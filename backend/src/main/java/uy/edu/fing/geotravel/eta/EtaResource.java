
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

@Path("/eta")
@Produces(MediaType.APPLICATION_JSON)
public class EtaResource {

    private static final String SQL =
            "SELECT " +
            "ST_X(ST_Transform(r.geom, 4326)) AS origen_lon, " +
            "ST_Y(ST_Transform(r.geom, 4326)) AS origen_lat, " +
            "ST_X(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lon, " +
            "ST_Y(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lat " +
            "FROM recurso r CROSS JOIN incidente i " +
            "WHERE r.id = ? AND i.id = ?";

    @GET
    @Path("/recursos/{recursoId}/incidentes/{incidenteId}")
    public Response estimar(
            @PathParam("recursoId") int recursoId,
            @PathParam("incidenteId") int incidenteId)
            throws SQLException {

        // Validar que ambos identificadores sean positivos
        if (recursoId <= 0 || incidenteId <= 0) {
            return error(400, "Identificadores invalidos");
        }

        double origenLon;
        double origenLat;
        double destinoLon;
        double destinoLat;

        // 2. Obtener las coordenadas desde PostGIS
        try (Connection conexion = DataSourceProvider.get().getConnection();
             PreparedStatement consulta = conexion.prepareStatement(SQL)) {

            consulta.setInt(1, recursoId);
            consulta.setInt(2, incidenteId);

            try (ResultSet resultado = consulta.executeQuery()) {

                if (!resultado.next()) {
                    return error(404, "Recurso o incidente no encontrado");
                }

                origenLon = resultado.getDouble("origen_lon");
                origenLat = resultado.getDouble("origen_lat");
                destinoLon = resultado.getDouble("destino_lon");
                destinoLat = resultado.getDouble("destino_lat");
            }
        }

        // 3. Consultar OSRM para calcular la ruta
        try {
            OsrmClient.Ruta ruta = OsrmClient.consultar(
                    origenLon,
                    origenLat,
                    destinoLon,
                    destinoLat
            );

            // 4. Construir la respuesta JSON
            Map<String, Object> respuesta = new LinkedHashMap<>();

            respuesta.put("recursoId", recursoId);
            respuesta.put("incidenteId", incidenteId);
            respuesta.put("distanciaMetros", Math.round(ruta.distanciaMetros));
            respuesta.put("duracionSegundos", Math.round(ruta.duracionSegundos));
            respuesta.put("tiempoEstimadoMinutos", ruta.minutosRedondeados());
            respuesta.put("motor", "OSRM driving");
            respuesta.put("aclaracion", "Estimacion sin trafico en tiempo real");

            return Response.ok(respuesta).build();

        } catch (OsrmClient.SinRutaException e) {
            return error(422, e.getMessage());

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return error(503, "Consulta OSRM interrumpida");

        } catch (IOException e) {
            return error(503, "No se pudo consultar OSRM");
        }
    }

    // Metodo auxiliar para construir respuestas de error
    private static Response error(int estado, String mensaje) {
        return Response.status(estado)
                .entity(Map.of("error", mensaje))
                .build();
    }
}
