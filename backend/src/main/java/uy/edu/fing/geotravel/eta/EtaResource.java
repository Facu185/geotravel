package uy.edu.fing.geotravel.eta;

import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Extra P2: tiempo estimado de viaje de un recurso hasta un incidente.
 * PostGIS convierte EPSG:32721 a lon/lat; OSRM calcula la ruta por calles.
 * Para incidentes LineString/Polygon se usa el punto mas cercano al recurso.
 */
@Path("/eta")
@Produces(MediaType.APPLICATION_JSON)
public class EtaResource {

    private static final String COORDENADAS =
            "SELECT ST_X(ST_Transform(r.geom, 4326)) AS origen_lon, " +
            "       ST_Y(ST_Transform(r.geom, 4326)) AS origen_lat, " +
            "       ST_X(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lon, " +
            "       ST_Y(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lat " +
            "FROM recurso r CROSS JOIN incidente i " +
            "WHERE r.id = ? AND i.id = ?";

    @GET
    @Path("/recursos/{recursoId}/incidentes/{incidenteId}")
    public Response estimar(@PathParam("recursoId") int recursoId,
                            @PathParam("incidenteId") int incidenteId) throws SQLException {
        if (recursoId <= 0 || incidenteId <= 0) {
            return error(400, "Los identificadores deben ser mayores que cero");
        }

        double origenLon, origenLat, destinoLon, destinoLat;
        try (Connection c = DataSourceProvider.get().getConnection();
             PreparedStatement ps = c.prepareStatement(COORDENADAS)) {
            ps.setInt(1, recursoId);
            ps.setInt(2, incidenteId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return error(404, "Recurso o incidente inexistente");
                }
                origenLon = rs.getDouble("origen_lon");
                origenLat = rs.getDouble("origen_lat");
                destinoLon = rs.getDouble("destino_lon");
                destinoLat = rs.getDouble("destino_lat");
            }
        }

        try {
            OsrmClient.Ruta ruta = OsrmClient.consultar(
                    origenLon, origenLat, destinoLon, destinoLat);
            Map<String, Object> respuesta = new LinkedHashMap<>();
            respuesta.put("recursoId", recursoId);
            respuesta.put("incidenteId", incidenteId);
            respuesta.put("distanciaMetros", Math.round(ruta.distanciaMetros));
            respuesta.put("duracionSegundos", Math.round(ruta.duracionSegundos));
            respuesta.put("tiempoEstimadoMinutos", ruta.minutosRedondeados());
            respuesta.put("motor", "OSRM driving");
            respuesta.put("aclaracion", "Estimacion de recorrido vial sin trafico en tiempo real");
            return Response.ok(respuesta).build();
        } catch (OsrmClient.SinRutaException e) {
            return error(422, e.getMessage());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return error(503, "Consulta de ruta interrumpida");
        } catch (IOException e) {
            return error(503, "No se pudo consultar OSRM: " + e.getMessage());
        }
    }

    private static Response error(int estado, String mensaje) {
        return Response.status(estado).entity(Map.of("error", mensaje)).build();
    }
}
