package uy.edu.fing.geotravel.eta;

import org.junit.Test;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

public class RutaServiceTest {

    private static final RutaService.Extremos EXTREMOS =
            new RutaService.Extremos(-57.96215, -31.39029, -57.9534, -31.38927, 830);

    @Test
    public void repiteSinVolverAConsultarElMotor() throws Exception {
        AtomicInteger llamadas = new AtomicInteger();
        OsrmClient.Ruta ruta = new OsrmClient.Ruta(1150, 180);
        RutaService servicio = new RutaService((a, b, c, d) -> {
            llamadas.incrementAndGet();
            return ruta;
        });

        assertSame(ruta, servicio.consultar(EXTREMOS));
        assertSame(ruta, servicio.consultar(EXTREMOS));

        assertEquals(1, llamadas.get());
    }

    @Test
    public void ausenciaDeRutaSeInformaComoEstado() {
        RutaService servicio = new RutaService((a, b, c, d) -> {
            throw new OsrmClient.SinRutaException("No se encontro ruta vial");
        });

        RutaService.Resultado r = servicio.intentar(EXTREMOS);

        assertEquals(RutaService.Estado.SIN_RUTA, r.estado);
        assertFalse(r.motorCaido);
        assertNull(r.ruta);
    }

    @Test
    public void errorDelMotorSeInformaSinLanzarExcepcion() {
        RutaService servicio = new RutaService((a, b, c, d) -> {
            throw new IOException("OSRM respondio HTTP 503");
        });

        RutaService.Resultado r = servicio.intentar(EXTREMOS);

        assertEquals(RutaService.Estado.ERROR, r.estado);
        assertTrue(r.motorCaido);
        assertNotNull(r.mensaje);
    }

    @Test
    public void rutaCorrectaSeInformaDisponible() {
        OsrmClient.Ruta ruta = new OsrmClient.Ruta(1150, 180);
        RutaService servicio = new RutaService((a, b, c, d) -> ruta);

        RutaService.Resultado r = servicio.intentar(EXTREMOS);

        assertEquals(RutaService.Estado.DISPONIBLE, r.estado);
        assertSame(ruta, r.ruta);
    }

    @Test
    public void advierteSoloSiElAjusteALaCalleEsGrande() {
        assertNull(RutaService.advertencia(new OsrmClient.Ruta(1, 1, null, 5.0, 99.0)));
        assertNull(RutaService.advertencia(new OsrmClient.Ruta(1, 1)));
        assertNotNull(RutaService.advertencia(new OsrmClient.Ruta(1, 1, null, 5.0, 100.0)));
    }
}
