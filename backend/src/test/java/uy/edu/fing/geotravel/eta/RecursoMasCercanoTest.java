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

    // ---------------------------------------------------------------- criterio: distancia o tiempo

    /** Las mismas tres rutas para los dos criterios: el 1 es corto y lento, el 3 es largo y rápido, el 2 queda en el medio. */
    private static Ruta rutaDe(int n) {
        return n == 1 ? new Ruta(500, 600) : n == 2 ? new Ruta(700, 400) : new Ruta(900, 200);
    }

    @Test
    public void conCriterioDistanciaGanaElMasCortoAunqueTardeMas() {
        RecursoMasCercano.Evaluacion ev =
                RecursoMasCercano.evaluar(candidatos(3), servicio(RecursoMasCercanoTest::rutaDe), PLAZO, Criterio.DISTANCIA);

        assertEquals(1, ev.elegido.id);
        assertEquals(500.0, ev.ruta.distanciaMetros, 0.001);
    }

    @Test
    public void conCriterioTiempoGanaElMasRapidoAunqueSeaMasLargo() {
        RecursoMasCercano.Evaluacion ev =
                RecursoMasCercano.evaluar(candidatos(3), servicio(RecursoMasCercanoTest::rutaDe), PLAZO, Criterio.TIEMPO);

        assertEquals(3, ev.elegido.id);
        assertEquals(200.0, ev.ruta.duracionSegundos, 0.001);
    }

    @Test
    public void sinIndicarCriterioSigueGanandoElDeMenorTiempo() {
        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(3), servicio(RecursoMasCercanoTest::rutaDe), PLAZO);

        assertEquals(3, ev.elegido.id);
    }

    @Test
    public void conCriterioDistanciaYMismaDistanciaGanaElMasRapido() {
        RutaService s = servicio(n -> n == 1 ? new Ruta(800, 500) : new Ruta(800, 300));

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(2), s, PLAZO, Criterio.DISTANCIA);

        assertEquals(2, ev.elegido.id);
    }

    @Test
    public void conCriterioDistanciaYEmpateTotalGanaElMasCercanoEnLineaRecta() {
        RutaService s = servicio(n -> new Ruta(800, 300));

        RecursoMasCercano.Evaluacion ev = RecursoMasCercano.evaluar(candidatos(3), s, PLAZO, Criterio.DISTANCIA);

        assertEquals(1, ev.elegido.id);
    }

    @Test
    public void elCriterioLlegaAlMotorYCadaUnoTieneSuPropiaRutaEnLaCache() throws Exception {
        List<Criterio> pedidos = new ArrayList<>();
        RutaService.MotorRutas motor = new RutaService.MotorRutas() {
            @Override
            public Ruta calcular(double oLon, double oLat, double dLon, double dLat) {
                return new Ruta(1, 1);
            }

            @Override
            public Ruta calcular(double oLon, double oLat, double dLon, double dLat, long timeoutMs, Criterio criterio) {
                pedidos.add(criterio);
                return criterio == Criterio.DISTANCIA ? new Ruta(100, 90) : new Ruta(150, 60);
            }
        };
        RutaService s = new RutaService(motor);
        RutaService.Extremos e = new RutaService.Extremos(-57.0, -31.0, -57.1, -31.1, 50);

        Ruta corta = s.consultar(e, 1000, Criterio.DISTANCIA);
        Ruta rapida = s.consultar(e, 1000, Criterio.TIEMPO);
        s.consultar(e, 1000, Criterio.DISTANCIA); // sale de la cache: no vuelve a llamar al motor

        assertEquals(100.0, corta.distanciaMetros, 0.001);
        assertEquals(150.0, rapida.distanciaMetros, 0.001);
        assertEquals(java.util.Arrays.asList(Criterio.DISTANCIA, Criterio.TIEMPO), pedidos);
    }

    @Test
    public void elCriterioSeValida() {
        assertEquals(Criterio.DISTANCIA, Criterio.de(null, Criterio.DISTANCIA));
        assertEquals(Criterio.TIEMPO, Criterio.de("  ", Criterio.TIEMPO));
        assertEquals(Criterio.TIEMPO, Criterio.de("tiempo", Criterio.DISTANCIA));
        assertEquals(Criterio.DISTANCIA, Criterio.de(" Distancia ", Criterio.TIEMPO));
        try {
            Criterio.de("barato", Criterio.TIEMPO);
            fail("deberia rechazar un criterio desconocido");
        } catch (IllegalArgumentException esperado) {
            assertNotNull(esperado.getMessage());
        }
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
