package uy.edu.fing.geotravel.incidentes;

import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.sql.*;
import java.util.*;

/**
 * Módulo Incidentes (dueño: P4): ABM + máquina de estados + histórico.
 *
 * Reemplaza al módulo "Recorridos" de GeoTravel. Cambia sustancialmente:
 *  - NO hay estacionalidad (no existe el concepto en UrbanSafe) -- se elimina por completo
 *    el cálculo de "estado efectivo" que tenía RecorridoResource.
 *  - La máquina de estados pasa de ser una secuencia lineal (3 pasos) a tener RAMAS:
 *    5 estados, con Derivado y Cancelado alcanzables desde más de un estado. Por eso
 *    "avanzar" ahora recibe el estado DESTINO en el cuerpo, no es un botón único.
 *  - El historial guarda también qué usuario hizo el cambio.
 *
 * SUPUESTO a confirmar con el tutor (ver TRANSICIONES abajo): el diagrama de estados no
 * está dibujado en la letra, solo un ejemplo ("Registrado → En atención → Resuelto") y la
 * mención de que existen derivación y cancelación. Mientras no se confirme, se asume:
 *   Registrado   -> En atención | Derivado | Cancelado
 *   En atención  -> Resuelto | Derivado | Cancelado
 *   Derivado     -> En atención | Cancelado
 *   Resuelto, Cancelado -> (estados terminales, sin salida)
 */
@Path("/incidentes")
public class IncidenteResource {

    private static final List<String> ESTADOS =
            Arrays.asList("Registrado", "En atención", "Derivado", "Resuelto", "Cancelado");

    /** Transiciones válidas desde cada estado. Ver el SUPUESTO en el comentario de la clase. */
    private static final Map<String, Set<String>> TRANSICIONES = new LinkedHashMap<>();
    static {
        TRANSICIONES.put("Registrado",  new LinkedHashSet<>(Arrays.asList("En atención", "Derivado", "Cancelado")));
        TRANSICIONES.put("En atención", new LinkedHashSet<>(Arrays.asList("Resuelto", "Derivado", "Cancelado")));
        TRANSICIONES.put("Derivado",    new LinkedHashSet<>(Arrays.asList("En atención", "Cancelado")));
        TRANSICIONES.put("Resuelto",    Collections.emptySet());
        TRANSICIONES.put("Cancelado",   Collections.emptySet());
    }

    private static final String GEOM_IN =
            "ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)";

    private static final String SELECT_ALL =
            "SELECT id, titulo, descripcion, tipo_incidente, prioridad, estado, "
          + "       fecha_hora_registro, equipo_responsable, "
          + "       ST_AsGeoJSON(ST_Transform(geom, 4326)) AS geom_json "
          + "FROM incidente ORDER BY fecha_hora_registro DESC";

    public static class IncidenteInput {
        public String titulo;
        public String descripcion;
        public String tipoIncidente;
        public int prioridad;
        public String equipoResponsable;
        public String geomGeoJson; // GeoJSON Point en lon/lat, como texto
    }

