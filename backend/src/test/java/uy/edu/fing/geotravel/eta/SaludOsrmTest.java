package uy.edu.fing.geotravel.eta;

import com.sun.net.httpserver.HttpServer;
import org.junit.After;
import org.junit.Test;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class SaludOsrmTest {

    private HttpServer servidor;
    private final CountDownLatch liberar = new CountDownLatch(1);

    @After
    public void cerrar() {
        liberar.countDown();
        if (servidor != null) servidor.stop(0);
    }

    private String levantar(int estado, String cuerpo, boolean colgar) throws Exception {
        servidor = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        servidor.createContext("/", ex -> {
            if (colgar) {
                try { liberar.await(10, TimeUnit.SECONDS); } catch (InterruptedException ignorado) { }
            }
            byte[] b = cuerpo.getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(estado, b.length);
            ex.getResponseBody().write(b);
            ex.close();
        });
        servidor.start();
        return "http://127.0.0.1:" + servidor.getAddress().getPort();
    }

    @Test
    public void motorQueResponderOkEsSaludable() throws Exception {
        assertTrue(OsrmClient.comprobar(levantar(200, "{\"code\":\"Ok\",\"routes\":[]}", false), 2000));
    }

    @Test
    public void respuestaDeErrorOCodigoDistintoNoEsSaludable() throws Exception {
        assertFalse(OsrmClient.comprobar(levantar(500, "{}", false), 2000));
        cerrar();
        assertFalse(OsrmClient.comprobar(levantar(200, "{\"code\":\"InvalidQuery\"}", false), 2000));
    }

    @Test
    public void motorDetenidoNoEsSaludable() throws Exception {
        String url = levantar(200, "{\"code\":\"Ok\"}", false);
        servidor.stop(0);
        assertFalse(OsrmClient.comprobar(url, 2000));
    }

    @Test(timeout = 5000)
    public void motorColgadoVenceElTimeoutAcotado() throws Exception {
        long t = System.nanoTime();
        assertFalse(OsrmClient.comprobar(levantar(200, "{\"code\":\"Ok\"}", true), 500));
        assertTrue((System.nanoTime() - t) / 1_000_000 < 3000);
    }

    @Test
    public void sinConfigurarNoEsSaludableYLosMotoresSimuladosSi() {
        RutaService sinCorta = new RutaService((a, b, c, d) -> new OsrmClient.Ruta(1, 1));
        assertFalse(sinCorta.saludable(Criterio.MAS_CORTA));
        assertTrue(sinCorta.saludable(Criterio.MAS_RAPIDA));
    }
}
