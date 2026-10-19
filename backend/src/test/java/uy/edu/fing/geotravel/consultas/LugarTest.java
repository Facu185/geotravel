package uy.edu.fing.geotravel.consultas;

import org.junit.Test;

import javax.ws.rs.WebApplicationException;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;

/** Validación del departamento y la localidad que se mandan al servicio de direcciones. */
public class LugarTest {

    @Test
    public void sinValorUsaElPorDefecto() {
        assertEquals("montevideo", ConsultaResource.lugar(null, "montevideo"));
        assertEquals("salto", ConsultaResource.lugar("  ", "salto"));
    }

    @Test
    public void normalizaAMinusculas() {
        assertEquals("salto", ConsultaResource.lugar(" Salto ", "montevideo"));
        assertEquals("san josé", ConsultaResource.lugar("San José", "x"));
        assertEquals("paso de los toros", ConsultaResource.lugar("Paso de los Toros", "x"));
    }

    @Test
    public void rechazaLoQueNoEsUnNombre() {
        for (String malo : new String[] {"salto&x=1", "a", "salto;drop", "../etc", "x".repeat(41), "sal<to>"}) {
            try {
                ConsultaResource.lugar(malo, "montevideo");
                fail("debería rechazar: " + malo);
            } catch (WebApplicationException esperado) {
                assertEquals(400, esperado.getResponse().getStatus());
            }
        }
    }
}
