package uy.edu.fing.geotravel.zonas;

import uy.edu.fing.geotravel.db.DataSourceProvider;
import uy.edu.fing.geotravel.mapa.Bbox;

import javax.ws.rs.Consumes;
import javax.ws.rs.DELETE;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.PUT;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Módulo Zonas Operativas (dueño: P3): ABM de las zonas que usa UrbanSafe para organizar
 * la atención de incidentes.
 *
 * SRID: la base guarda todo en EPSG:32721 (metros) pero Leaflet dibuja y envía
 * lon/lat (EPSG:4326). Por eso:
 *   - al LEER se transforma a 4326:  ST_Transform(geom, 4326)
 *   - al GUARDAR se transforma a 32721 (GEOM_IN, abajo)
 *
 * Las zonas PUEDEN superponerse (lo definió el tutor): al guardar solo se valida que el
 * polígono sea válido. Consecuencia para las consultas: un punto, un recurso o un incidente
 * puede estar en más de una zona a la vez.
 */
@Path("/zonas")
public class ZonaResource {

    /** GeoJSON en lon/lat (lo que dibuja Leaflet) -> geometría en el SRID de la base. */
    private static final String GEOM_IN =
            "ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)";

    private static final String COLUMNAS =
            "SELECT id, nombre, descripcion, nivel_prioridad, responsable, observaciones, "
          + "       ST_AsGeoJSON(ST_Transform(geom, 4326)) AS geom_json ";

    private static final String SELECT_ALL = COLUMNAS + "FROM zona_operativa ORDER BY id";

    /** Zonas del rectángulo visible. COUNT(*) OVER() se calcula antes del LIMIT: es el total real. */
    private static final String SELECT_BBOX =
            COLUMNAS + ", COUNT(*) OVER () AS total FROM zona_operativa WHERE " + Bbox.FILTRO + " ORDER BY id LIMIT ?";

    /** Cuerpo JSON de POST/PUT. geomGeoJson es la geometría como texto GeoJSON (JSON.stringify en el frontend). */
    public static class ZonaInput {
        public String nombre;
        public String descripcion;
        public int nivelPrioridad;
        public String responsable;
        public String observaciones;
        public String geomGeoJson;
    }

    /**
     * Sin bbox: todas las zonas, como lista (lo sigue usando Consultas).
     * Con bbox: solo las del rectángulo visible, hasta "limit", como {items, total, truncado}.
     */
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response listar(@QueryParam("bbox") String bbox, @QueryParam("limit") Integer limit) throws SQLException {
        if (bbox == null) {
            return Response.ok(listarTodas()).build();
        }
        Bbox rect;
        int limite;
        try {
            rect = Bbox.parse(bbox);
            limite = Bbox.limite(limit);
        } catch (IllegalArgumentException e) {
            return error(400, e.getMessage());
        }
        List<Map<String, Object>> zonas = new ArrayList<>();
        int total = 0;
        if (!rect.vacio()) {
            try (Connection conn = DataSourceProvider.get().getConnection();
                 PreparedStatement ps = conn.prepareStatement(SELECT_BBOX)) {
                ps.setInt(rect.enlazar(ps, 1), limite);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        total = rs.getInt("total");
                        zonas.add(aZona(rs));
                    }
                }
            }
        }
        return Response.ok(Bbox.resultado(zonas, total)).build();
    }

    private static List<Map<String, Object>> listarTodas() throws SQLException {
        List<Map<String, Object>> zonas = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(SELECT_ALL)) {

            while (rs.next()) {
                zonas.add(aZona(rs));
            }
        }
        return zonas;
    }

    private static Map<String, Object> aZona(ResultSet rs) throws SQLException {
        Map<String, Object> zona = new LinkedHashMap<>();
        zona.put("id", rs.getInt("id"));
        zona.put("nombre", rs.getString("nombre"));
        zona.put("descripcion", rs.getString("descripcion"));
        zona.put("nivelPrioridad", rs.getInt("nivel_prioridad"));
        zona.put("responsable", rs.getString("responsable"));
        zona.put("observaciones", rs.getString("observaciones"));
        zona.put("geom", rs.getString("geom_json")); // texto GeoJSON: el frontend hace JSON.parse
        return zona;
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response crear(ZonaInput in) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            Response invalida = validar(conn, in);
            if (invalida != null) {
                return invalida;
            }
            String sql = "INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, observaciones, geom) "
                       + "VALUES (?, ?, ?, ?, ?, " + GEOM_IN + ") RETURNING id";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, in.nombre.trim());
                ps.setString(2, in.descripcion);
                ps.setInt(3, in.nivelPrioridad);
                ps.setString(4, in.responsable);
                ps.setString(5, in.observaciones);
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
    public Response editar(@PathParam("id") int id, ZonaInput in) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            Response invalida = validar(conn, in);
            if (invalida != null) {
                return invalida;
            }
            String sql = "UPDATE zona_operativa SET nombre = ?, descripcion = ?, nivel_prioridad = ?, "
                       + "responsable = ?, observaciones = ?, geom = " + GEOM_IN + " WHERE id = ?";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, in.nombre.trim());
                ps.setString(2, in.descripcion);
                ps.setInt(3, in.nivelPrioridad);
                ps.setString(4, in.responsable);
                ps.setString(5, in.observaciones);
                ps.setString(6, in.geomGeoJson);
                ps.setInt(7, id);
                return ps.executeUpdate() == 0
                        ? error(Response.Status.NOT_FOUND.getStatusCode(), "La zona no existe")
                        : Response.ok(Map.of("id", id)).build();
            }
        }
    }

    @DELETE
    @Path("/{id}")
    public Response eliminar(@PathParam("id") int id) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM zona_operativa WHERE id = ?")) {
            ps.setInt(1, id);
            return ps.executeUpdate() == 0
                    ? error(Response.Status.NOT_FOUND.getStatusCode(), "La zona no existe")
                    : Response.noContent().build();
        }
    }

    // ------------------------------------------------------------------ validaciones

    /**
     * @return null si todo está bien; si no, la Response de error (400 datos inválidos).
     * Las zonas SÍ pueden superponerse (lo definió el tutor): no se controla contra las demás.
     */
    private static Response validar(Connection conn, ZonaInput in) {
        if (in == null || in.nombre == null || in.nombre.trim().isEmpty()) {
            return error(400, "El nombre es obligatorio");
        }
        if (in.nivelPrioridad < 1 || in.nivelPrioridad > 5) {
            return error(400, "El nivel de prioridad debe estar entre 1 y 5");
        }
        if (in.geomGeoJson == null || !esPoligonoValido(conn, in.geomGeoJson)) {
            return error(400, "La geometría no es un polígono válido");
        }
        return null;
    }

    private static boolean esPoligonoValido(Connection conn, String geojson) {
        String sql = "SELECT ST_IsValid(g) AND GeometryType(g) = 'POLYGON' "
                   + "FROM (SELECT " + GEOM_IN + " AS g) t";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, geojson);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getBoolean(1);
            }
        } catch (SQLException e) {
            return false; // GeoJSON mal formado
        }
    }

    private static Response error(int status, String mensaje) {
        return Response.status(status).type(MediaType.APPLICATION_JSON).entity(Map.of("error", mensaje)).build();
    }
}
