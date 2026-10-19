
package uy.edu.fing.geotravel.eta;

import org.junit.Test;

import java.io.IOException;

import static org.junit.Assert.assertEquals;

public class OsrmClientTest {

    @Test
    public void interpretaUnaRutaCorrecta() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":1151,\"duration\":175}]}";

        OsrmClient.Ruta ruta = OsrmClient.parsearRuta(json);

        assertEquals(1151.0, ruta.distanciaMetros, 0.001);
        assertEquals(175.0, ruta.duracionSegundos, 0.001);
        assertEquals(3L, ruta.minutosRedondeados());
    }

    @Test
    public void noRedondeaUnMinutoExacto() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":500,\"duration\":60}]}";

        OsrmClient.Ruta ruta = OsrmClient.parsearRuta(json);

        assertEquals(1L, ruta.minutosRedondeados());
    }

    @Test
    public void redondeaHaciaArriba() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":500,\"duration\":61}]}";

        OsrmClient.Ruta ruta = OsrmClient.parsearRuta(json);

        assertEquals(2L, ruta.minutosRedondeados());
    }

    @Test(expected = OsrmClient.SinRutaException.class)
    public void detectaCuandoNoHayRuta() throws Exception {
        String json = "{\"code\":\"NoRoute\",\"routes\":[]}";

        OsrmClient.parsearRuta(json);
    }

    @Test(expected = IOException.class)
    public void detectaDuracionFaltante() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":1151}]}";

        OsrmClient.parsearRuta(json);
    }

    @Test(expected = IOException.class)
    public void rechazaDistanciaNegativa() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":-100,\"duration\":175}]}";

        OsrmClient.parsearRuta(json);
    }

    @Test(expected = IOException.class)
    public void rechazaCodigoInesperado() throws Exception {
        String json = "{\"code\":\"Error\",\"routes\":[]}";

        OsrmClient.parsearRuta(json);
    }
}
