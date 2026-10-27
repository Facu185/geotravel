package uy.edu.fing.geotravel.consultas;

import org.junit.Test;
import uy.edu.fing.geotravel.eta.OsrmClient;
import uy.edu.fing.geotravel.eta.RutaService;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class AnalisisVialTest {

    private static final long SIN_PLAZO = System.nanoTime() + 3_600_000_000_000L;

    private static AnalisisVial.Candidato candidato(int id, double lon) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("recursoId", id);
        item.put("estadoRuta", "no_calculada");
        return new AnalisisVial.Candidato(item, new RutaService.Extremos(lon, -31.39, -57.95, -31.389, 500));
    }

    private static List<AnalisisVial.Candidato> candidatos(int cantidad) {
        List<AnalisisVial.Candidato> lista = new ArrayList<>();
        for (int i = 1; i <= cantidad; i++) {
            lista.add(candidato(i, -57.96 - i * 0.001));
        }
        return lista;
    }

    // ------------------------------------------------------------------ validacion

    @Test
    public void usaValoresPorDefecto() {
        AnalisisVial.Parametros p = AnalisisVial.validar(null, null);
        assertEquals(2000, p.radioMetros);
        assertEquals(5, p.limite);
    }

    @Test(expected = IllegalArgumentException.class)
    public void unRadioNoNumericoEsInvalido() {
        AnalisisVial.entero("radioMetros", "abc");
    }

    @Test
    public void enteroTomaVacioComoAusente() {
        assertNull(AnalisisVial.entero("limite", null));
        assertNull(AnalisisVial.entero("limite", " "));
        assertEquals(Integer.valueOf(250), AnalisisVial.entero("radioMetros", " 250 "));
    }

    @Test
    public void aceptaElRadioMaximo() {
        assertEquals(AnalisisVial.RADIO_MAXIMO_M, AnalisisVial.validar(AnalisisVial.RADIO_MAXIMO_M, 1).radioMetros);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaRadioMayorAlMaximo() {
        AnalisisVial.validar(AnalisisVial.RADIO_MAXIMO_M + 1, null);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaRadioCero() {
        AnalisisVial.validar(0, null);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaRadioNegativo() {
        AnalisisVial.validar(-500, null);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaLimiteMayorAlMaximo() {
        AnalisisVial.validar(1000, AnalisisVial.LIMITE_MAXIMO + 1);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaLimiteCero() {
        AnalisisVial.validar(1000, 0);
    }

    // ------------------------------------------------------------------ rutas

    @Test
    public void respuestaParcialConservaLosRecursosSinRuta() {
        // 1: ok, 2: sin ruta, 3: ok
        AtomicInteger n = new AtomicInteger();
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) -> {
            int llamada = n.incrementAndGet();
            if (llamada == 2) throw new OsrmClient.SinRutaException("No se encontro ruta vial");
            return new OsrmClient.Ruta(1000 + llamada, 100 * llamada);
        }));
        List<AnalisisVial.Candidato> lista = candidatos(3);

        int obtenidas = analisis.calcularRutas(lista, SIN_PLAZO);

        assertEquals(2, obtenidas);
        assertEquals("disponible", lista.get(0).item.get("estadoRuta"));
        assertEquals("sin_ruta", lista.get(1).item.get("estadoRuta"));
        assertTrue(lista.get(1).item.get("mensajeRuta").toString().startsWith("Ruta no disponible"));
        assertEquals("disponible", lista.get(2).item.get("estadoRuta"));
        assertEquals(1001L, lista.get(0).item.get("distanciaViaM"));
    }

    @Test
    public void siElMotorNoRespondeNoSeInsisteConLosDemas() {
        AtomicInteger llamadas = new AtomicInteger();
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) -> {
            llamadas.incrementAndGet();
            throw new IOException("OSRM respondio HTTP 503");
        }));
        List<AnalisisVial.Candidato> lista = candidatos(4);

        int obtenidas = analisis.calcularRutas(lista, SIN_PLAZO);

        assertEquals(0, obtenidas);
        assertEquals(1, llamadas.get());
        for (AnalisisVial.Candidato c : lista) {
            assertEquals("error", c.item.get("estadoRuta"));
        }
    }

    @Test
    public void soloSePidenRutasDeLosRecursosMasCercanos() {
        AtomicInteger llamadas = new AtomicInteger();
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) -> {
            llamadas.incrementAndGet();
            return new OsrmClient.Ruta(1000, 100);
        }));
        List<AnalisisVial.Candidato> lista = candidatos(AnalisisVial.RUTAS_MAXIMAS + 3);

        analisis.calcularRutas(lista, SIN_PLAZO);

        assertEquals(AnalisisVial.RUTAS_MAXIMAS, llamadas.get());
        AnalisisVial.Candidato ultimo = lista.get(lista.size() - 1);
        assertEquals("no_calculada", ultimo.item.get("estadoRuta"));
        assertNotNull(ultimo.item.get("mensajeRuta"));
    }

    @Test
    public void conPlazoVencidoNoConsultaAlMotor() {
        AtomicInteger llamadas = new AtomicInteger();
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) -> {
            llamadas.incrementAndGet();
            return new OsrmClient.Ruta(1000, 100);
        }));
        List<AnalisisVial.Candidato> lista = candidatos(2);

        analisis.calcularRutas(lista, System.nanoTime() - 1);

        assertEquals(0, llamadas.get());
        assertEquals("plazo_agotado", lista.get(0).item.get("estadoRuta"));
    }

    @Test
    public void unPedidoQueExcedeElPlazoNoRetienePasaLosDemas() {
        AtomicInteger llamadas = new AtomicInteger();
        AnalisisVial analisis = new AnalisisVial(new RutaService(new RutaService.MotorRutas() {
            public OsrmClient.Ruta calcular(double a, double b, double c, double d) {
                return new OsrmClient.Ruta(1000, 100);
            }
            public OsrmClient.Ruta calcular(double a, double b, double c, double d, long t)
                    throws java.io.IOException {
                llamadas.incrementAndGet();
                throw new OsrmClient.PlazoAgotadoException("lento");
            }
        }));
        List<AnalisisVial.Candidato> lista = candidatos(3);

        int obtenidas = analisis.calcularRutas(lista, System.nanoTime() + 5_000_000_000L);

        assertEquals(0, obtenidas);
        assertEquals(1, llamadas.get());
        assertEquals("plazo_agotado", lista.get(0).item.get("estadoRuta"));
        assertEquals("plazo_agotado", lista.get(2).item.get("estadoRuta"));
    }

    @Test
    public void elRecursoMasRapidoEsElDeMenorDuracion() {
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) ->
                new OsrmClient.Ruta(1000, a < -57.9625 ? 50 : 300)));
        List<AnalisisVial.Candidato> lista = candidatos(3);

        analisis.calcularRutas(lista, SIN_PLAZO);

        assertEquals(Integer.valueOf(3), AnalisisVial.recursoMasRapido(lista));
    }

    @Test
    public void sinRutasNoHayRecursoMasRapido() {
        assertNull(AnalisisVial.recursoMasRapido(candidatos(2)));
        assertNull(AnalisisVial.recursoMasCorto(candidatos(2)));
    }

    @Test
    public void elRecursoMasCortoEsElDeMenorDistanciaAunqueTardeMas() {
        AnalisisVial analisis = new AnalisisVial(new RutaService(
                (a, b, c, d) -> new OsrmClient.Ruta(1000, 50),
                (a, b, c, d) -> new OsrmClient.Ruta(a < -57.9625 ? 700 : 1200, 400)));
        List<AnalisisVial.Candidato> lista = candidatos(3);

        analisis.calcularRutas(lista, SIN_PLAZO, uy.edu.fing.geotravel.eta.Criterio.MAS_CORTA);

        assertEquals(Integer.valueOf(3), AnalisisVial.recursoMasCorto(lista));
        assertEquals(Long.valueOf(700), lista.get(2).item.get("distanciaViaM"));
    }

    @Test
    public void conCortaNoConfiguradaLosRecursosQuedanEnError() {
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) -> new OsrmClient.Ruta(1, 1)));
        List<AnalisisVial.Candidato> lista = candidatos(2);

        int obtenidas = analisis.calcularRutas(lista, SIN_PLAZO, uy.edu.fing.geotravel.eta.Criterio.MAS_CORTA);

        assertEquals(0, obtenidas);
        assertEquals("error", lista.get(0).item.get("estadoRuta"));
    }
}
