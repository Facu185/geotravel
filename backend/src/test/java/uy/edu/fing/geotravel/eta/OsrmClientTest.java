
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
    public void interpretaElAjusteALaCalle() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":1151,\"duration\":175}],"
                + "\"waypoints\":[{\"distance\":4.2},{\"distance\":130.5}]}";

        OsrmClient.Ruta ruta = OsrmClient.parsearRuta(json);

        assertEquals(4.2, ruta.ajusteOrigenMetros, 0.001);
        assertEquals(130.5, ruta.ajusteDestinoMetros, 0.001);
    }

    @Test
    public void sinWaypointsNoHayAjuste() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{\"distance\":1151,\"duration\":175}]}";

        OsrmClient.Ruta ruta = OsrmClient.parsearRuta(json);

        org.junit.Assert.assertNull(ruta.ajusteOrigenMetros);
        org.junit.Assert.assertNull(ruta.ajusteDestinoMetros);
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

    @Test(expected = OsrmClient.SinRutaException.class)
    public void sinCalleCercanaEsSinRutaYNoCaidaDelMotor() throws Exception {
        OsrmClient.parsearRuta("{\"code\":\"NoSegment\",\"message\":\"Could not find a matching segment\"}");
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

    @Test
    public void interpretaGeometriaGeoJson() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{"
                + "\"distance\":1051,"
                + "\"duration\":170,"
                + "\"geometry\":{"
                + "\"type\":\"LineString\","
                + "\"coordinates\":["
                + "[-57.96215,-31.39029],"
                + "[-57.95340,-31.38927]"
                + "]}}]}";

        OsrmClient.Ruta ruta = OsrmClient.parsearRuta(json);

        assertEquals(1051.0, ruta.distanciaMetros, 0.001);
        assertEquals(170.0, ruta.duracionSegundos, 0.001);
        assertEquals(3L, ruta.minutosRedondeados());
        assertEquals("LineString", ruta.geometriaRuta.path("type").asText());
        assertEquals(2, ruta.geometriaRuta.path("coordinates").size());
    }

    @Test(expected = IOException.class)
    public void rechazaGeometriaSinPuntosSuficientes() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{"
                + "\"distance\":1051,"
                + "\"duration\":170,"
                + "\"geometry\":{"
                + "\"type\":\"LineString\","
                + "\"coordinates\":[[-57.96215,-31.39029]]"
                + "}}]}";

        OsrmClient.parsearRuta(json);
    }

    @Test(expected = IOException.class)
    public void rechazaCoordenadasFueraDeRango() throws Exception {
        String json = "{\"code\":\"Ok\",\"routes\":[{"
                + "\"distance\":1051,"
                + "\"duration\":170,"
                + "\"geometry\":{"
                + "\"type\":\"LineString\","
                + "\"coordinates\":["
                + "[-200,-31.39029],"
                + "[-57.95340,-31.38927]"
                + "]}}]}";

        OsrmClient.parsearRuta(json);
    }
}
