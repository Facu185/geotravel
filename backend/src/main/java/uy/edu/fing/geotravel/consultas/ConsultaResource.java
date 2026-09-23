package uy.edu.fing.geotravel.consultas;

import uy.edu.fing.geotravel.db.DataSourceProvider;

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
 * Cada método corresponde a uno de los 5 requerimientos del enunciado
 * (ver docs/api/openapi.yaml para el contrato completo). Los dos que dependen
 * de datos externos (calles, geocodificación de direcciones) reciben ya
 * resuelta la coordenada -- esa resolución (WFS de v_sig_vias / un geocoder,
 * como en el Práctico 3) puede hacerse en el frontend o en un endpoint propio.
 */
@Path("/consultas")
public class ConsultaResource {

    /** Recorridos que tienen al menos una atracción dentro de la zona dada. */
    @GET
    @Path("/recorridos-por-zona/{zonaId}")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> recorridosPorZona(@PathParam("zonaId") int zonaId) throws SQLException {
        String sql =
            "SELECT DISTINCT r.id, r.nombre, r.estado " +
            "FROM recorrido r " +
            "JOIN recorrido_atraccion ra ON ra.recorrido_id = r.id " +
            "JOIN atraccion a ON a.id = ra.atraccion_id " +
            "JOIN zona_turistica z ON z.id = ? AND ST_Contains(z.geom, a.geom) " +
            "ORDER BY r.id";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, zonaId);
            return rowsToMaps(ps.executeQuery(), "id", "nombre", "estado");
        }
    }

    /** Zonas ordenadas por cantidad de recorridos actualmente "Disponible". */
    @GET
    @Path("/zonas-mas-activas")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> zonasMasActivas() throws SQLException {
        String sql =
            "SELECT z.id, z.nombre, count(DISTINCT r.id) AS recorridos_activos " +
            "FROM zona_turistica z " +
            "JOIN atraccion a ON ST_Contains(z.geom, a.geom) " +
            "JOIN recorrido_atraccion ra ON ra.atraccion_id = a.id " +
            "JOIN recorrido r ON r.id = ra.recorrido_id AND r.estado = 'Disponible' " +
            "GROUP BY z.id, z.nombre " +
            "ORDER BY recorridos_activos DESC";
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            return rowsToMaps(rs, "id", "nombre", "recorridos_activos");
        }
    }

    /** Atracciones más populares = incluidas en más recorridos. */
    @GET
    @Path("/puntos-populares")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> puntosPopulares() throws SQLException {
        String sql =
            "SELECT a.id, a.nombre, count(ra.recorrido_id) AS cantidad_recorridos " +
            "FROM atraccion a " +
            "JOIN recorrido_atraccion ra ON ra.atraccion_id = a.id " +
            "GROUP BY a.id, a.nombre " +
            "ORDER BY cantidad_recorridos DESC";
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            return rowsToMaps(rs, "id", "nombre", "cantidad_recorridos");
        }
    }

    /**
     * Recorrido cuya atracción más cercana al punto dado (x, y en EPSG:32721).
     * Para "el cruce de dos calles": resolvé antes el punto de intersección
     * (mismo patrón que el ejercicio 6 del Práctico 2) y pasalo acá.
     */
    @GET
    @Path("/recorrido-mas-cercano")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> recorridoMasCercano(@QueryParam("x") double x, @QueryParam("y") double y) throws SQLException {
        String sql =
            "SELECT r.id, r.nombre, a.nombre AS atraccion_mas_cercana, " +
            "       ST_Distance(a.geom, ST_SetSRID(ST_MakePoint(?, ?), 32721)) AS distancia_m " +
            "FROM atraccion a " +
            "JOIN recorrido_atraccion ra ON ra.atraccion_id = a.id " +
            "JOIN recorrido r ON r.id = ra.recorrido_id " +
            "ORDER BY a.geom <-> ST_SetSRID(ST_MakePoint(?, ?), 32721) " +
            "LIMIT 1";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDouble(1, x); ps.setDouble(2, y);
            ps.setDouble(3, x); ps.setDouble(4, y);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return Map.of();
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("id", rs.getInt("id"));
                row.put("nombre", rs.getString("nombre"));
                row.put("atraccionMasCercana", rs.getString("atraccion_mas_cercana"));
                row.put("distanciaM", rs.getDouble("distancia_m"));
                return row;
            }
        }
    }

    /**
      Reporte de recorridos agrupados por zona, filtrable por estado (parametro opcional).
      Una atraccion "pertenece" a una zona si está geométricamente contenida en ella; un
      recorrido pertenece a una zona si tiene al menos una atracción adentro (mismo criterio
      que recorridosPorZona). Las zonas sin recorridos que cumplan el filtro no aparecen.
     */
    @GET
    @Path("/reportes/recorridos-por-zona")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> reporteRecorridosPorZona(@QueryParam("estado") String estado) throws SQLException {
        String sql =
            "SELECT z.id AS zona_id, z.nombre AS zona_nombre, " +
            "       r.id AS recorrido_id, r.nombre AS recorrido_nombre, r.estado " +
            "FROM zona_turistica z " +
            "JOIN atraccion a ON ST_Contains(z.geom, a.geom) " +
            "JOIN recorrido_atraccion ra ON ra.atraccion_id = a.id " +
            "JOIN recorrido r ON r.id = ra.recorrido_id " +
            "WHERE (? IS NULL OR r.estado = ?) " +
            "GROUP BY z.id, z.nombre, r.id, r.nombre, r.estado " +
            "ORDER BY z.nombre, r.nombre";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, estado);
            ps.setString(2, estado);
            try (ResultSet rs = ps.executeQuery()) {
                Map<Integer, Map<String, Object>> zonas = new LinkedHashMap<>();
                while (rs.next()) {
                    int zonaId = rs.getInt("zona_id");
                    Map<String, Object> zona = zonas.computeIfAbsent(zonaId, id -> {
                        Map<String, Object> z = new LinkedHashMap<>();
                        z.put("zonaId", id);
                        try {
                            z.put("zonaNombre", rs.getString("zona_nombre"));
                        } catch (SQLException e) {
                            throw new RuntimeException(e);
                        }
                        z.put("recorridos", new ArrayList<Map<String, Object>>());
                        return z;
                    });
                    Map<String, Object> recorrido = new LinkedHashMap<>();
                    recorrido.put("id", rs.getInt("recorrido_id"));
                    recorrido.put("nombre", rs.getString("recorrido_nombre"));
                    recorrido.put("estado", rs.getString("estado"));
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> recorridos = (List<Map<String, Object>>) zona.get("recorridos");
                    recorridos.add(recorrido);
                }
                return new ArrayList<>(zonas.values());
            }
        }
    }

    /** Zona que contiene el punto dado (x, y en EPSG:32721) -- ya geocodificada la dirección. */
    @GET
    @Path("/zona-por-punto")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> zonaPorPunto(@QueryParam("x") double x, @QueryParam("y") double y) throws SQLException {
        String sql =
            "SELECT id, nombre FROM zona_turistica " +
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

    // --- helper: cualquier ResultSet -> List<Map<columna, valor>>, solo para las columnas pedidas ---
    private static List<Map<String, Object>> rowsToMaps(ResultSet rs, String... columns) throws SQLException {
        List<Map<String, Object>> rows = new ArrayList<>();
        while (rs.next()) {
            Map<String, Object> row = new LinkedHashMap<>();
            for (String col : columns) {
                row.put(toCamelCase(col), rs.getObject(col));
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