    public static class AvanzarInput {
        public String estado;   // estado destino
        public String usuario;  // quién hace el cambio (sin login real: texto libre, opcional)
    }

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> listar() throws SQLException {
        List<Map<String, Object>> incidentes = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(SELECT_ALL)) {
            while (rs.next()) {
                incidentes.add(filaAMapa(rs));
            }
        }
        return incidentes;
    }

    @GET
    @Path("/{id}/historial")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> historial(@PathParam("id") int id) throws SQLException {
        String sql = "SELECT estado, fecha_hora, usuario FROM historial_estado "
                   + "WHERE incidente_id = ? ORDER BY fecha_hora, id";
        List<Map<String, Object>> filas = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> h = new LinkedHashMap<>();
                    h.put("estado", rs.getString("estado"));
                    h.put("fechaHora", rs.getTimestamp("fecha_hora").toInstant().toString());
                    h.put("usuario", rs.getString("usuario"));
                    filas.add(h);
                }
            }
        }
        return filas;
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response crear(IncidenteInput in) throws SQLException {
        Response invalida = validar(in);
        if (invalida != null) {
            return invalida;
        }
        // El estado inicial siempre es 'Registrado' (el DEFAULT de la columna) y el propio
        // trigger de la base dispara el primer registro de historial -- no se setea acá.
        String sql = "INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, equipo_responsable, geom) "
                   + "VALUES (?, ?, ?, ?, ?, " + GEOM_IN + ") RETURNING id";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, in.titulo.trim());
            ps.setString(2, in.descripcion);
            ps.setString(3, in.tipoIncidente);
            ps.setInt(4, in.prioridad);
            ps.setString(5, in.equipoResponsable);
            ps.setString(6, in.geomGeoJson);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return Response.status(Response.Status.CREATED).entity(Map.of("id", rs.getInt("id"))).build();
            }
        }
    }

    @PUT
    @Path("/{id}")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response editar(@PathParam("id") int id, IncidenteInput in) throws SQLException {
        // Edita los datos del incidente, NO su estado (para eso está /avanzar).
        Response invalida = validar(in);
        if (invalida != null) {
            return invalida;
        }
        String sql = "UPDATE incidente SET titulo = ?, descripcion = ?, tipo_incidente = ?, "
                   + "prioridad = ?, equipo_responsable = ?, geom = " + GEOM_IN + " WHERE id = ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, in.titulo.trim());
            ps.setString(2, in.descripcion);
            ps.setString(3, in.tipoIncidente);
            ps.setInt(4, in.prioridad);
            ps.setString(5, in.equipoResponsable);
            ps.setString(6, in.geomGeoJson);
            ps.setInt(7, id);
            return ps.executeUpdate() == 0
                    ? error(404, "El incidente no existe")
                    : Response.ok(Map.of("id", id)).build();
        }
    }

    @DELETE
    @Path("/{id}")
    public Response eliminar(@PathParam("id") int id) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM incidente WHERE id = ?")) {
            ps.setInt(1, id);
            return ps.executeUpdate() == 0
                    ? error(404, "El incidente no existe")
                    : Response.noContent().build();
        }
    }

    /** Avanza el incidente al estado indicado, si la transición es válida desde el estado actual. */
    @POST
    @Path("/{id}/avanzar")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response avanzar(@PathParam("id") int id, AvanzarInput in) throws SQLException {
        if (in == null || in.estado == null || !ESTADOS.contains(in.estado)) {
            return error(400, "Estado destino inválido. Debe ser uno de: " + String.join(", ", ESTADOS));
        }

        try (Connection conn = DataSourceProvider.get().getConnection()) {
            conn.setAutoCommit(false);

            String estadoActual;
            try (PreparedStatement sel = conn.prepareStatement(
                    "SELECT estado FROM incidente WHERE id = ? FOR UPDATE")) {
                sel.setInt(1, id);
                try (ResultSet rs = sel.executeQuery()) {
                    if (!rs.next()) {
                        conn.rollback();
                        return error(404, "El incidente no existe");
                    }
                    estadoActual = rs.getString("estado");
                }
            }

            if (!TRANSICIONES.getOrDefault(estadoActual, Collections.emptySet()).contains(in.estado)) {
                conn.rollback();
                return error(409, "No se puede pasar de \"" + estadoActual + "\" a \"" + in.estado + "\"");
            }

            try (PreparedStatement upd = conn.prepareStatement(
                    "UPDATE incidente SET estado = ? WHERE id = ?")) {
                upd.setString(1, in.estado);
                upd.setInt(2, id);
                upd.executeUpdate();
            }
            try (PreparedStatement hist = conn.prepareStatement(
                    "INSERT INTO historial_estado (incidente_id, estado, usuario) VALUES (?, ?, ?)")) {
                hist.setInt(1, id);
                hist.setString(2, in.estado);
                hist.setString(3, (in.usuario == null || in.usuario.trim().isEmpty()) ? "desconocido" : in.usuario.trim());
                hist.executeUpdate();
            }

            conn.commit();
            return Response.ok(Map.of("id", id, "estadoAnterior", estadoActual, "estado", in.estado)).build();
        }
    }

    /** Recursos asignados a un incidente (tabla incidente_recurso). */
    @GET
    @Path("/{id}/recursos")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> recursosAsignados(@PathParam("id") int id) throws SQLException {
        String sql = "SELECT r.id, r.identificacion, r.nombre, r.tipo, r.estado_operativo, ir.fecha_asignacion "
                   + "FROM incidente_recurso ir JOIN recurso r ON r.id = ir.recurso_id "
                   + "WHERE ir.incidente_id = ? ORDER BY ir.fecha_asignacion";
        List<Map<String, Object>> filas = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> r = new LinkedHashMap<>();
                    r.put("id", rs.getInt("id"));
                    r.put("identificacion", rs.getString("identificacion"));
                    r.put("nombre", rs.getString("nombre"));
                    r.put("tipo", rs.getString("tipo"));
                    r.put("estadoOperativo", rs.getString("estado_operativo"));
                    r.put("fechaAsignacion", rs.getTimestamp("fecha_asignacion").toInstant().toString());
                    filas.add(r);
                }
            }
        }
        return filas;
    }

    /** Asigna un recurso existente a un incidente. SUPUESTO: N a M, ver nota en V1__init.sql. */
    @POST
    @Path("/{id}/recursos/{recursoId}")
    public Response asignarRecurso(@PathParam("id") int id, @PathParam("recursoId") int recursoId) throws SQLException {
        String sql = "INSERT INTO incidente_recurso (incidente_id, recurso_id) VALUES (?, ?) "
                   + "ON CONFLICT DO NOTHING";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            ps.setInt(2, recursoId);
            ps.executeUpdate();
            return Response.status(Response.Status.CREATED).build();
        } catch (SQLException e) {
            return error(400, "No se pudo asignar (¿el incidente o el recurso no existen?)");
        }
    }

    @DELETE
    @Path("/{id}/recursos/{recursoId}")
    public Response desasignarRecurso(@PathParam("id") int id, @PathParam("recursoId") int recursoId) throws SQLException {
        String sql = "DELETE FROM incidente_recurso WHERE incidente_id = ? AND recurso_id = ?";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            ps.setInt(2, recursoId);
            return ps.executeUpdate() == 0 ? error(404, "No estaba asignado") : Response.noContent().build();
        }
    }

    // ------------------------------------------------------------------ utilidades

    private static Map<String, Object> filaAMapa(ResultSet rs) throws SQLException {
        Map<String, Object> i = new LinkedHashMap<>();
        i.put("id", rs.getInt("id"));
        i.put("titulo", rs.getString("titulo"));
        i.put("descripcion", rs.getString("descripcion"));
        i.put("tipoIncidente", rs.getString("tipo_incidente"));
        i.put("prioridad", rs.getInt("prioridad"));
        i.put("estado", rs.getString("estado"));
        i.put("fechaHoraRegistro", rs.getTimestamp("fecha_hora_registro").toInstant().toString());
        i.put("equipoResponsable", rs.getString("equipo_responsable"));
        i.put("geom", rs.getString("geom_json")); // texto GeoJSON: el frontend hace JSON.parse
        return i;
    }

    private static Response validar(IncidenteInput in) {
        if (in == null || in.titulo == null || in.titulo.trim().isEmpty()) {
            return error(400, "El título es obligatorio");
        }
        if (in.tipoIncidente == null || in.tipoIncidente.trim().isEmpty()) {
            return error(400, "El tipo de incidente es obligatorio");
        }
        if (in.prioridad < 1 || in.prioridad > 5) {
            return error(400, "La prioridad debe estar entre 1 y 5");
        }
        if (in.geomGeoJson == null) {
            return error(400, "Falta la ubicación del incidente");
        }
        return null;
    }

    private static Response error(int status, String mensaje) {
        return Response.status(status).type(MediaType.APPLICATION_JSON).entity(Map.of("error", mensaje)).build();
    }
}
