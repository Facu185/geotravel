package uy.edu.fing.geotravel.consultas;

import uy.edu.fing.geotravel.db.DataSourceProvider;
import uy.edu.fing.geotravel.eta.Criterio;
import uy.edu.fing.geotravel.eta.RutaService;
import uy.edu.fing.geotravel.mapa.Bbox;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import javax.ws.rs.Consumes;
import javax.ws.rs.DefaultValue;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.time.Duration;
import java.util.*;

/**
 * Módulo Consultas geográficas y reportes (dueño: P5).
 * Cada método corresponde a uno de los 8 requerimientos de la letra de UrbanSafe (ver
 * docs/api/openapi.yaml para el contrato completo). Reemplaza al ConsultaResource de
 * GeoTravel -- mismos patrones SQL (point-in-polygon, nearest, agregaciones), aplicados
 * a zona_operativa / incidente / recurso en vez de zona_turistica / recorrido / atraccion.
 *
 * Un incidente puede ser un punto, una línea (calle cortada) o una zona: "incidente de una zona" se calcula
 * con ST_Intersects (una calle cortada que cruza dos zonas cuenta en las dos), y las distancias con
 * ST_Distance y el operador <->, que sirven igual para puntos, líneas y polígonos.
 *
 * "Búsqueda de incidente/zona por dirección o intersección de calles" recibe ya resuelta
 * la coordenada (x, y o lon, lat). Esa resolución la hacen /consultas/geocodificar (calle y
 * número, con la tabla acceso de Salto o con la IDE según el lugar), /consultas/interseccion
 * (cruce de dos calles, con la tabla via) y, en el frontend, el clic en el mapa. El departamento y
 * la localidad se piden por parámetro; sin ellos se usan los del backend (IDE_DEPARTAMENTO e
 * IDE_LOCALIDAD, por defecto Salto).
 */
@Path("/consultas")
public class ConsultaResource {

    // ------------------------------------------------------------------ resultados "a demanda"
    // Para que el navegador no tenga que cargar todos los objetos, cada consulta devuelve ya la
    // geometría de lo que encontró (GeoJSON en lon/lat, como texto) y, las que pueden dar muchas
    // filas, un límite y el total real: {items, total, truncado} (el mismo formato que /zonas?bbox).
    private static String geomIncidente(String alias) {
        return "ST_AsGeoJSON(ST_Transform(" + alias + ".geom, 4326), 6) AS geom";
    }

    /** Las zonas se simplifican (3 m): alcanza para dibujarlas y pesa mucho menos. */
    private static String geomZona(String alias) {
        return "ST_AsGeoJSON(ST_Transform(ST_SimplifyPreserveTopology(" + alias + ".geom, 3), 4326), 6) AS geom";
    }

    /** Lee las filas de una consulta que trae la columna "total" (count(*) OVER ()) y arma {items, total, truncado}. */
    private static Map<String, Object> conTotal(ResultSet rs, String... columnas) throws SQLException {
        List<Map<String, Object>> items = new ArrayList<>();
        int total = 0;
        while (rs.next()) {
            total = rs.getInt("total");
            Map<String, Object> fila = new LinkedHashMap<>();
            for (String columna : columnas) fila.put(toCamelCase(columna), texto(rs.getObject(columna)));
            items.add(fila);
        }
        return Bbox.resultado(items, total);
    }

    /** Las fechas viajan como texto (como en rowsToMaps), no como número. */
    private static Object texto(Object valor) {
        return valor instanceof Timestamp ? valor.toString() : valor;
    }

    private static int limiteDe(Integer pedido) {
        try {
            return Bbox.limite(pedido);
        } catch (IllegalArgumentException e) {
            throw peticionInvalida(e.getMessage());
        }
    }

