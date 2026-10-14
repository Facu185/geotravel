package uy.edu.fing.geotravel.eta;

import org.junit.Test;
import java.io.IOException;
import static org.junit.Assert.assertEquals;

public class OsrmClientTest {

    @Test
    public void rutaValidaDevuelveDistanciaYMinutos() throws IOException {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":2388.4,\"duration\":462.6}]}";
        OsrmClient.Ruta ruta = OsrmClient.parsearRuta(json);
        assertEquals(2388.4, ruta.distanciaMetros, 0.001);
        assertEquals(462.6, ruta.duracionSegundos, 0.001);
        assertEquals(8, ruta.minutosRedondeados());
    }

    @Test(expected = OsrmClient.SinRutaException.class)
    public void sinRutaDevuelveErrorEspecifico() throws IOException {
        OsrmClient.parsearRuta("{\"code\":\"NoRoute\",\"routes\":[]}");
    }

    @Test(expected = IOException.class)
    public void rutaSinDuracionSeRechaza() throws IOException {
        OsrmClient.parsearRuta("{\"code\":\"Ok\",\"routes\":[{\"distance\":10.0}]}");
    }
}
