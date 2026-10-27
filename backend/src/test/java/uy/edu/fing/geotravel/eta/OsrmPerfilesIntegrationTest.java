package uy.edu.fing.geotravel.eta;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.Assume;
import org.junit.Before;
import org.junit.Test;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/**
 * Pruebas contra los dos OSRM propios ya levantados. Se activan con URBANSAFE_OSRM_TESTS=true y las
 * variables OSRM_FAST_URL y OSRM_SHORTEST_URL (p. ej. http://localhost:15001 y http://localhost:15002).
 */
public class OsrmPerfilesIntegrationTest {

    // Salto: la ruta rapida (408 s) es mas larga que la corta (593 s) en el extracto de Geofabrik probado
    private static final double[] SALTO = {-57.98, -31.40, -57.9534, -31.3893};
    private static final double[] MONTEVIDEO = {-56.19, -34.90, -56.1685, -34.9158};

    @Before
    public void preparar() {
        Assume.assumeTrue("Definir URBANSAFE_OSRM_TESTS=true con los dos OSRM levantados",
                "true".equalsIgnoreCase(System.getenv("URBANSAFE_OSRM_TESTS")));
        Assume.assumeTrue(OsrmClient.cortaConfigurada());
    }

    private static OsrmClient.Ruta ruta(double[] p, Criterio c) throws Exception {
        return OsrmClient.consultar(p[0], p[1], p[2], p[3], c);
    }

    @Test
    public void laCortaNuncaEsMasLargaQueLaRapida() throws Exception {
        for (double[] par : new double[][] {SALTO, MONTEVIDEO}) {
            OsrmClient.Ruta rapida = ruta(par, Criterio.MAS_RAPIDA);
            OsrmClient.Ruta corta = ruta(par, Criterio.MAS_CORTA);
            assertTrue(corta.distanciaMetros <= rapida.distanciaMetros + 0.5);
        }
    }

    @Test
    public void escenarioControladoMasCortaPeroMasLenta() throws Exception {
        OsrmClient.Ruta rapida = ruta(SALTO, Criterio.MAS_RAPIDA);
        OsrmClient.Ruta corta = ruta(SALTO, Criterio.MAS_CORTA);
        assertTrue("la corta debe ser mas corta", corta.distanciaMetros < rapida.distanciaMetros);
        assertTrue("la rapida debe ser mas rapida", rapida.duracionSegundos < corta.duracionSegundos);
    }

    @Test
    public void elPesoDelPerfilCortoEsLaDistancia() throws Exception {
        JsonNode r = anotada(System.getenv("OSRM_SHORTEST_URL"), SALTO);
        assertEquals("distance", r.path("weight_name").asText());
        assertEquals(r.path("distance").asDouble(), r.path("weight").asDouble(), 1.0);
    }

    @Test
    public void elPerfilRapidoNoOptimizaDistancia() throws Exception {
        JsonNode r = anotada(OsrmClient.servidorDe(Criterio.MAS_RAPIDA), SALTO);
        assertEquals("routability", r.path("weight_name").asText());
        assertEquals(r.path("duration").asDouble(), r.path("weight").asDouble(), 2.0);
    }

    @Test
    public void laGeometriaEsGeoJsonLineStringEnOrdenLonLat() throws Exception {
        OsrmClient.Ruta corta = ruta(SALTO, Criterio.MAS_CORTA);
        assertEquals("LineString", corta.geometriaRuta.path("type").asText());
        JsonNode primera = corta.geometriaRuta.path("coordinates").path(0);
        assertTrue("longitud de Uruguay", primera.path(0).asDouble() < -53 && primera.path(0).asDouble() > -59);
        assertTrue("latitud de Uruguay", primera.path(1).asDouble() < -30 && primera.path(1).asDouble() > -35);
    }

    private static JsonNode anotada(String servidor, double[] p) throws Exception {
        String url = String.format(java.util.Locale.ROOT,
                "%s/route/v1/driving/%f,%f;%f,%f?overview=false&annotations=distance,duration,weight",
                servidor.replaceAll("/+$", ""), p[0], p[1], p[2], p[3]);
        HttpResponse<String> r = HttpClient.newHttpClient().send(
                HttpRequest.newBuilder(URI.create(url)).GET().build(), HttpResponse.BodyHandlers.ofString());
        return new ObjectMapper().readTree(r.body()).path("routes").path(0);
    }
}
