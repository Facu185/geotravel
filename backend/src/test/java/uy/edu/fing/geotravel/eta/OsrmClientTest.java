package uy.edu.fing.geotravel.eta;

import com.sun.net.httpserver.HttpServer;
import org.junit.Test;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;
import static org.junit.Assert.assertTrue;

public class OsrmClientTest {

    @Test
    public void rutaValidaDevuelveDistanciaYMinutos() throws IOException {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":2388.4,\"duration\":462.6,"
            + "\"geometry\":{\"type\":\"LineString\",\"coordinates\":[[-56.18,-34.90],[-56.17,-34.89]]}}]}";
        OsrmClient.Ruta ruta = OsrmClient.parsearRuta(json);
        assertEquals(2388.4, ruta.distanciaMetros, 0.001);
        assertEquals(462.6, ruta.duracionSegundos, 0.001);
        assertEquals(8, ruta.minutosRedondeados());
        assertEquals(-56.18, ruta.coordenadas.get(0).get(0), 0.001);
        assertEquals(-34.89, ruta.coordenadas.get(1).get(1), 0.001);
    }

    @Test(expected = OsrmClient.SinRutaException.class)
    public void sinRutaDevuelveErrorEspecifico() throws IOException {
        OsrmClient.parsearRuta("{\"code\":\"NoRoute\",\"routes\":[]}");
    }

    @Test(expected = IOException.class)
    public void rutaSinDuracionSeRechaza() throws IOException {
        OsrmClient.parsearRuta("{\"code\":\"Ok\",\"routes\":[{\"distance\":10.0}]}");
    }

    @Test(expected = IOException.class)
    public void rutaSinGeometriaSeRechaza() throws IOException {
        OsrmClient.parsearRuta("{\"code\":\"Ok\",\"routes\":[{\"distance\":10.0,\"duration\":5.0}]}");
    }

    @Test
    public void consultaHttpDevuelveRutaYUsaFormatoGeoJson() throws Exception {
        AtomicReference<String> rutaSolicitada = new AtomicReference<>();
        HttpServer server = iniciarServidor(200, "application/json",
                "{\"code\":\"Ok\",\"routes\":[{\"distance\":1200,\"duration\":80,"
                        + "\"geometry\":{\"type\":\"LineString\",\"coordinates\":[[-56.18,-34.90],[-56.17,-34.89]]}}]}",
                rutaSolicitada, 0);
        try {
            OsrmClient.Ruta ruta = OsrmClient.consultar(-56.18, -34.90, -56.17, -34.89,
                    baseUrl(server), Duration.ofSeconds(2));
            assertEquals(1200, ruta.distanciaMetros, 0.001);
            assertEquals(80, ruta.duracionSegundos, 0.001);
            assertTrue(rutaSolicitada.get().contains("overview=full&geometries=geojson"));
            assertTrue(rutaSolicitada.get().contains("-56.1800000,-34.9000000;-56.1700000,-34.8900000"));
        } finally {
            server.stop(0);
        }
    }

    @Test
    public void respuestaHttpDeErrorSeRechaza() throws Exception {
        HttpServer server = iniciarServidor(503, "application/json", "{}", new AtomicReference<>(), 0);
        try {
            OsrmClient.consultar(-56.18, -34.90, -56.17, -34.89, baseUrl(server), Duration.ofSeconds(2));
            fail("Se esperaba un error HTTP de OSRM");
        } catch (IOException e) {
            assertTrue(e.getMessage().contains("HTTP 503"));
        } finally {
            server.stop(0);
        }
    }

    @Test(expected = IOException.class)
    public void respuestaNoJsonSeRechaza() throws Exception {
        HttpServer server = iniciarServidor(200, "text/html", "not json", new AtomicReference<>(), 0);
        try {
            OsrmClient.consultar(-56.18, -34.90, -56.17, -34.89, baseUrl(server), Duration.ofSeconds(2));
        } finally {
            server.stop(0);
        }
    }

    @Test(expected = IOException.class)
    public void urlOsrmConEsquemaInseguroSeRechaza() throws Exception {
        OsrmClient.consultar(-56.18, -34.90, -56.17, -34.89, "file:///tmp/osrm", Duration.ofSeconds(1));
    }

    @Test(expected = IOException.class)
    public void coordenadasFueraDeRangoSeRechazan() throws Exception {
        OsrmClient.consultar(200, -34.90, -56.17, -34.89, "http://localhost", Duration.ofSeconds(1));
    }

    @Test
    public void solicitudQueExcedeElTimeoutSeRechaza() throws Exception {
        HttpServer server = iniciarServidor(200, "application/json", "{}", new AtomicReference<>(), 250);
        try {
            OsrmClient.consultar(-56.18, -34.90, -56.17, -34.89,
                    baseUrl(server), Duration.ofMillis(50));
            fail("Se esperaba un timeout de OSRM");
        } catch (IOException e) {
            assertTrue(e.getMessage() != null);
        } finally {
            server.stop(0);
        }
    }

    private static HttpServer iniciarServidor(int status, String contentType, String body,
                                              AtomicReference<String> rutaSolicitada, long demoraMs)
            throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            rutaSolicitada.set(exchange.getRequestURI().toString());
            if (demoraMs > 0) {
                try {
                    Thread.sleep(demoraMs);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    exchange.close();
                    return;
                }
            }
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", contentType);
            try {
                exchange.sendResponseHeaders(status, bytes.length);
                exchange.getResponseBody().write(bytes);
            } catch (IOException ignored) {
                // El cliente puede cancelar la solicitud al vencer su timeout.
            } finally {
                exchange.close();
            }
        });
        server.start();
        return server;
    }

    private static String baseUrl(HttpServer server) {
        return "http://127.0.0.1:" + server.getAddress().getPort();
    }
}
