package uy.edu.fing.geotravel.atracciones;

import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.Consumes;
import javax.ws.rs.DELETE;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.PUT;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Módulo Atracciones (dueño: P3): ABM de atracciones turísticas puntuales.
 * Misma convención de SRID que ZonaResource: la base usa 32721, la API habla 4326 (lon/lat).
 */
@Path("/atracciones")
public class AtraccionResource {

    /** Únicos valores que conocen los estilos de GeoServer (geoserver/styles/atracciones_clasificacion.sld). */
    private static final List<String> CLASIFICACIONES =
            Arrays.asList("cultural", "gastronomica", "natural", "historica");

    private static final String GEOM_IN =
            "ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)";

    private static final String SELECT_ALL =
            "SELECT id, nombre, descripcion, clasificacion, foto_url, "
          + "       ST_AsGeoJSON(ST_Transform(geom, 4326)) AS geom_json "
          + "FROM atraccion ORDER BY id";

    public static class AtraccionInput {
        public String nombre;
        public String descripcion;
        public String clasificacion;
        public String fotoUrl;       // opcional
        public String geomGeoJson;   // GeoJSON Point en lon/lat, como texto
    }

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> listar() throws SQLException {
        List<Map<String, Object>> atracciones = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(SELECT_ALL)) {

            while (rs.next()) {
                Map<String, Object> a = new LinkedHashMap<>();
                a.put("id", rs.getInt("id"));
                a.put("nombre", rs.getString("nombre"));
                a.put("descripcion", rs.getString("descripcion"));
                a.put("clasificacion", rs.getString("clasificacion"));
                a.put("fotoUrl", rs.getString("foto_url"));
                a.put("geom", rs.getString("geom_json")); // texto GeoJSON: el frontend hace JSON.parse
                atracciones.add(a);
            }
        }
        return atracciones;
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response crear(AtraccionInput in) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            Response invalida = validar(conn, in);
            if (invalida != null) {
                return invalida;
            }
            String sql = "INSERT INTO atraccion (nombre, descripcion, clasificacion, foto_url, geom) "
                       + "VALUES (?, ?, ?, ?, " + GEOM_IN + ") RETURNING id";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, in.nombre.trim());
                ps.setString(2, in.descripcion);
                ps.setString(3, in.clasificacion);
                ps.setString(4, vacioANull(in.fotoUrl));
                ps.setString(5, in.geomGeoJson);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    return Response.status(Response.Status.CREATED).entity(Map.of("id", rs.getInt("id"))).build();
                }
            }
        }
    }

    @PUT
    @Path("/{id}")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response editar(@PathParam("id") int id, AtraccionInput in) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            Response invalida = validar(conn, in);
            if (invalida != null) {
                return invalida;
            }
            String sql = "UPDATE atraccion SET nombre = ?, descripcion = ?, clasificacion = ?, "
                       + "foto_url = ?, geom = " + GEOM_IN + " WHERE id = ?";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, in.nombre.trim());
                ps.setString(2, in.descripcion);
                ps.setString(3, in.clasificacion);
                ps.setString(4, vacioANull(in.fotoUrl));
                ps.setString(5, in.geomGeoJson);
                ps.setInt(6, id);
                return ps.executeUpdate() == 0
                        ? error(Response.Status.NOT_FOUND.getStatusCode(), "La atracción no existe")
                        : Response.ok(Map.of("id", id)).build();
            }
        }
    }

    @DELETE
    @Path("/{id}")
    public Response eliminar(@PathParam("id") int id) throws SQLException {
        // recorrido_atraccion tiene ON DELETE CASCADE: al borrar la atracción se quita de los itinerarios.
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM atraccion WHERE id = ?")) {
            ps.setInt(1, id);
            return ps.executeUpdate() == 0
                    ? error(Response.Status.NOT_FOUND.getStatusCode(), "La atracción no existe")
                    : Response.noContent().build();
        }
    }

    // ------------------------------------------------------------------ validaciones

    private static Response validar(Connection conn, AtraccionInput in) {
        if (in == null || in.nombre == null || in.nombre.trim().isEmpty()) {
            return error(400, "El nombre es obligatorio");
        }
        if (in.clasificacion == null || !CLASIFICACIONES.contains(in.clasificacion)) {
            return error(400, "La clasificación debe ser una de: " + String.join(", ", CLASIFICACIONES));
        }
        if (in.fotoUrl != null && !in.fotoUrl.trim().isEmpty()
                && !in.fotoUrl.matches("(?i)^https?://\\S+$")) {
            return error(400, "La foto debe ser una URL http(s)");
        }
        if (in.geomGeoJson == null || !esPuntoValido(conn, in.geomGeoJson)) {
            return error(400, "La ubicación no es un punto válido");
        }
        return null;
    }

    private static boolean esPuntoValido(Connection conn, String geojson) {
        String sql = "SELECT GeometryType(g) = 'POINT' FROM (SELECT " + GEOM_IN + " AS g) t";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, geojson);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getBoolean(1);
            }
        } catch (SQLException e) {
            return false; // GeoJSON mal formado
        }
    }

    private static String vacioANull(String s) {
        return (s == null || s.trim().isEmpty()) ? null : s.trim();
    }

    private static Response error(int status, String mensaje) {
        return Response.status(status).type(MediaType.APPLICATION_JSON).entity(Map.of("error", mensaje)).build();
    }
}
