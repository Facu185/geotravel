package uy.edu.fing.geotravel.recursos;

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
 * Módulo Recursos de emergencia (dueño: P3): ABM de ambulancias, bomberos, patrullas,
 * centros de atención, etc.
 *
 * Reemplaza al antiguo módulo "Atracciones" de GeoTravel: misma forma (ABM de un punto
 * en el mapa), pero sin foto -- la letra de UrbanSafe no la pide -- y con "tipo" como
 * texto libre en vez de una lista cerrada de 4 valores, porque el enunciado da ejemplos
 * ("ambulancias, vehículos de bomberos, patrullas, centros de atención y otros recursos")
 * sin cerrar la lista. Si el tutor confirma que debe ser una lista fija, restringir
 * TIPOS igual que CLASIFICACIONES en la versión anterior.
 */
@Path("/recursos")
public class RecursoResource {

    /** Únicos valores de estado operativo que acepta el sistema. */
    private static final List<String> ESTADOS_OPERATIVOS =
            Arrays.asList("Disponible", "En servicio", "Fuera de servicio");

    private static final String GEOM_IN =
            "ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)";

    private static final String SELECT_ALL =
            "SELECT id, identificacion, nombre, tipo, estado_operativo, descripcion, "
          + "       ST_AsGeoJSON(ST_Transform(geom, 4326)) AS geom_json "
          + "FROM recurso ORDER BY id";

    public static class RecursoInput {
        public String identificacion;
        public String nombre;        // opcional
        public String tipo;
        public String estadoOperativo;
        public String descripcion;
        public String geomGeoJson;   // GeoJSON Point en lon/lat, como texto
    }

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> listar() throws SQLException {
        List<Map<String, Object>> recursos = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(SELECT_ALL)) {

            while (rs.next()) {
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("id", rs.getInt("id"));
                r.put("identificacion", rs.getString("identificacion"));
                r.put("nombre", rs.getString("nombre"));
                r.put("tipo", rs.getString("tipo"));
                r.put("estadoOperativo", rs.getString("estado_operativo"));
                r.put("descripcion", rs.getString("descripcion"));
                r.put("geom", rs.getString("geom_json")); // texto GeoJSON: el frontend hace JSON.parse
                recursos.add(r);
            }
        }
        return recursos;
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response crear(RecursoInput in) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            Response invalida = validar(conn, in);
            if (invalida != null) {
                return invalida;
            }
            String sql = "INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom) "
                       + "VALUES (?, ?, ?, ?, ?, " + GEOM_IN + ") RETURNING id";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, in.identificacion.trim());
                ps.setString(2, vacioANull(in.nombre));
                ps.setString(3, in.tipo);
                ps.setString(4, in.estadoOperativo);
                ps.setString(5, in.descripcion);
                ps.setString(6, in.geomGeoJson);
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
    public Response editar(@PathParam("id") int id, RecursoInput in) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            Response invalida = validar(conn, in);
            if (invalida != null) {
                return invalida;
            }
            String sql = "UPDATE recurso SET identificacion = ?, nombre = ?, tipo = ?, "
                       + "estado_operativo = ?, descripcion = ?, geom = " + GEOM_IN + " WHERE id = ?";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, in.identificacion.trim());
                ps.setString(2, vacioANull(in.nombre));
                ps.setString(3, in.tipo);
                ps.setString(4, in.estadoOperativo);
                ps.setString(5, in.descripcion);
                ps.setString(6, in.geomGeoJson);
                ps.setInt(7, id);
                return ps.executeUpdate() == 0
                        ? error(Response.Status.NOT_FOUND.getStatusCode(), "El recurso no existe")
                        : Response.ok(Map.of("id", id)).build();
            }
        }
    }

    @DELETE
    @Path("/{id}")
    public Response eliminar(@PathParam("id") int id) throws SQLException {
        // incidente_recurso tiene ON DELETE CASCADE: al borrar el recurso se quita de las asignaciones.
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM recurso WHERE id = ?")) {
            ps.setInt(1, id);
            return ps.executeUpdate() == 0
                    ? error(Response.Status.NOT_FOUND.getStatusCode(), "El recurso no existe")
                    : Response.noContent().build();
        }
    }

    // ------------------------------------------------------------------ validaciones

    private static Response validar(Connection conn, RecursoInput in) {
        if (in == null || in.identificacion == null || in.identificacion.trim().isEmpty()) {
            return error(400, "La identificación es obligatoria");
        }
        if (in.tipo == null || in.tipo.trim().isEmpty()) {
            return error(400, "El tipo es obligatorio");
        }
        if (in.estadoOperativo == null || !ESTADOS_OPERATIVOS.contains(in.estadoOperativo)) {
            return error(400, "El estado operativo debe ser uno de: " + String.join(", ", ESTADOS_OPERATIVOS));
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
