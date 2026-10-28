
package uy.edu.fing.geotravel.eta;

import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

@Path("/eta")
@Produces(MediaType.APPLICATION_JSON)
public class EtaResource {

    private final RutaService rutas;

    public EtaResource() {
        this(RutaService.predeterminado());
    }

    EtaResource(RutaService rutas) {
        this.rutas = rutas;
    }

    /**
     * Criterios de ruta realmente disponibles: el motor debe estar configurado y responder.
     * La comprobacion se cachea 5 s (OsrmClient.SALUD_VIGENCIA_MS), asi una caida se refleja en pocos segundos.
     */
    @GET
    @Path("/criterios")
    public Response criterios() {
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        Map<String, Object> motivos = new LinkedHashMap<>();
        for (Criterio c : Criterio.values()) {
            boolean configurado = rutas.disponible(c);
            boolean ok = rutas.saludable(c);
            cuerpo.put(c.codigo, ok);
            if (!ok) {
                motivos.put(c.codigo, configurado ? "El servicio OSRM no responde" : "El servicio OSRM no esta configurado");
            }
        }
        cuerpo.put("motivos", motivos);
        return Response.ok(cuerpo).build();
    }

    @GET
    @Path("/recursos/{recursoId}/incidentes/{incidenteId}")
    public Response estimar(
            @PathParam("recursoId") int recursoId,
            @PathParam("incidenteId") int incidenteId,
            @QueryParam("criterio") String criterioParam)
            throws SQLException {

        Criterio criterio = Criterio.desde(criterioParam);
        if (criterio == null) {
            return error(400, "criterio tiene que ser mas_rapida o mas_corta");
        }
        if (!rutas.disponible(criterio)) {
            return error(503, "El criterio " + criterio.codigo
                    + " no esta disponible: falta configurar el OSRM propio (OSRM_SHORTEST_URL)");
        }

        // Validar que ambos identificadores sean positivos
        if (recursoId <= 0 || incidenteId <= 0) {
            return error(400, "Identificadores invalidos");
        }

        // 2. Obtener las coordenadas desde PostGIS
        RutaService.Extremos extremos;
        try (Connection conexion = DataSourceProvider.get().getConnection()) {
            extremos = rutas.extremos(conexion, recursoId, incidenteId);
        }

        if (extremos == null) {
            return error(404, "Recurso o incidente no encontrado");
        }

        // 3. Consultar OSRM para calcular la ruta
        try {
            OsrmClient.Ruta ruta = rutas.consultar(extremos, criterio);

            // 4. Construir la respuesta JSON
            Map<String, Object> respuesta = new LinkedHashMap<>();

            respuesta.put("recursoId", recursoId);
            respuesta.put("incidenteId", incidenteId);
            respuesta.put("distanciaMetros", Math.round(ruta.distanciaMetros));
            respuesta.put("duracionSegundos", Math.round(ruta.duracionSegundos));
            respuesta.put("tiempoEstimadoMinutos", ruta.minutosRedondeados());
            respuesta.put("geometriaRuta", ruta.geometriaRuta);
            respuesta.put("motor", criterio.motor);
            respuesta.put("aclaracion", "Estimacion sin trafico en tiempo real");
            respuesta.put("criterioRuta", criterio.codigo);
            respuesta.put("criterioRutaTexto", criterio.texto);
            respuesta.put("distanciaDirectaMetros", Math.round(extremos.distanciaDirectaM));
            respuesta.put("ajusteOrigenMetros", redondeado(ruta.ajusteOrigenMetros));
            respuesta.put("ajusteDestinoMetros", redondeado(ruta.ajusteDestinoMetros));
            respuesta.put("advertencia", RutaService.advertencia(ruta));

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

    private static Long redondeado(Double valor) {
        return valor == null ? null : Math.round(valor);
    }

    // Metodo auxiliar para construir respuestas de error
    private static Response error(int estado, String mensaje) {
        return Response.status(estado)
                .entity(Map.of("error", mensaje))
                .build();
    }
}
