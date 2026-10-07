package uy.edu.fing.geotravel.consultas;

import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.DefaultValue;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;
import java.sql.*;
import java.util.*;

/**
 * Módulo Consultas geográficas y reportes (dueño: P5).
 * Cada método corresponde a uno de los 8 requerimientos de la letra de UrbanSafe (ver
 * docs/api/openapi.yaml para el contrato completo). Reemplaza al ConsultaResource de
 * GeoTravel -- mismos patrones SQL (point-in-polygon, nearest, agregaciones), aplicados
 * a zona_operativa / incidente / recurso en vez de zona_turistica / recorrido / atraccion.
 *
 * "Búsqueda de incidente/zona por dirección o intersección de calles" recibe ya resuelta
 * la coordenada (x, y) -- esa resolución (WFS de una capa de calles / un geocoder, como en
 * el Práctico 3 del curso) puede hacerse en el frontend o en un endpoint propio.
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
    public List<Map<String, Object>> zonasMayorConcentracion() throws SQLException {
        String sql =
            "SELECT z.id, z.nombre, count(i.id) AS cantidad_incidentes, " +
            "       round((count(i.id) / (ST_Area(z.geom) / 1e6))::numeric, 3) AS incidentes_por_km2 " +
            "FROM zona_operativa z " +
            "LEFT JOIN incidente i ON ST_Contains(z.geom, i.geom) " +
            "GROUP BY z.id, z.nombre, z.geom " +
            "ORDER BY incidentes_por_km2 DESC";
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            return rowsToMaps(rs, "id", "nombre", "cantidad_incidentes", "incidentes_por_km2");
        }
    }

    // ---------------------------------------------------- 3. Recursos cercanos a un incidente
    /** Los recursos más cercanos al incidente dado, ordenados por distancia. */
    @GET
    @Path("/recursos-cercanos/{incidenteId}")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> recursosCercanos(@PathParam("incidenteId") int incidenteId,
                                                        @QueryParam("limite") @DefaultValue("5") int limite)
            throws SQLException {
        int max = limite < 1 ? 5 : limite;
        String sql =
            "SELECT r.id, r.identificacion, r.tipo, r.estado_operativo, " +
            "       ST_Distance(r.geom, i.geom) AS distancia_m " +
            "FROM recurso r, incidente i " +
            "WHERE i.id = ? " +
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
    public Map<String, Object> incidenteMasCercano(@QueryParam("x") double x, @QueryParam("y") double y) throws SQLException {
        String sql =
            "SELECT id, titulo, estado, " +
            "       ST_Distance(geom, ST_SetSRID(ST_MakePoint(?, ?), 32721)) AS distancia_m " +
            "FROM incidente " +
            "ORDER BY geom <-> ST_SetSRID(ST_MakePoint(?, ?), 32721) " +
            "LIMIT 1";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDouble(1, x); ps.setDouble(2, y);
            ps.setDouble(3, x); ps.setDouble(4, y);
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
    public Map<String, Object> zonaPorPunto(@QueryParam("x") double x, @QueryParam("y") double y) throws SQLException {
        String sql =
            "SELECT id, nombre FROM zona_operativa " +
            "WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(?, ?), 32721)) " +
            "LIMIT 1";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDouble(1, x); ps.setDouble(2, y);
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
     * consulta geográfica #1): filtrable por tipo/prioridad/estado/rango de fechas,
     * agrupado por zona. Todos los filtros son opcionales.
     */
    @GET
    @Path("/reportes/incidentes-por-zona")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> reporteIncidentesPorZona(@QueryParam("tipo") String tipo,
                                                                @QueryParam("prioridad") Integer prioridad,
                                                                @QueryParam("estado") String estado,
                                                                @QueryParam("desde") String desde,
                                                                @QueryParam("hasta") String hasta) throws SQLException {
        String sql =
            "SELECT z.id AS zona_id, z.nombre AS zona_nombre, i.id, i.titulo, i.tipo_incidente, i.prioridad, i.estado, i.fecha_hora_registro " +
            "FROM zona_operativa z " +
            "JOIN incidente i ON ST_Contains(z.geom, i.geom) " +
            "WHERE (?::text IS NULL OR i.tipo_incidente = ?) " +
            "  AND (?::int  IS NULL OR i.prioridad = ?) " +
            "  AND (?::text IS NULL OR i.estado = ?) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro >= ?::timestamp) " +
            "  AND (?::timestamp IS NULL OR i.fecha_hora_registro <  ?::timestamp) " +
            "ORDER BY z.nombre, i.fecha_hora_registro DESC";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, tipo); ps.setString(2, tipo);
            if (prioridad == null) { ps.setNull(3, Types.INTEGER); ps.setNull(4, Types.INTEGER); }
            else { ps.setInt(3, prioridad); ps.setInt(4, prioridad); }
            ps.setString(5, estado); ps.setString(6, estado);
            ps.setString(7, desde); ps.setString(8, desde);
            ps.setString(9, hasta); ps.setString(10, hasta);
            return rowsToMaps(ps.executeQuery(),
                    "zona_id", "zona_nombre", "id", "titulo", "tipo_incidente", "prioridad", "estado", "fecha_hora_registro");
        }
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
