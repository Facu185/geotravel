package uy.edu.fing.geotravel.recorridos;

import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.sql.*;
import java.util.*;

/**
 * Módulo Recorridos (dueño: P4).
 *
 * GET  /api/recorridos            -> lista, con el estado "efectivo" ya resuelto
 *                                     (si mes_inicio/mes_fin no cubre el mes actual,
 *                                     se reporta "Fuera de estacion" aunque el campo
 *                                     'estado' en la tabla diga otra cosa).
 * POST /api/recorridos/{id}/avanzar -> aplica la transición de estado válida
 *                                       siguiente y la registra en historial_estado.
 *
 * La secuencia manual es Pendiente -> Disponible -> Cancelado. "Fuera de estación"
 * NO se setea manualmente: es siempre calculado a partir de mes_inicio/mes_fin
 * (ver estadoEfectivo() abajo) -- ajusten la regla si el criterio real es otro.
 */
@Path("/recorridos")
public class RecorridoResource {

    private static final Map<String, String> SIGUIENTE_ESTADO = new LinkedHashMap<>();
    static {
        SIGUIENTE_ESTADO.put("Pendiente", "Disponible");
        SIGUIENTE_ESTADO.put("Disponible", "Cancelado");
    }

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> listar() throws SQLException {
        String sql = "SELECT id, nombre, descripcion, duracion_min, guia_responsable, "
                   + "       tipo_experiencia, mes_inicio, mes_fin, estado "
                   + "FROM recorrido ORDER BY id";

        List<Map<String, Object>> recorridos = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {

            while (rs.next()) {
                int mesInicio = rs.getInt("mes_inicio");
                int mesFin = rs.getInt("mes_fin");
                String estado = rs.getString("estado");

                Map<String, Object> r = new LinkedHashMap<>();
                r.put("id", rs.getInt("id"));
                r.put("nombre", rs.getString("nombre"));
                r.put("descripcion", rs.getString("descripcion"));
                r.put("duracionMin", rs.getInt("duracion_min"));
                r.put("guiaResponsable", rs.getString("guia_responsable"));
                r.put("tipoExperiencia", rs.getString("tipo_experiencia"));
                r.put("mesInicio", mesInicio);
                r.put("mesFin", mesFin);
                r.put("estado", estado);
                r.put("estadoEfectivo", estadoEfectivo(estado, mesInicio, mesFin));
                recorridos.add(r);
            }
        }
        return recorridos;
    }

    @POST
    @Path("/{id}/avanzar")
    @Produces(MediaType.APPLICATION_JSON)
    public Response avanzar(@PathParam("id") int id) throws SQLException {
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            conn.setAutoCommit(false);

            String estadoActual;
            try (PreparedStatement sel = conn.prepareStatement(
                    "SELECT estado FROM recorrido WHERE id = ? FOR UPDATE")) {
                sel.setInt(1, id);
                try (ResultSet rs = sel.executeQuery()) {
                    if (!rs.next()) {
                        conn.rollback();
                        return Response.status(Response.Status.NOT_FOUND)
                                .entity(Map.of("error", "Recorrido no encontrado")).build();
                    }
                    estadoActual = rs.getString("estado");
                }
            }

            String siguiente = SIGUIENTE_ESTADO.get(estadoActual);
            if (siguiente == null) {
                conn.rollback();
                return Response.status(Response.Status.CONFLICT)
                        .entity(Map.of("error", "No hay transición válida desde " + estadoActual))
                        .build();
            }

            try (PreparedStatement upd = conn.prepareStatement(
                    "UPDATE recorrido SET estado = ? WHERE id = ?")) {
                upd.setString(1, siguiente);
                upd.setInt(2, id);
                upd.executeUpdate();
            }
            try (PreparedStatement hist = conn.prepareStatement(
                    "INSERT INTO historial_estado (recorrido_id, estado) VALUES (?, ?)")) {
                hist.setInt(1, id);
                hist.setString(2, siguiente);
                hist.executeUpdate();
            }

            conn.commit();
            return Response.ok(Map.of("id", id, "estadoAnterior", estadoActual, "estado", siguiente)).build();
        }
    }

    /** Fuera de estación si el mes actual no cae en [mesInicio, mesFin] (maneja rangos que cruzan el año). */
    private static String estadoEfectivo(String estadoGuardado, int mesInicio, int mesFin) {
        if (!"Disponible".equals(estadoGuardado)) {
            return estadoGuardado;
        }
        int mesActual = java.time.LocalDate.now().getMonthValue();
        boolean enEstacion = (mesInicio <= mesFin)
                ? (mesActual >= mesInicio && mesActual <= mesFin)
                : (mesActual >= mesInicio || mesActual <= mesFin);
        return enEstacion ? "Disponible" : "Fuera de estacion";
    }
}
