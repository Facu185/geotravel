package uy.edu.fing.geotravel.mapa;

import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.Map;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/** Validación del parámetro bbox de los listados a demanda (no necesita base de datos). */
public class BboxTest {

    @Test
    public void aceptaElFormatoDeLeaflet() {
        assertFalse(Bbox.parse("-57.995,-31.405,-57.925,-31.365").vacio());
        assertFalse(Bbox.parse(" -57.995 , -31.405 , -57.925 , -31.365 ").vacio());
    }

    @Test
    public void elMundoEnteroSeRecortaAUruguay() {
        assertFalse(Bbox.parse("-180,-85,180,85").vacio());
    }

    @Test
    public void fueraDeUruguayQuedaVacio() {
        assertTrue(Bbox.parse("10,40,11,41").vacio());
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaMenosDeCuatroValores() {
        Bbox.parse("1,2,3");
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaValoresNoNumericos() {
        Bbox.parse("a,b,c,d");
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaInfinito() {
        Bbox.parse("-Infinity,-31,-57,-30");
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaRectanguloInvertido() {
        Bbox.parse("-57.9,-31.4,-58.0,-31.3");
    }

    @Test
    public void limitePorDefectoYTope() {
        assertEquals(Bbox.LIMITE_POR_DEFECTO, Bbox.limite(null));
        assertEquals(10, Bbox.limite(10));
        assertEquals(Bbox.LIMITE_MAXIMO, Bbox.limite(1_000_000));
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaLimiteCero() {
        Bbox.limite(0);
    }

    @Test
    public void limiteDesdeTextoUsaDefaultYAplicaMaximo() {
        assertEquals(500, Bbox.limiteDesdeTexto(null));
        assertEquals(2000, Bbox.limiteDesdeTexto("5000"));
    }

    @Test(expected = IllegalArgumentException.class)
    public void limiteDesdeTextoRechazaNoEnteros() {
        Bbox.limiteDesdeTexto("1.5");
    }

    @Test(expected = IllegalArgumentException.class)
    public void limiteDesdeTextoRechazaVacio() {
        Bbox.limiteDesdeTexto("  ");
    }

    @Test
    public void resultadoMarcaTruncado() {
        Map<String, Object> parcial = Bbox.resultado(Arrays.asList("a", "b"), 5);
        assertEquals(5, parcial.get("total"));
        assertEquals(true, parcial.get("truncado"));

        Map<String, Object> completo = Bbox.resultado(Collections.singletonList("a"), 1);
        assertEquals(false, completo.get("truncado"));
    }
}
