package uy.edu.fing.geotravel.eta;

import org.junit.Test;

import java.io.IOException;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

public class CriterioRutaTest {

    private static final RutaService.Extremos EXTREMOS =
            new RutaService.Extremos(-57.96215, -31.39029, -57.9534, -31.38927, 830);

    @Test
    public void criterioPorDefectoEsMasRapida() {
        assertEquals(Criterio.MAS_RAPIDA, Criterio.desde(null));
        assertEquals(Criterio.MAS_RAPIDA, Criterio.desde(" "));
        assertEquals(Criterio.MAS_CORTA, Criterio.desde("MAS_CORTA"));
        assertNull(Criterio.desde("barata"));
    }

    @Test
    public void textosNoConfundenDistanciaConDuracion() {
        assertTrue(Criterio.MAS_CORTA.texto.contains("distancia"));
        assertTrue(Criterio.MAS_RAPIDA.texto.contains("duracion"));
    }

    @Test
    public void cadaCriterioUsaSuPropioMotor() throws Exception {
        OsrmClient.Ruta rapida = new OsrmClient.Ruta(900, 100);
        OsrmClient.Ruta corta = new OsrmClient.Ruta(800, 140);
        RutaService servicio = new RutaService((a, b, c, d) -> rapida, (a, b, c, d) -> corta);

        assertSame(rapida, servicio.consultar(EXTREMOS));
        assertSame(rapida, servicio.consultar(EXTREMOS, Criterio.MAS_RAPIDA));
        assertSame(corta, servicio.consultar(EXTREMOS, Criterio.MAS_CORTA));
    }

    @Test
    public void lasCachesDeCriteriosNoSeMezclan() throws Exception {
        int[] llamadas = {0, 0};
        RutaService servicio = new RutaService(
                (a, b, c, d) -> { llamadas[0]++; return new OsrmClient.Ruta(900, 100); },
                (a, b, c, d) -> { llamadas[1]++; return new OsrmClient.Ruta(800, 140); });

        servicio.consultar(EXTREMOS, Criterio.MAS_RAPIDA);
        servicio.consultar(EXTREMOS, Criterio.MAS_CORTA);
        servicio.consultar(EXTREMOS, Criterio.MAS_CORTA);

        assertEquals(1, llamadas[0]);
        assertEquals(1, llamadas[1]);
    }

    @Test
    public void sinMotorCortoNoEstaDisponible() {
        RutaService servicio = new RutaService((a, b, c, d) -> new OsrmClient.Ruta(1, 1));

        assertTrue(servicio.disponible(Criterio.MAS_RAPIDA));
        assertFalse(servicio.disponible(Criterio.MAS_CORTA));

        RutaService.Resultado r = servicio.intentar(EXTREMOS, Criterio.MAS_CORTA);
        assertEquals(RutaService.Estado.ERROR, r.estado);
    }

    @Test(expected = IOException.class)
    public void sinMotorCortoConsultarFalla() throws Exception {
        new RutaService((a, b, c, d) -> new OsrmClient.Ruta(1, 1)).consultar(EXTREMOS, Criterio.MAS_CORTA);
    }
}
