package uy.edu.fing.geotravel.incidentes;

import org.junit.Test;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

/** La ubicación de un incidente puede ser un punto, una línea o un polígono; lo demás se rechaza antes de llegar a la base. */
public class FormaIncidenteTest {

    @Test
    public void aceptaPuntoLineaYPoligono() {
        assertNull(IncidenteResource.errorDeForma("{\"type\":\"Point\",\"coordinates\":[-57.96,-31.38]}"));
        assertNull(IncidenteResource.errorDeForma("{\"type\":\"LineString\",\"coordinates\":[[-57.96,-31.38],[-57.95,-31.38]]}"));
        assertNull(IncidenteResource.errorDeForma(
                "{\"type\":\"Polygon\",\"coordinates\":[[[-57.96,-31.38],[-57.95,-31.38],[-57.95,-31.37],[-57.96,-31.38]]]}"));
    }

    @Test
    public void rechazaLoQueNoEsUnaGeometria() {
        assertNotNull(IncidenteResource.errorDeForma("no es json"));
        assertNotNull(IncidenteResource.errorDeForma("{\"type\":\"Feature\",\"geometry\":null}"));
        assertNotNull(IncidenteResource.errorDeForma("{\"type\":\"GeometryCollection\",\"geometries\":[]}"));
        assertNotNull(IncidenteResource.errorDeForma("{\"coordinates\":[1,2]}"));
    }

    @Test
    public void rechazaUnaUbicacionVacia() {
        assertNotNull(IncidenteResource.errorDeForma("{\"type\":\"Point\"}"));
        assertNotNull(IncidenteResource.errorDeForma("{\"type\":\"LineString\",\"coordinates\":[]}"));
    }
}
