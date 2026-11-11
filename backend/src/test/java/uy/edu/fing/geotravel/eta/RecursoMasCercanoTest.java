package uy.edu.fing.geotravel.eta;

import org.junit.Test;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

/**
 * La elección del recurso más cercano por calles, sin base de datos ni motor real: el motor es falso y devuelve una ruta
 * distinta según el origen (la longitud del recurso identifica a cada uno).
 */
public class RecursoMasCercanoTest {

    private static final long PLAZO = TimeUnit.SECONDS.toNanos(25);

    /** Un candidato con id n: a n * 100 m en línea recta (el 1 es el más cercano) y origen en la longitud -n. */
    private static RecursoMasCercano.Candidato candidato(int n) {
        Map<String, Object> datos = new LinkedHashMap<>();
        datos.put("id", n);
        datos.put("identificacion", "REC-" + n);
        datos.put("tipo", "ambulancia");
        datos.put("estadoOperativo", "Disponible");
        return new RecursoMasCercano.Candidato(n, datos, new RutaService.Extremos(-n, -31.0, -57.0, -31.0, n * 100.0));
    }

    private static List<RecursoMasCercano.Candidato> candidatos(int cuantos) {
        List<RecursoMasCercano.Candidato> lista = new ArrayList<>();
        for (int n = 1; n <= cuantos; n++) {
            lista.add(candidato(n));
        }
        return lista;
    }

    /** Un servicio cuyo motor devuelve la ruta que indique la función según el recurso (origen -n => n). */
    private static RutaService servicio(java.util.function.IntFunction<Ruta> porRecurso) {
        return new RutaService((oLon, oLat, dLon, dLat) -> porRecurso.apply((int) -oLon));
    }

    private static Object de(RecursoMasCercano.Evaluacion ev, int indice, String clave) {
        return ev.evaluados.get(indice).get(clave);
    }

    @Test
    public void ganaElDeMenorTiempoPorCallesAunqueNoSeaElMasCercanoEnLineaRecta() {
        // el 1 está a 100 m en línea recta pero tarda 600 s; el 3, a 300 m, tarda 200 s
        RutaService s = servicio(n -> n == 1 ? new Ruta(900, 600) : n == 2 ? new Ruta(500, 400) : new Ruta(700, 200));

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(3), s, PLAZO);

        assertNotNull(ev.elegido);
        assertEquals(3, ev.elegido.id);
        assertEquals(200.0, ev.ruta.duracionSegundos, 0.001);
        assertEquals(3, ev.evaluados.size());
        assertEquals(false, de(ev, 0, "elegido"));
        assertEquals(true, de(ev, 2, "elegido"));
        assertEquals("disponible", de(ev, 0, "estadoRuta"));
        assertEquals(7L, ((Number) de(ev, 1, "tiempoEstimadoMinutos")).longValue()); // 400 s = 7 min redondeado hacia arriba
        assertEquals(500L, ((Number) de(ev, 1, "distanciaMetros")).longValue());
    }

    @Test
    public void conElMismoTiempoGanaElDeMenorDistancia() {
        RutaService s = servicio(n -> n == 1 ? new Ruta(1200, 300) : new Ruta(800, 300));

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(2), s, PLAZO);

        assertEquals(2, ev.elegido.id);
    }

    @Test
    public void conEmpateTotalGanaElMasCercanoEnLineaRecta() {
        RutaService s = servicio(n -> new Ruta(1000, 300));

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(3), s, PLAZO);

        assertEquals(1, ev.elegido.id);
    }

    @Test
    public void unRecursoSinRutaSeInformaYNoImpideElegirOtro() {
        RutaService s = new RutaService((oLon, oLat, dLon, dLat) -> {
            if ((int) -oLon == 1) {
                throw new SinRutaException("a mas de 500 m de una calle");
            }
            return new Ruta(900, 450);
        });

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(2), s, PLAZO);

        assertEquals(2, ev.elegido.id);
        assertEquals("sin_ruta", de(ev, 0, "estadoRuta"));
        assertEquals("a mas de 500 m de una calle", de(ev, 0, "mensaje"));
        assertFalse(ev.motorCaido);
    }

    @Test
    public void siNingunoTieneRutaNoHayElegido() {
        RutaService s = new RutaService((oLon, oLat, dLon, dLat) -> {
            throw new SinRutaException("sin ruta");
        });

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(3), s, PLAZO);

        assertNull(ev.elegido);
        assertNull(ev.ruta);
        assertFalse(ev.motorCaido);
        assertFalse(ev.plazoAgotado);
        assertEquals(3, ev.evaluados.size());
        for (Map<String, Object> fila : ev.evaluados) {
            assertEquals(false, fila.get("elegido"));
        }
    }

    @Test
    public void siElMotorSeCaeNoSeInsisteConLosDemas() {
        AtomicInteger llamadas = new AtomicInteger();
        RutaService s = new RutaService((oLon, oLat, dLon, dLat) -> {
            llamadas.incrementAndGet();
            throw new IOException("el motor no respondio");
        });

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(4), s, PLAZO);

        assertEquals(1, llamadas.get());
        assertTrue(ev.motorCaido);
        assertNull(ev.elegido);
        assertEquals("error", de(ev, 0, "estadoRuta"));
        assertEquals("no_consultado", de(ev, 1, "estadoRuta"));
        assertEquals("no_consultado", de(ev, 3, "estadoRuta"));
    }

    @Test
    public void sinPlazoNoSeConsultaAlMotorYSeInformaElPlazoAgotado() {
        AtomicInteger llamadas = new AtomicInteger();
        RutaService s = new RutaService((oLon, oLat, dLon, dLat) -> {
            llamadas.incrementAndGet();
            return new Ruta(1, 1);
        });

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(3), s, 0);

        assertEquals(0, llamadas.get());
        assertTrue(ev.plazoAgotado);
        assertNull(ev.elegido);
        assertEquals("plazo_agotado", de(ev, 0, "estadoRuta"));
    }

    @Test
    public void laCantidadDeCandidatosSeValida() {
        assertEquals(RecursoMasCercano.CANDIDATOS_DEFECTO, RecursoMasCercano.candidatos(null));
        assertEquals(RecursoMasCercano.CANDIDATOS_DEFECTO, RecursoMasCercano.candidatos("  "));
        assertEquals(1, RecursoMasCercano.candidatos("1"));
        assertEquals(RecursoMasCercano.CANDIDATOS_MAXIMO, RecursoMasCercano.candidatos(" 10 "));
        for (String malo : new String[] {"0", "11", "-3", "cinco", "2.5"}) {
            try {
                RecursoMasCercano.candidatos(malo);
                fail("deberia rechazar '" + malo + "'");
            } catch (IllegalArgumentException esperado) {
                assertNotNull(esperado.getMessage());
            }
        }
    }
}
