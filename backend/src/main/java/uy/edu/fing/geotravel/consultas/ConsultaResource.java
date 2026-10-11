package uy.edu.fing.geotravel.consultas;

import uy.edu.fing.geotravel.db.DataSourceProvider;

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
import java.net.URLEncoder;
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
 * "Búsqueda de incidente/zona por dirección o intersección de calles" recibe ya resuelta
 * la coordenada (x, y o lon, lat). Esa resolución la hacen /consultas/geocodificar (calle y
 * número, con la tabla acceso), /consultas/interseccion (cruce de dos calles, con la tabla via)
 * y, en el frontend, el clic en el mapa.
 */
@Path("/consultas")
public class ConsultaResource {

    // ---------------------------------------------------------- 1. Incidentes por zona
    /** Incidentes que caen dentro de la zona dada. */
    @GET
    @Path("/incidentes-por-zona/{zonaId}")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> incidentesPorZona(@PathParam("zonaId") int zonaId) throws SQLException {
        String sql =
            "SELECT i.id, i.titulo, i.tipo_incidente, i.estado, i.prioridad " +
            "FROM incidente i, zona_operativa z " +
            "WHERE z.id = ? AND ST_Contains(z.geom, i.geom) " +
            "ORDER BY i.fecha_hora_registro DESC";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, zonaId);
            return rowsToMaps(ps.executeQuery(), "id", "titulo", "tipo_incidente", "estado", "prioridad");
        }
    }

    // --------------------------------------------- 2. Zonas con mayor cantidad de incidentes
    /** Zonas ordenadas por cantidad de incidentes registrados en el período dado (ambos opcionales). */
    @GET
    @Path("/zonas-mas-incidentes")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> zonasMasIncidentes(@QueryParam("desde") String desde,
                                                          @QueryParam("hasta") String hasta) throws SQLException {
        String sql =
            "SELECT z.id, z.nombre, count(i.id) AS cantidad_incidentes " +
            "FROM zona_operativa z " +
            "LEFT JOIN incidente i ON ST_Contains(z.geom, i.geom) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro >= ?::timestamp) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro <  ?::timestamp) " +
            "GROUP BY z.id, z.nombre " +
            "ORDER BY cantidad_incidentes DESC";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, desde); ps.setString(2, desde);
            ps.setString(3, hasta); ps.setString(4, hasta);
            return rowsToMaps(ps.executeQuery(), "id", "nombre", "cantidad_incidentes");
        }
    }

    // ---------------------------------- 8. Zonas con mayor concentración de incidentes
    /**
     * AMBIGÜEDAD EN LA LETRA: aparece como requerimiento aparte de "zonas con mayor
     * cantidad" (arriba), sin aclarar la diferencia -- se asume que "concentración" es
     * la cantidad NORMALIZADA por área (incidentes / km²), a diferencia del conteo bruto.
     * Confirmar con el tutor si el criterio esperado es otro.
     */
    @GET
    @Path("/zonas-mayor-concentracion")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> zonasMayorConcentracion(@QueryParam("desde") String desde,
                                                               @QueryParam("hasta") String hasta) throws SQLException {
        String sql =
            "SELECT z.id, z.nombre, count(i.id) AS cantidad_incidentes, " +
            "       round((count(i.id) / (ST_Area(z.geom) / 1e6))::numeric, 3) AS incidentes_por_km2 " +
            "FROM zona_operativa z " +
            "LEFT JOIN incidente i ON ST_Contains(z.geom, i.geom) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro >= ?::timestamp) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro <  ?::timestamp) " +
            "GROUP BY z.id, z.nombre, z.geom " +
            "ORDER BY incidentes_por_km2 DESC";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, desde); ps.setString(2, desde);
            ps.setString(3, hasta); ps.setString(4, hasta);
            return rowsToMaps(ps.executeQuery(), "id", "nombre", "cantidad_incidentes", "incidentes_por_km2");
        }
    }

    // ---------------------------------------------------- 3. Recursos cercanos a un incidente
    /**
     * Los recursos más cercanos al incidente dado, ordenados por distancia. Con
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
        int max = limite < 1 ? 5 : limite;
        String sql =
            "SELECT r.id, r.identificacion, r.tipo, r.estado_operativo, " +
            "       ST_Distance(r.geom, i.geom) AS distancia_m " +
            "FROM recurso r, incidente i " +
            "WHERE i.id = ? " +
            (soloDisponibles ? "  AND r.estado_operativo = 'Disponible' " : "") +
            "ORDER BY r.geom <-> i.geom " +
            "LIMIT ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, incidenteId);
            ps.setInt(2, max);
            return rowsToMaps(ps.executeQuery(), "id", "identificacion", "tipo", "estado_operativo", "distancia_m");
        }
    }

    // ------------------------------------------------------------- 4. Búsqueda de incidente
    /**
     * Incidente más cercano al punto (x, y en EPSG:32721). Para "una dirección o
     * intersección de calles": resolvé antes la coordenada (geocoder, o el mismo patrón
     * del ejercicio 6 del Práctico 2 para el cruce de dos calles) y pasala acá.
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
            "SELECT id, titulo, estado, " +
            "       ST_Distance(geom, " + punto + ") AS distancia_m " +
            "FROM incidente " +
            "ORDER BY geom <-> " + punto + " " +
            "LIMIT 1";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDouble(1, a); ps.setDouble(2, b);
            ps.setDouble(3, a); ps.setDouble(4, b);
            try (ResultSet rs = ps.executeQuery()) {
                Map<String, Object> row = new LinkedHashMap<>();
                if (!rs.next()) return row;
                row.put("id", rs.getInt("id"));
                row.put("titulo", rs.getString("titulo"));
                row.put("estado", rs.getString("estado"));
                row.put("distanciaM", rs.getDouble("distancia_m"));
                return row;
            }
        }
    }

    // ----------------------------------------------------------------- 5. Búsqueda de zona
    /** Zona que contiene el punto dado (x, y en EPSG:32721) -- ya geocodificada la dirección. */
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
            "SELECT id, nombre FROM zona_operativa " +
            "WHERE ST_Contains(geom, " + (enGrados ? PUNTO_LON_LAT : PUNTO_X_Y) + ") " +
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
                row.put("id", rs.getInt("id"));
                row.put("nombre", rs.getString("nombre"));
                return row;
            }
        }
    }

    // --------------------------------------------------------------- 6. Recursos por zona
    /** Recursos ubicados dentro de la zona dada. */
    @GET
    @Path("/recursos-por-zona/{zonaId}")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> recursosPorZona(@PathParam("zonaId") int zonaId) throws SQLException {
        String sql =
            "SELECT r.id, r.identificacion, r.tipo, r.estado_operativo " +
            "FROM recurso r, zona_operativa z " +
            "WHERE z.id = ? AND ST_Contains(z.geom, r.geom) " +
            "ORDER BY r.id";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, zonaId);
            return rowsToMaps(ps.executeQuery(), "id", "identificacion", "tipo", "estado_operativo");
        }
    }

    // ----------------------------------------------------------- 7. Incidentes por recurso
    /** Incidentes atendidos/asociados a un recurso (tabla incidente_recurso). */
    @GET
    @Path("/incidentes-por-recurso/{recursoId}")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> incidentesPorRecurso(@PathParam("recursoId") int recursoId) throws SQLException {
        String sql =
            "SELECT i.id, i.titulo, i.estado, ir.fecha_asignacion " +
            "FROM incidente i JOIN incidente_recurso ir ON ir.incidente_id = i.id " +
            "WHERE ir.recurso_id = ? " +
            "ORDER BY ir.fecha_asignacion DESC";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, recursoId);
            return rowsToMaps(ps.executeQuery(), "id", "titulo", "estado", "fecha_asignacion");
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
    public List<Map<String, Object>> reporteIncidentesPorZona(@QueryParam("zonaId") Integer zonaId,
                                                                @QueryParam("tipo") String tipo,
                                                                @QueryParam("prioridad") Integer prioridad,
                                                                @QueryParam("estado") String estado,
                                                                @QueryParam("desde") String desde,
                                                                @QueryParam("hasta") String hasta) throws SQLException {
        String sql =
            "SELECT z.id AS zona_id, z.nombre AS zona_nombre, i.id, i.titulo, i.tipo_incidente, i.prioridad, i.estado, i.fecha_hora_registro " +
            "FROM zona_operativa z " +
            "JOIN incidente i ON ST_Contains(z.geom, i.geom) " +
            "WHERE (?::int  IS NULL OR z.id = ?) " +
            "  AND (?::text IS NULL OR i.tipo_incidente = ?) " +
            "  AND (?::int  IS NULL OR i.prioridad = ?) " +
            "  AND (?::text IS NULL OR i.estado = ?) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro >= ?::timestamp) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro <  ?::timestamp) " +
            "ORDER BY z.nombre, i.fecha_hora_registro DESC";
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
            return rowsToMaps(ps.executeQuery(),
                    "zona_id", "zona_nombre", "id", "titulo", "tipo_incidente", "prioridad", "estado", "fecha_hora_registro");
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

    // ------------------------------------------------------- Figura dibujada en el mapa
    /** Cuerpo de POST /consultas/por-figura. geomGeoJson: la figura en lon/lat, como texto. */
    public static class FiguraInput {
        public String geomGeoJson;
        public Double distanciaM;
    }

    private static final String FIGURA = "ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)";
    private static final int MAX_POR_FIGURA = 200;
    private static final double MAX_DISTANCIA_M = 10000;

    /**
     * Qué hay dentro de, o cerca de, una línea o un polígono dibujado en el mapa. Para un polígono
     * (distancia 0 por defecto) son los puntos que caen adentro; para una línea (200 m por defecto)
     * los que están a menos de esa distancia, como un pasillo a lo largo de ella. Con una distancia
     * mayor a 0 se agranda la figura (ST_Buffer), y esa área se devuelve para dibujarla.
     * Todo lo resuelve PostGIS: ST_DWithin usa los índices espaciales, y se devuelven las medidas
     * de la figura (ST_Length, ST_Area, ST_Perimeter) y las zonas que toca. Cada lista trae como
     * máximo MAX_POR_FIGURA filas, las más cercanas, y el total real.
     */
    @POST
    @Path("/por-figura")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> porFigura(FiguraInput in) throws SQLException {
        if (in == null || in.geomGeoJson == null || in.geomGeoJson.trim().isEmpty()) {
            throw peticionInvalida("Falta la figura: dibujá una línea o un polígono");
        }
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            String tipo;
            boolean valida;
            double largo;
            double area;
            double perimetro;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT GeometryType(g), ST_IsValid(g), ST_Length(g), ST_Area(g), ST_Perimeter(g) " +
                    "FROM (SELECT " + FIGURA + " AS g) t")) {
                ps.setString(1, in.geomGeoJson);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    tipo = rs.getString(1);
                    valida = rs.getBoolean(2);
                    largo = rs.getDouble(3);
                    area = rs.getDouble(4);
                    perimetro = rs.getDouble(5);
                }
            } catch (SQLException e) {
                throw peticionInvalida("La figura no es un GeoJSON válido");
            }
            boolean esLinea = "LINESTRING".equals(tipo);
            if (!esLinea && !"POLYGON".equals(tipo)) {
                throw peticionInvalida("La figura tiene que ser una línea o un polígono");
            }
            if (!valida) {
                throw peticionInvalida("La figura no es válida (¿se cruza consigo misma?)");
            }

            double distancia = in.distanciaM != null ? in.distanciaM : (esLinea ? 200 : 0);
            if (distancia < 0 || distancia > MAX_DISTANCIA_M) {
                throw peticionInvalida("La distancia tiene que estar entre 0 y " + (int) MAX_DISTANCIA_M + " metros");
            }
            if (esLinea && distancia <= 0) {
                throw peticionInvalida("Para una línea indicá a cuántos metros buscar (mayor que 0)");
            }

            String base = "WITH g AS (SELECT " + FIGURA + " AS geom) ";
            Map<String, Object> respuesta = new LinkedHashMap<>();
            respuesta.put("tipo", esLinea ? "LineString" : "Polygon");
            respuesta.put("distanciaM", distancia);
            if (esLinea) {
                respuesta.put("largoM", Math.round(largo * 10) / 10.0);
            } else {
                respuesta.put("areaM2", Math.round(area));
                respuesta.put("perimetroM", Math.round(perimetro * 10) / 10.0);
            }

            // El área buscada: la figura agrandada por la distancia (solo si hay algo que dibujar).
            String areaBuscada = null;
            if (distancia > 0) {
                try (PreparedStatement ps = conn.prepareStatement(
                        "SELECT ST_AsGeoJSON(ST_Transform(ST_Buffer(g, ?), 4326)) FROM (SELECT " + FIGURA + " AS g) t")) {
                    ps.setDouble(1, distancia);
                    ps.setString(2, in.geomGeoJson);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) areaBuscada = rs.getString(1);
                    }
                }
            }
            respuesta.put("area", areaBuscada);

            respuesta.put("incidentes", buscarCerca(conn,
                base + "SELECT i.id, i.titulo, i.tipo_incidente, i.estado, i.prioridad, " +
                "       round(ST_Distance(i.geom, g.geom)::numeric, 1) AS distancia_m, count(*) OVER () AS total " +
                "FROM incidente i, g WHERE ST_DWithin(i.geom, g.geom, ?) " +
                "ORDER BY ST_Distance(i.geom, g.geom), i.id LIMIT " + MAX_POR_FIGURA,
                in.geomGeoJson, distancia, "id", "titulo", "tipo_incidente", "estado", "prioridad", "distancia_m"));
            respuesta.put("recursos", buscarCerca(conn,
                base + "SELECT r.id, r.identificacion, r.tipo, r.estado_operativo, " +
                "       round(ST_Distance(r.geom, g.geom)::numeric, 1) AS distancia_m, count(*) OVER () AS total " +
                "FROM recurso r, g WHERE ST_DWithin(r.geom, g.geom, ?) " +
                "ORDER BY ST_Distance(r.geom, g.geom), r.id LIMIT " + MAX_POR_FIGURA,
                in.geomGeoJson, distancia, "id", "identificacion", "tipo", "estado_operativo", "distancia_m"));
            respuesta.put("zonas", buscarCerca(conn,
                base + "SELECT z.id, z.nombre, z.nivel_prioridad, count(*) OVER () AS total " +
                "FROM zona_operativa z, g WHERE ST_DWithin(z.geom, g.geom, ?) ORDER BY z.nombre LIMIT " + MAX_POR_FIGURA,
                in.geomGeoJson, distancia, "id", "nombre", "nivel_prioridad").get("filas"));
            return respuesta;
        }
    }

    /** Ejecuta una consulta "base + distancia" y devuelve {total, filas}; total viene de count(*) OVER (). */
    private static Map<String, Object> buscarCerca(Connection conn, String sql, String geoJson, double distancia, String... columnas)
            throws SQLException {
        List<Map<String, Object>> filas = new ArrayList<>();
        long total = 0;
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, geoJson);
            ps.setDouble(2, distancia);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    total = rs.getLong("total");
                    Map<String, Object> fila = new LinkedHashMap<>();
                    for (String columna : columnas) fila.put(toCamelCase(columna), rs.getObject(columna));
                    filas.add(fila);
                }
            }
        }
        Map<String, Object> resultado = new LinkedHashMap<>();
        resultado.put("total", total);
        resultado.put("filas", filas);
        return resultado;
    }

    // -------------------------------------------------------- Dirección (calle y número)
    private static final String IDE_BUSQUEDA_DIRECCION = "https://direcciones.ide.uy/api/v0/geocode/BusquedaDireccion";
    private static final HttpClient HTTP = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
    private static final ObjectMapper JSON = new ObjectMapper();

    /** Cómo se abrevian en los nombres de calle de la base ("AV 18 DE JULIO", "CNO CARRASCO"). */
    private static final Map<String, String> ABREVIATURAS = Map.ofEntries(
        Map.entry("AVENIDA", "AV"), Map.entry("AVDA", "AV"), Map.entry("CAMINO", "CNO"),
        Map.entry("BULEVAR", "BV"), Map.entry("BOULEVARD", "BV"), Map.entry("PASAJE", "PSJE"),
        Map.entry("GENERAL", "GRAL"), Map.entry("DOCTOR", "DR"), Map.entry("DOCTORA", "DRA"),
        Map.entry("INGENIERO", "ING"), Map.entry("RAMBLA", "RBLA"), Map.entry("CIRCUITO", "CIRC"),
        Map.entry("CAPITAN", "CAP"), Map.entry("CORONEL", "CNEL"), Map.entry("ALMIRANTE", "ALM"),
        Map.entry("ARQUITECTO", "ARQ"), Map.entry("PROFESOR", "PROF"), Map.entry("TENIENTE", "TTE"),
        Map.entry("SARGENTO", "SGTO"), Map.entry("COMANDANTE", "CTE"), Map.entry("PRESIDENTE", "PTE"));

    private static final java.util.regex.Pattern CALLE_Y_NUMERO =
        java.util.regex.Pattern.compile("^(.+?)\\s+(\\d{1,6})\\s*([A-Z])?$");

    /** Mayúsculas, sin tildes ni puntuación y con las palabras abreviadas como en la base. */
    private static String normalizarCalle(String texto) {
        String limpio = java.text.Normalizer.normalize(texto, java.text.Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "").toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9 ]", " ").trim();
        StringBuilder sb = new StringBuilder();
        for (String palabra : limpio.split("\\s+")) {
            if (sb.length() > 0) sb.append(' ');
            sb.append(ABREVIATURAS.getOrDefault(palabra, palabra));
        }
        return sb.toString();
    }

    /**
     * Ubica una dirección "calle número" (por ejemplo "Camino Carrasco 4680" o "18 de Julio 1000")
     * y devuelve lon/lat (EPSG:4326), que se usan en "incidente más cercano" y "zona de un punto".
     * Se busca en la tabla acceso (los números de puerta de Montevideo, capa mdg_accesos de la
     * Intendencia; la capa "acceso" de GeoServer es esa misma tabla). La calle se compara por
     * nombre tolerando abreviaturas y errores de tipeo. Si el número no existe se usa la puerta más
     * cercana de esa calle y se marca "aproximada". Lo que no se resuelve acá ("calle esquina
     * calle", calles que no están en la base) se pasa al servicio de direcciones de la IDE.
     */
    @GET
    @Path("/geocodificar")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> geocodificar(@QueryParam("direccion") String direccion) throws SQLException {
        if (direccion == null || direccion.trim().isEmpty()) {
            throw peticionInvalida("Falta la dirección (por ejemplo: Buenos Aires 451)");
        }
        java.util.regex.Matcher m = CALLE_Y_NUMERO.matcher(normalizarCalle(direccion));
        if (m.matches() && !m.group(1).contains(" ESQ")) {
            Map<String, Object> propio = buscarPuerta(m.group(1), Integer.parseInt(m.group(2)), m.group(3));
            if (propio != null) return propio;
        }
        return geocodificarConIde(direccion);
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
                    resultado.put("fuente", "Puertas de Montevideo");
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
    private Map<String, Object> geocodificarConIde(String direccion) {
        String url = IDE_BUSQUEDA_DIRECCION
            + "?calle=" + URLEncoder.encode(direccion.trim(), StandardCharsets.UTF_8)
            + "&departamento=montevideo&localidad=montevideo";
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
                .entity(Map.of("error", "No se encontró esa dirección. Probá con el formato \"calle número\", por ejemplo: Buenos Aires 451"))
                .build());
        }
        JsonNode mejor = lista.get(0);
        JsonNode datos = mejor.path("direccion");
        String calle = datos.path("calle").path("nombre_normalizado").asText("");
        String numero = datos.path("numero").path("nro_puerta").asText("");
        String esquina = datos.path("esquina").path("nombre_normalizado").asText("");
        String texto = !esquina.isEmpty() ? calle + " esq. " + esquina
            : !numero.isEmpty() ? calle + " " + numero
            : direccion.trim();
        String error = mejor.path("error").asText("").trim();

        Map<String, Object> resultado = new LinkedHashMap<>();
        resultado.put("direccion", texto);
        resultado.put("fuente", "IDE");
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