    // ---------------------------------------------------------- 1. Incidentes por zona
    /** Incidentes que tocan la zona dada (puntos, líneas o zonas), con su geometría. */
    @GET
    @Path("/incidentes-por-zona/{zonaId}")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> incidentesPorZona(@PathParam("zonaId") int zonaId,
                                                 @QueryParam("limit") Integer limit) throws SQLException {
        String sql =
            "SELECT i.id, i.titulo, i.tipo_incidente, i.estado, i.prioridad, i.fecha_hora_registro, " +
            "       " + geomIncidente("i") + ", count(*) OVER () AS total " +
            "FROM incidente i, zona_operativa z " +
            "WHERE z.id = ? AND ST_Intersects(z.geom, i.geom) " +
            "ORDER BY i.fecha_hora_registro DESC LIMIT ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, zonaId);
            ps.setInt(2, limiteDe(limit));
            return conTotal(ps.executeQuery(), "id", "titulo", "tipo_incidente", "estado", "prioridad", "fecha_hora_registro", "geom");
        }
    }

    // --------------------------------------------- 2. Zonas con mayor cantidad de incidentes
    /**
     * Zonas ordenadas por cantidad de incidentes registrados en el período dado (ambos opcionales).
     * Con bbox (oeste,sur,este,norte en lon/lat) solo cuenta las zonas que están en esa parte del mapa, la
     * que se está viendo. Devuelve las primeras "limit" (50 por defecto), con su geometría para pintarlas.
     */
    @GET
    @Path("/zonas-mas-incidentes")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> zonasMasIncidentes(@QueryParam("desde") String desde,
                                                  @QueryParam("hasta") String hasta,
                                                  @QueryParam("bbox") String bbox,
                                                  @QueryParam("limit") Integer limit) throws SQLException {
        Bbox rectangulo = null;
        if (bbox != null) {
            try {
                rectangulo = Bbox.parse(bbox);
            } catch (IllegalArgumentException e) {
                throw peticionInvalida(e.getMessage());
            }
            if (rectangulo.vacio()) {
                return Bbox.resultado(new ArrayList<>(), 0);
            }
        }
        String sql =
            "SELECT z.id, z.nombre, z.nivel_prioridad, count(i.id) AS cantidad_incidentes, " +
            "       " + geomZona("z") + ", count(*) OVER () AS total " +
            "FROM zona_operativa z " +
            "LEFT JOIN incidente i ON ST_Intersects(z.geom, i.geom) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro >= ?::timestamp) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro <  ?::timestamp) " +
            (rectangulo != null ? "WHERE z.geom && ST_Transform(ST_MakeEnvelope(?, ?, ?, ?, 4326), 32721) " : "") +
            "GROUP BY z.id, z.nombre, z.nivel_prioridad, z.geom " +
            "ORDER BY cantidad_incidentes DESC, z.nombre LIMIT ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, desde); ps.setString(2, desde);
            ps.setString(3, hasta); ps.setString(4, hasta);
            int siguiente = rectangulo != null ? rectangulo.enlazar(ps, 5) : 5;
            ps.setInt(siguiente, limiteRanking(limit));
            return conTotal(ps.executeQuery(), "id", "nombre", "nivel_prioridad", "cantidad_incidentes", "geom");
        }
    }

    private static int limiteRanking(Integer pedido) {
        return pedido == null ? 50 : limiteDe(pedido);
    }

    // ---------------------------------------------------- 3. Recursos cercanos a un incidente
    /**
     * Los recursos más cercanos al incidente dado, ordenados por distancia, con su geometría. Con
     * soloDisponibles=true se consideran únicamente los recursos en estado "Disponible"
     * (la letra pide los recursos *operativos* más cercanos).
     */
    @GET
    @Path("/recursos-cercanos/{incidenteId}")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> recursosCercanos(@PathParam("incidenteId") int incidenteId,
                                                        @QueryParam("limite") @DefaultValue("5") int limite,
                                                        @QueryParam("soloDisponibles") @DefaultValue("false") boolean soloDisponibles)
            throws SQLException {
        int max = limite < 1 ? 5 : Math.min(limite, 50);
        String sql =
            "SELECT r.id, r.identificacion, r.tipo, r.estado_operativo, " +
            "       ST_Distance(r.geom, i.geom) AS distancia_m, " + geomIncidente("r") + " " +
            "FROM recurso r, incidente i " +
            "WHERE i.id = ? " +
            (soloDisponibles ? "  AND r.estado_operativo = 'Disponible' " : "") +
            "ORDER BY r.geom <-> i.geom " +
            "LIMIT ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, incidenteId);
            ps.setInt(2, max);
            return rowsToMaps(ps.executeQuery(), "id", "identificacion", "tipo", "estado_operativo", "distancia_m", "geom");
        }
    }

    /**
     * Consulta 3 ampliada: recursos dentro de un buffer de radioMetros alrededor del incidente, con distancia directa
     * y, con conRutas=true, la ruta por calles de los más cercanos. Ver AnalisisVial y docs/api/openapi.yaml.
     */
    @GET
    @Path("/recursos-cercanos/{incidenteId}/analisis-vial")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> analisisVial(@PathParam("incidenteId") int incidenteId,
                                            @QueryParam("radioMetros") String radioMetros,
                                            @QueryParam("limite") String limite,
                                            @QueryParam("soloDisponibles") @DefaultValue("true") boolean soloDisponibles,
                                            @QueryParam("conRutas") @DefaultValue("false") boolean conRutas,
                                            @QueryParam("criterio") String criterioParam)
            throws SQLException, IOException {
        Criterio criterio = Criterio.desde(criterioParam);
        if (criterio == null) {
            throw peticionInvalida("criterio tiene que ser mas_rapida o mas_corta");
        }
        RutaService servicio = RutaService.predeterminado();
        if (conRutas && !servicio.disponible(criterio)) {
            throw new WebApplicationException(Response.status(Response.Status.SERVICE_UNAVAILABLE)
                    .type(MediaType.APPLICATION_JSON)
                    .entity(Map.of("error", "El criterio " + criterio.codigo
                            + " no esta disponible: falta configurar el OSRM propio (OSRM_URL_CORTA)"))
                    .build());
        }
        AnalisisVial.Parametros parametros;
        try {
            parametros = AnalisisVial.validar(
                    AnalisisVial.entero("radioMetros", radioMetros), AnalisisVial.entero("limite", limite));
        } catch (IllegalArgumentException e) {
            throw peticionInvalida(e.getMessage());
        }
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            Map<String, Object> respuesta = new AnalisisVial(servicio)
                    .analizar(conn, incidenteId, parametros, soloDisponibles, conRutas, criterio);
            if (respuesta == null) {
                throw new WebApplicationException(Response.status(Response.Status.NOT_FOUND)
                        .type(MediaType.APPLICATION_JSON)
                        .entity(Map.of("error", "Incidente no encontrado"))
                        .build());
            }
            return respuesta;
        }
    }

    // ------------------------------------------------------------- 4. Búsqueda de incidente
    /**
     * Incidente más cercano al punto (x, y en EPSG:32721, o lon, lat en EPSG:4326), con su geometría.
     * Para "una dirección o intersección de calles": resolvé antes la coordenada (/consultas/geocodificar
     * o /consultas/interseccion) y pasala acá.
     */
    @GET
    @Path("/incidente-mas-cercano")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> incidenteMasCercano(@QueryParam("x") Double x, @QueryParam("y") Double y,
                                                     @QueryParam("lon") Double lon, @QueryParam("lat") Double lat) throws SQLException {
        boolean enGrados = lon != null && lat != null;
        validarCoordenada(x, y, lon, lat);
        double a = enGrados ? lon : x;
        double b = enGrados ? lat : y;
        String punto = enGrados ? PUNTO_LON_LAT : PUNTO_X_Y;
        String sql =
            "SELECT i.id, i.titulo, i.tipo_incidente, i.estado, i.prioridad, i.fecha_hora_registro, " +
            "       ST_Distance(i.geom, " + punto + ") AS distancia_m, " + geomIncidente("i") + " " +
            "FROM incidente i " +
            "ORDER BY i.geom <-> " + punto + " " +
            "LIMIT 1";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDouble(1, a); ps.setDouble(2, b);
            ps.setDouble(3, a); ps.setDouble(4, b);
            try (ResultSet rs = ps.executeQuery()) {
                Map<String, Object> row = new LinkedHashMap<>();
                if (!rs.next()) return row;
                for (String columna : new String[] {"id", "titulo", "tipo_incidente", "estado", "prioridad", "fecha_hora_registro", "distancia_m", "geom"}) {
                    row.put(columna.equals("distancia_m") ? "distanciaM" : toCamelCase(columna), texto(rs.getObject(columna)));
                }
                return row;
            }
        }
    }

    // ----------------------------------------------------------------- 5. Búsqueda de zona
    /** Zona que contiene el punto dado (x, y en EPSG:32721, o lon, lat en EPSG:4326), con su geometría. */
    @GET
    @Path("/zona-por-punto")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> zonaPorPunto(@QueryParam("x") Double x, @QueryParam("y") Double y,
                                              @QueryParam("lon") Double lon, @QueryParam("lat") Double lat) throws SQLException {
        boolean enGrados = lon != null && lat != null;
        validarCoordenada(x, y, lon, lat);
        double a = enGrados ? lon : x;
        double b = enGrados ? lat : y;
        String sql =
            "SELECT z.id, z.nombre, z.nivel_prioridad, z.responsable, " + geomZona("z") + " " +
            "FROM zona_operativa z " +
            "WHERE ST_Contains(z.geom, " + (enGrados ? PUNTO_LON_LAT : PUNTO_X_Y) + ") " +
            "LIMIT 1";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDouble(1, a); ps.setDouble(2, b);
            try (ResultSet rs = ps.executeQuery()) {
                Map<String, Object> row = new LinkedHashMap<>();
                if (!rs.next()) {
                    row.put("zona", null);
                    return row;
                }
                for (String columna : new String[] {"id", "nombre", "nivel_prioridad", "responsable", "geom"}) {
                    row.put(toCamelCase(columna), texto(rs.getObject(columna)));
                }
                return row;
            }
        }
    }

    // --------------------------------------------------------------- 6. Recursos por zona
    /** Recursos ubicados dentro de la zona dada, con su geometría. */
    @GET
    @Path("/recursos-por-zona/{zonaId}")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> recursosPorZona(@PathParam("zonaId") int zonaId,
                                               @QueryParam("limit") Integer limit) throws SQLException {
        String sql =
            "SELECT r.id, r.identificacion, r.tipo, r.estado_operativo, " + geomIncidente("r") + ", count(*) OVER () AS total " +
            "FROM recurso r, zona_operativa z " +
            "WHERE z.id = ? AND ST_Contains(z.geom, r.geom) " +
            "ORDER BY r.id LIMIT ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, zonaId);
            ps.setInt(2, limiteDe(limit));
            return conTotal(ps.executeQuery(), "id", "identificacion", "tipo", "estado_operativo", "geom");
        }
    }

    // ----------------------------------------------------------- 7. Incidentes por recurso
    /** Incidentes atendidos/asociados a un recurso (tabla incidente_recurso), con su geometría. */
    @GET
    @Path("/incidentes-por-recurso/{recursoId}")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> incidentesPorRecurso(@PathParam("recursoId") int recursoId,
                                                    @QueryParam("limit") Integer limit) throws SQLException {
        String sql =
            "SELECT i.id, i.titulo, i.tipo_incidente, i.estado, i.prioridad, i.fecha_hora_registro, ir.fecha_asignacion, " +
            "       " + geomIncidente("i") + ", count(*) OVER () AS total " +
            "FROM incidente i JOIN incidente_recurso ir ON ir.incidente_id = i.id " +
            "WHERE ir.recurso_id = ? " +
            "ORDER BY ir.fecha_asignacion DESC LIMIT ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, recursoId);
            ps.setInt(2, limiteDe(limit));
            return conTotal(ps.executeQuery(), "id", "titulo", "tipo_incidente", "estado", "prioridad", "fecha_hora_registro", "fecha_asignacion", "geom");
        }
    }

    // ------------------------------------------------------------------------ Buscar un objeto
    /**
     * Búsqueda por texto de una zona, un incidente o un recurso, para elegirlo sin cargar la lista
     * completa (los selectores de las consultas). Devuelve hasta "limite" resultados con su
     * etiqueta y geometría. Sin texto, devuelve los primeros.
     */
    @GET
    @Path("/buscar")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> buscar(@QueryParam("tipo") String tipo,
                                            @QueryParam("q") String q,
                                            @QueryParam("limite") @DefaultValue("10") int limite) throws SQLException {
        int max = limite < 1 ? 10 : Math.min(limite, 25);
        String texto = q == null ? "" : q.trim().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
        String patron = "%" + texto + "%";
        String sql;
        String[] columnas;
        boolean porNumero = false;
        switch (tipo == null ? "" : tipo) {
            case "zona":
                sql = "SELECT z.id, z.nombre || ' (prioridad ' || z.nivel_prioridad || ')' AS etiqueta, z.nivel_prioridad, " + geomZona("z") + " " +
                      "FROM zona_operativa z WHERE z.nombre ILIKE ? ORDER BY z.nombre LIMIT ?";
                columnas = new String[] {"id", "etiqueta", "nivel_prioridad", "geom"};
                break;
            case "incidente":
                columnas = new String[] {"id", "etiqueta", "estado", "geom"};
                sql = "SELECT i.id, '#' || i.id || ' ' || i.titulo || ' — ' || i.estado AS etiqueta, i.estado, " + geomIncidente("i") + " " +
                      "FROM incidente i WHERE i.titulo ILIKE ? OR i.id::text = ? ORDER BY i.fecha_hora_registro DESC LIMIT ?";
                porNumero = true;
                break;
            case "recurso":
                columnas = new String[] {"id", "etiqueta", "estado_operativo", "geom"};
                sql = "SELECT r.id, r.identificacion || ' — ' || r.tipo AS etiqueta, r.estado_operativo, " + geomIncidente("r") + " " +
                      "FROM recurso r WHERE r.identificacion ILIKE ? OR r.nombre ILIKE ? ORDER BY r.identificacion LIMIT ?";
                porNumero = true;
                break;
            default:
                throw peticionInvalida("El tipo tiene que ser zona, incidente o recurso");
        }
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, patron);
            if (porNumero) {
                ps.setString(2, "recurso".equals(tipo) ? patron : q == null ? "" : q.trim());
                ps.setInt(3, max);
            } else {
                ps.setInt(2, max);
            }
            return rowsToMaps(ps.executeQuery(), columnas);
        }
    }

    // ------------------------------------------------------------------------- Reporte
    /**
     * "Reporte de incidentes por zona" (requerimiento del administrador, distinto de la
     * consulta geográfica #1): filtrable por zona/tipo/prioridad/estado/rango de fechas,
     * agrupado por zona. Todos los filtros son opcionales.
     */
    @GET
    @Path("/reportes/incidentes-por-zona")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> reporteIncidentesPorZona(@QueryParam("zonaId") Integer zonaId,
                                                                @QueryParam("tipo") String tipo,
                                                                @QueryParam("prioridad") Integer prioridad,
                                                                @QueryParam("estado") String estado,
                                                                @QueryParam("desde") String desde,
                                                                @QueryParam("hasta") String hasta,
                                                                @QueryParam("limit") Integer limit) throws SQLException {
        String sql =
            "SELECT z.id AS zona_id, z.nombre AS zona_nombre, i.id, i.titulo, i.tipo_incidente, i.prioridad, i.estado, i.fecha_hora_registro, " +
            "       " + geomIncidente("i") + ", count(*) OVER () AS total " +
            "FROM zona_operativa z " +
            "JOIN incidente i ON ST_Intersects(z.geom, i.geom) " +
            "WHERE (?::int  IS NULL OR z.id = ?) " +
            "  AND (?::text IS NULL OR i.tipo_incidente = ?) " +
            "  AND (?::int  IS NULL OR i.prioridad = ?) " +
            "  AND (?::text IS NULL OR i.estado = ?) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro >= ?::timestamp) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro <  ?::timestamp) " +
            "ORDER BY z.nombre, i.fecha_hora_registro DESC LIMIT ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (zonaId == null) { ps.setNull(1, Types.INTEGER); ps.setNull(2, Types.INTEGER); }
            else { ps.setInt(1, zonaId); ps.setInt(2, zonaId); }
            ps.setString(3, tipo); ps.setString(4, tipo);
            if (prioridad == null) { ps.setNull(5, Types.INTEGER); ps.setNull(6, Types.INTEGER); }
            else { ps.setInt(5, prioridad); ps.setInt(6, prioridad); }
            ps.setString(7, estado); ps.setString(8, estado);
            ps.setString(9, desde); ps.setString(10, desde);
            ps.setString(11, hasta); ps.setString(12, hasta);
            ps.setInt(13, limiteDe(limit));
            return conTotal(ps.executeQuery(),
                    "zona_id", "zona_nombre", "id", "titulo", "tipo_incidente", "prioridad", "estado", "fecha_hora_registro", "geom");
        }
    }

    // El punto de consulta llega en metros (x, y en EPSG:32721) o en grados (lon, lat en EPSG:4326,
    // lo que entrega un clic en el mapa); en este último caso lo convierte PostGIS.
    private static final String PUNTO_X_Y = "ST_SetSRID(ST_MakePoint(?, ?), 32721)";
    private static final String PUNTO_LON_LAT = "ST_Transform(ST_SetSRID(ST_MakePoint(?, ?), 4326), 32721)";

    private static void validarCoordenada(Double x, Double y, Double lon, Double lat) {
        boolean enGrados = lon != null && lat != null;
        boolean enMetros = x != null && y != null;
        if (!enGrados && !enMetros) {
            throw peticionInvalida("Falta la coordenada: enviar x e y (EPSG:32721) o lon y lat (EPSG:4326)");
        }
    }

    private static WebApplicationException peticionInvalida(String mensaje) {
        return new WebApplicationException(Response.status(Response.Status.BAD_REQUEST)
                .type(MediaType.APPLICATION_JSON)
                .entity(Map.of("error", mensaje))
                .build());
    }

    // -------------------------------------------------------- Dirección (calle y número)
    private static final String IDE_BUSQUEDA_DIRECCION = "https://direcciones.ide.uy/api/v0/geocode/BusquedaDireccion";
    private static final HttpClient HTTP = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final ConfiguracionIde CONFIGURACION_IDE = ConfiguracionIde.desdeEntorno();

    /**
     * Cómo se escriben completas las palabras de los nombres de calle de la base ("AVENIDA", "GENERAL",
     * "DOCTOR"): quien busca puede escribir "Av.", "Gral" o "Dr" y se compara con el nombre completo.
     */
    private static final Map<String, String> PALABRAS_COMPLETAS = Map.ofEntries(
        Map.entry("AV", "AVENIDA"), Map.entry("AVDA", "AVENIDA"), Map.entry("CNO", "CAMINO"),
        Map.entry("BV", "BULEVAR"), Map.entry("BOULEVARD", "BULEVAR"), Map.entry("PSJE", "PASAJE"),
        Map.entry("GRAL", "GENERAL"), Map.entry("DR", "DOCTOR"), Map.entry("DRA", "DOCTORA"),
        Map.entry("ING", "INGENIERO"), Map.entry("RBLA", "RAMBLA"), Map.entry("CIRC", "CIRCUITO"),
        Map.entry("CAP", "CAPITAN"), Map.entry("CNEL", "CORONEL"), Map.entry("ALM", "ALMIRANTE"),
        Map.entry("ARQ", "ARQUITECTO"), Map.entry("PROF", "PROFESOR"), Map.entry("TTE", "TENIENTE"),
        Map.entry("SGTO", "SARGENTO"), Map.entry("CTE", "COMANDANTE"), Map.entry("PTE", "PRESIDENTE"));

    private static final java.util.regex.Pattern CALLE_Y_NUMERO =
        java.util.regex.Pattern.compile("^(.+?)\\s+(\\d{1,6})\\s*([A-Z])?$");

    /** Mayúsculas, sin tildes ni puntuación y con las palabras completas, como en la base. */
    private static String normalizarCalle(String texto) {
        String limpio = java.text.Normalizer.normalize(texto, java.text.Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "").toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9 ]", " ").trim();
        StringBuilder sb = new StringBuilder();
        for (String palabra : limpio.split("\\s+")) {
            if (sb.length() > 0) sb.append(' ');
            sb.append(PALABRAS_COMPLETAS.getOrDefault(palabra, palabra));
        }
        return sb.toString();
    }

    /**
     * Ubica una dirección "calle número" (por ejemplo "Camino Carrasco 4680" o "18 de Julio 1000")
     * y devuelve lon/lat (EPSG:4326), que se usan en "incidente más cercano" y "zona de un punto".
     * Se busca en la tabla acceso (los números de puerta de Salto; la capa "acceso" de GeoServer es
     * esa misma tabla). La calle se compara por
     * nombre tolerando abreviaturas y errores de tipeo. Si el número no existe se usa la puerta más
     * cercana de esa calle y se marca "aproximada". Esa tabla es solo de Salto. En otro departamento
     * (parámetros departamento y localidad, por ejemplo montevideo y montevideo), y para las esquinas (parámetro
     * esquina: dos calles que se cruzan), se usa el servicio de direcciones de la IDE, que cubre el país.
     */
    @GET
    @Path("/geocodificar")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> geocodificar(@QueryParam("direccion") String direccion,
                                            @QueryParam("esquina") String esquina,
                                            @QueryParam("departamento") String departamento,
                                            @QueryParam("localidad") String localidad) throws SQLException {
        if (direccion == null || direccion.trim().isEmpty()) {
            throw peticionInvalida("Falta la dirección (por ejemplo: Buenos Aires 451)");
        }
        boolean hayDepartamento = departamento != null && !departamento.trim().isEmpty();
        // Sin parámetros se usa el lugar configurado en el backend (IDE_DEPARTAMENTO / IDE_LOCALIDAD).
        // Con solo el departamento, la localidad es la del mismo nombre.
        String dep = lugar(departamento, CONFIGURACION_IDE.getDepartamento());
        String loc = lugar(localidad, hayDepartamento ? dep : CONFIGURACION_IDE.getLocalidad());
        boolean hayEsquina = esquina != null && !esquina.trim().isEmpty();
        // La tabla de puertas propia es solo de Salto: en otro lugar, o con esquina, va directo a la IDE.
        java.util.regex.Matcher m = hayEsquina ? null : coincidenciaPuertaLocal(direccion, new ConfiguracionIde(dep, loc));
        if (m != null) {
            Map<String, Object> propio = buscarPuerta(m.group(1), Integer.parseInt(m.group(2)), m.group(3));
            if (propio != null) return propio;
        }
        return geocodificarConIde(direccion, hayEsquina ? esquina.trim() : null, dep, loc);
    }

    /**
     * Nombre de departamento o localidad para el servicio de direcciones: minúsculas, solo letras,
     * espacios, punto, apóstrofo y guion, hasta 40 caracteres. Sin valor usa el de por defecto.
     */
    static String lugar(String valor, String porDefecto) {
        if (valor == null || valor.trim().isEmpty()) {
            return porDefecto;
        }
        String limpio = valor.trim().toLowerCase(Locale.ROOT);
        if (!limpio.matches("[\\p{L} .'-]{2,40}")) {
            throw peticionInvalida("El departamento o la localidad no es válido");
        }
        return limpio;
    }

    static java.util.regex.Matcher coincidenciaPuertaLocal(
            String direccion,
            ConfiguracionIde configuracion
    ) {
        if (direccion == null || !configuracion.usaPuertasLocales()) {
            return null;
        }
        java.util.regex.Matcher matcher = CALLE_Y_NUMERO.matcher(normalizarCalle(direccion));
        return matcher.matches() && !matcher.group(1).contains(" ESQ") ? matcher : null;
    }

    /** Busca la puerta en la tabla acceso; null si la calle o el número no están en la base. */
    private Map<String, Object> buscarPuerta(String calle, int numero, String letra) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            // 1. Nombres de calle parecidos al escrito (el exacto primero).
            List<String> nombres = new ArrayList<>();
            try (PreparedStatement ps = conn.prepareStatement(
                "SELECT n, similarity(n, ?) AS s FROM (SELECT DISTINCT upper(nom_calle) AS n FROM acceso " +
                "WHERE upper(nom_calle) % ?) t WHERE similarity(n, ?) >= 0.5 ORDER BY s DESC, n LIMIT 5")) {
                ps.setString(1, calle);
                ps.setString(2, calle);
                ps.setString(3, calle);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) nombres.add(rs.getString("n"));
                }
            }
            if (nombres.isEmpty()) return null;
            Array arreglo = conn.createArrayOf("text", nombres.toArray());

            // 2. La puerta exacta (con la letra pedida si hay) o, si no existe, la de numeración más
            //    cercana de esa calle, prefiriendo la misma paridad (la misma vereda).
            String sql =
                "SELECT nom_calle, num_puerta, letra, " +
                "       ST_X(ST_Transform(geom, 4326)) AS lon, ST_Y(ST_Transform(geom, 4326)) AS lat " +
                "FROM acceso WHERE upper(nom_calle) = ANY (?) " +
                "ORDER BY abs(num_puerta - ?), (num_puerta % 2 <> ? % 2), " +
                "         (letra IS DISTINCT FROM ?), array_position(?, upper(nom_calle)) LIMIT 1";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setArray(1, arreglo);
                ps.setInt(2, numero);
                ps.setInt(3, numero);
                ps.setString(4, letra);
                ps.setArray(5, arreglo);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) return null;
                    int encontrado = rs.getInt("num_puerta");
                    // Un número muy lejos de la numeración de la calle es un error de tipeo, no una puerta cercana.
                    if (Math.abs(encontrado - numero) > 60) return null;
                    String letraEncontrada = rs.getString("letra");
                    boolean exacta = encontrado == numero && (letra == null || letra.equals(letraEncontrada));
                    Map<String, Object> resultado = new LinkedHashMap<>();
                    resultado.put("direccion", rs.getString("nom_calle") + " " + encontrado + (letraEncontrada == null ? "" : letraEncontrada));
                    resultado.put("lon", rs.getDouble("lon"));
                    resultado.put("lat", rs.getDouble("lat"));
                    resultado.put("aproximada", !exacta);
                    resultado.put("aviso", exacta ? null
                        : encontrado == numero
                            ? "No existe esa letra en la base: se ubicó la puerta " + numero + "."
                            : "No existe esa puerta en la base: se ubicó la más cercana (" + encontrado + ").");
                    resultado.put("fuente", "Puertas de Salto");
                    return resultado;
                }
            }
        }
    }

    /**
     * Respaldo: ubica la dirección con el servicio de direcciones de la IDE de Uruguay (Sistema
     * Único de Direcciones Geográficas), por internet. Si el número no existe el servicio ubica la
     * calle y se marca "aproximada". Sin internet o con el servicio caído responde 502 con un mensaje.
     */
    private Map<String, Object> geocodificarConIde(String direccion, String esquinaPedida, String departamento, String localidad) {
        String url = new ConfiguracionIde(departamento, localidad)
            .urlBusqueda(IDE_BUSQUEDA_DIRECCION, direccion, esquinaPedida);
        JsonNode lista;
        try {
            HttpResponse<String> respuesta = HTTP.send(
                HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(10)).GET().build(),
                HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (respuesta.statusCode() != 200) {
                throw servicioDeDireccionesNoDisponible("respondió " + respuesta.statusCode());
            }
            lista = JSON.readTree(respuesta.body());
        } catch (IOException e) {
            throw servicioDeDireccionesNoDisponible("no se pudo conectar");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw servicioDeDireccionesNoDisponible("la consulta fue interrumpida");
        }
        // Si el servicio no reconoce ni la calle, devuelve el centro de la localidad: eso no es una dirección.
        boolean sinCalle = lista == null || !lista.isArray() || lista.size() == 0
            || !lista.get(0).hasNonNull("puntoX")
            || lista.get(0).path("direccion").path("calle").path("nombre_normalizado").asText("").isEmpty();
        if (sinCalle) {
            throw new WebApplicationException(Response.status(Response.Status.NOT_FOUND)
                .type(MediaType.APPLICATION_JSON)
                .entity(Map.of("error", "No se encontró esa dirección. Probá con el formato \"calle número\" (por ejemplo: Buenos Aires 451) o con otra calle"))
                .build());
        }
        JsonNode mejor = lista.get(0);
        JsonNode datos = mejor.path("direccion");
        String calle = datos.path("calle").path("nombre_normalizado").asText("");
        String numero = datos.path("numero").path("nro_puerta").asText("");
        String esquina = esquinaPedida != null ? esquinaPedida : datos.path("esquina").path("nombre_normalizado").asText("");
        String texto = !esquina.isEmpty() ? calle + " esq. " + esquina
            : !numero.isEmpty() ? calle + " " + numero
            : direccion.trim();
        String error = mejor.path("error").asText("").trim();

        Map<String, Object> resultado = new LinkedHashMap<>();
        resultado.put("direccion", texto);
        resultado.put("fuente", "IDE");
        resultado.put("departamento", departamento);
        resultado.put("localidad", localidad);
        resultado.put("lon", mejor.get("puntoX").asDouble());
        resultado.put("lat", mejor.get("puntoY").asDouble());
        resultado.put("aproximada", !error.isEmpty());
        // Con número, el servicio ubica el portal por interpolación sobre la calle y igual lo marca
        // "punto no encontrado"; sin número en la respuesta, el número no existe y solo ubicó la calle.
        String aviso = error.isEmpty() ? null
            : !numero.isEmpty() ? "El servicio no tiene el punto exacto de esa puerta: se ubicó por el número sobre la calle (aproximado, puede haber unos metros de diferencia)."
            : "No se encontró ese número de puerta: se ubicó sobre la calle (aproximado).";
        resultado.put("aviso", aviso);
        return resultado;
    }

    private static WebApplicationException servicioDeDireccionesNoDisponible(String motivo) {
        return new WebApplicationException(Response.status(Response.Status.BAD_GATEWAY)
            .type(MediaType.APPLICATION_JSON)
            .entity(Map.of("error", "El servicio de direcciones de la IDE no está disponible (" + motivo
                + "). Podés elegir el punto con un clic en el mapa o por intersección de calles."))
            .build());
    }

    // ---------------------------------------------------------- Calles e intersecciones
    /**
     * Nombres de calle que contienen el texto dado (mínimo 2 letras), con los que empiezan por
     * él primero. Alimenta el autocompletado de la búsqueda por intersección.
     */
    @GET
    @Path("/calles")
    @Produces(MediaType.APPLICATION_JSON)
    public List<String> calles(@QueryParam("q") String q) throws SQLException {
        List<String> nombres = new ArrayList<>();
        if (q == null || q.trim().length() < 2) return nombres;
        String texto = q.trim().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
        String sql =
            "SELECT nom_calle FROM via WHERE nom_calle ILIKE ? " +
            "GROUP BY nom_calle ORDER BY (nom_calle ILIKE ?) DESC, nom_calle LIMIT 10";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, "%" + texto + "%");
            ps.setString(2, texto + "%");
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) nombres.add(rs.getString(1));
            }
        }
        return nombres;
    }

    /**
     * Puntos donde se cruzan dos calles (lon/lat), para usarlos en "incidente más cercano" y
     * "zona de un punto". Una calle son varios tramos con el mismo nombre: se unen y se
     * intersectan en PostGIS (mismo patrón del ejercicio 6 del Práctico 2). Si no se cruzan
     * devuelve una lista vacía; si hay varios cruces (nombres repetidos en la ciudad), todos.
     */
    @GET
    @Path("/interseccion")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> interseccion(@QueryParam("calle1") String calle1,
                                                    @QueryParam("calle2") String calle2) throws SQLException {
        if (calle1 == null || calle1.trim().isEmpty() || calle2 == null || calle2.trim().isEmpty()) {
            throw peticionInvalida("Faltan las dos calles: calle1 y calle2");
        }
        String sql =
            "WITH a AS (SELECT ST_Collect(geom) AS g FROM via WHERE upper(nom_calle) = upper(?)), " +
            "     b AS (SELECT ST_Collect(geom) AS g FROM via WHERE upper(nom_calle) = upper(?)), " +
            "     puntos AS (SELECT (ST_Dump(ST_Intersection(a.g, b.g))).geom AS p FROM a, b " +
            "                WHERE a.g IS NOT NULL AND b.g IS NOT NULL) " +
            "SELECT ST_X(ST_Transform(p, 4326)) AS lon, ST_Y(ST_Transform(p, 4326)) AS lat " +
            "FROM puntos WHERE GeometryType(p) = 'POINT' ORDER BY lat, lon";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, calle1.trim());
            ps.setString(2, calle2.trim());
            return rowsToMaps(ps.executeQuery(), "lon", "lat");
        }
    }

    // ------------------------------------------------------------ Opciones de filtros
    /** Los tipos de incidente que existen, para el filtro del mapa público (un DISTINCT, no un listado). */
    @GET
    @Path("/tipos-incidente")
    @Produces(MediaType.APPLICATION_JSON)
    public List<String> tiposIncidente() throws SQLException {
        List<String> tipos = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT DISTINCT tipo_incidente FROM incidente ORDER BY 1")) {
            while (rs.next()) tipos.add(rs.getString(1));
        }
        return tipos;
    }

    // --- helper: cualquier ResultSet -> List<Map<columna, valor>>, solo para las columnas pedidas ---
    private static List<Map<String, Object>> rowsToMaps(ResultSet rs, String... columns) throws SQLException {
        List<Map<String, Object>> rows = new ArrayList<>();
        while (rs.next()) {
            Map<String, Object> row = new LinkedHashMap<>();
            for (String col : columns) {
                Object valor = rs.getObject(col);
                row.put(toCamelCase(col), (valor instanceof Timestamp) ? valor.toString() : valor);
            }
            rows.add(row);
        }
        return rows;
    }

    private static String toCamelCase(String snake) {
        StringBuilder sb = new StringBuilder();
        boolean upperNext = false;
        for (char c : snake.toCharArray()) {
            if (c == '_') { upperNext = true; continue; }
            sb.append(upperNext ? Character.toUpperCase(c) : c);
            upperNext = false;
        }
        return sb.toString();
    }
}
