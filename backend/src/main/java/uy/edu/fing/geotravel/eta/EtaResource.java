
package uy.edu.fing.geotravel.eta;

import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.DefaultValue;
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
     * Si se pueden calcular rutas: la base debe tener pgRouting, la red vial y la funcion de rutas.
     * La comprobacion se cachea 5 s, asi un cambio se refleja en pocos segundos.
     */
    @GET
    @Path("/disponible")
    public Response disponible() {
        boolean ok = rutas.disponible();
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("disponible", ok);
        cuerpo.put("motivo", ok ? null : "Falta pgRouting, la red vial o la funcion de rutas en la base (ver docs/RED_VIAL.md)");
        return Response.ok(cuerpo).build();
    }

    @GET
    @Path("/recursos/{recursoId}/incidentes/{incidenteId}")
    public Response estimar(
            @PathParam("recursoId") int recursoId,
            @PathParam("incidenteId") int incidenteId)
            throws SQLException {

        if (!rutas.disponible()) {
            return error(503, "El calculo de rutas no esta disponible: falta pgRouting, la red vial o la funcion de rutas");
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

        // 3. Calcular la ruta por calles (pgRouting)
        try {
            Ruta ruta = rutas.consultar(extremos);

            // 4. Construir la respuesta JSON
            Map<String, Object> respuesta = new LinkedHashMap<>();

            respuesta.put("recursoId", recursoId);
            respuesta.put("incidenteId", incidenteId);
            respuesta.put("distanciaMetros", Math.round(ruta.distanciaMetros));
            respuesta.put("duracionSegundos", Math.round(ruta.duracionSegundos));
            respuesta.put("tiempoEstimadoMinutos", ruta.minutosRedondeados());
            respuesta.put("geometriaRuta", ruta.geometriaRuta);
            respuesta.put("calles", ruta.calles);
            respuesta.put("motor", rutas.nombreMotor());
            respuesta.put("aclaracion", "Estimacion sin trafico en tiempo real");
            respuesta.put("distanciaDirectaMetros", Math.round(extremos.distanciaDirectaM));
            respuesta.put("ajusteOrigenMetros", redondeado(ruta.ajusteOrigenMetros));
            respuesta.put("ajusteDestinoMetros", redondeado(ruta.ajusteDestinoMetros));
            respuesta.put("advertencia", RutaService.advertencia(ruta));

            return Response.ok(respuesta).build();

        } catch (SinRutaException e) {
            return error(422, e.getMessage());

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return error(503, "Calculo de ruta interrumpido");

        } catch (IOException e) {
            return error(503, "No se pudo consultar el motor de rutas");
        }
    }

    /**
     * El recurso mas cercano al incidente POR LAS CALLES, con su ruta: de los N recursos mas cercanos en linea recta
     * (por defecto 5, solo los disponibles) gana el de menor tiempo por calles. Ver RecursoMasCercano.
     */
    @GET
    @Path("/incidentes/{incidenteId}/recurso-mas-cercano")
    public Response recursoMasCercano(
            @PathParam("incidenteId") int incidenteId,
            @QueryParam("soloDisponibles") @DefaultValue("true") boolean soloDisponibles,
            @QueryParam("candidatos") String candidatos)
            throws SQLException {

        if (incidenteId <= 0) {
            return error(400, "Identificador invalido");
        }
        int cantidad;
        try {
            cantidad = RecursoMasCercano.candidatos(candidatos);
        } catch (IllegalArgumentException e) {
            return error(400, e.getMessage());
        }
        if (!rutas.disponible()) {
            return error(503, "El calculo de rutas no esta disponible: falta pgRouting, la red vial o la funcion de rutas");
        }
        try (Connection conexion = DataSourceProvider.get().getConnection()) {
            RecursoMasCercano.Respuesta r = new RecursoMasCercano(rutas).buscar(conexion, incidenteId, soloDisponibles, cantidad);
            return Response.status(r.estado).entity(r.cuerpo).build();
        } catch (IOException e) {
            return error(503, "No se pudo consultar el motor de rutas");
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
