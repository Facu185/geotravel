package uy.edu.fing.geotravel.eta;

import org.junit.Test;
import java.io.IOException;
import static org.junit.Assert.assertEquals;

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
}
