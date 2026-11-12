package uy.edu.fing.geotravel.consultas;

import org.junit.Test;
import uy.edu.fing.geotravel.eta.Criterio;
import uy.edu.fing.geotravel.eta.PlazoAgotadoException;
import uy.edu.fing.geotravel.eta.Ruta;
import uy.edu.fing.geotravel.eta.SinRutaException;
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
        assertEquals(5, AnalisisVial.validar(null).limite);
    }

    @Test(expected = IllegalArgumentException.class)
    public void unLimiteNoNumericoEsInvalido() {
        AnalisisVial.entero("limite", "abc");
    }

    @Test
    public void enteroTomaVacioComoAusente() {
        assertNull(AnalisisVial.entero("limite", null));
        assertNull(AnalisisVial.entero("limite", " "));
        assertEquals(Integer.valueOf(7), AnalisisVial.entero("limite", " 7 "));
    }

    @Test
    public void aceptaElLimiteMaximo() {
        assertEquals(AnalisisVial.LIMITE_MAXIMO, AnalisisVial.validar(AnalisisVial.LIMITE_MAXIMO).limite);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaLimiteMayorAlMaximo() {
        AnalisisVial.validar(AnalisisVial.LIMITE_MAXIMO + 1);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaLimiteCero() {
        AnalisisVial.validar(0);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rechazaLimiteNegativo() {
        AnalisisVial.validar(-3);
    }

    // ------------------------------------------------------------------ rutas

    @Test
    public void respuestaParcialConservaLosRecursosSinRuta() {
        // 1: ok, 2: sin ruta, 3: ok
        AtomicInteger n = new AtomicInteger();
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) -> {
            int llamada = n.incrementAndGet();
            if (llamada == 2) throw new SinRutaException("No se encontro ruta vial");
            return new Ruta(1000 + llamada, 100 * llamada);
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
            throw new IOException("El motor de rutas respondio HTTP 503");
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
            return new Ruta(1000, 100);
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
            return new Ruta(1000, 100);
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
            public Ruta calcular(double a, double b, double c, double d) {
                return new Ruta(1000, 100);
            }
            public Ruta calcular(double a, double b, double c, double d, long t)
                    throws java.io.IOException {
                llamadas.incrementAndGet();
                throw new PlazoAgotadoException("lento");
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
    public void elRecursoMasCercanoPorCallesEsElDeMenorDistancia() {
        // el recurso 3 (el mas lejano en linea recta) tiene el camino mas corto, aunque tarde mas
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) ->
                a < -57.9625 ? new Ruta(800, 300) : new Ruta(1000, 50)));
        List<AnalisisVial.Candidato> lista = candidatos(3);

        analisis.calcularRutas(lista, SIN_PLAZO);

        assertEquals(Integer.valueOf(3), AnalisisVial.recursoMasCercanoPorCalles(lista));
    }

    @Test
    public void aIgualDistanciaPorCallesGanaElMasRapido() {
        AnalisisVial analisis = new AnalisisVial(new RutaService((a, b, c, d) ->
                new Ruta(900, a < -57.9625 ? 100 : 300)));
        List<AnalisisVial.Candidato> lista = candidatos(3);

        analisis.calcularRutas(lista, SIN_PLAZO);

        assertEquals(Integer.valueOf(3), AnalisisVial.recursoMasCercanoPorCalles(lista));
    }

    @Test
    public void sinRutasNoHayRecursoMasCercanoPorCalles() {
        assertNull(AnalisisVial.recursoMasCercanoPorCalles(candidatos(2)));
    }

    @Test
    public void lasRutasSePidenPorDistancia() {
        List<Criterio> pedidos = new ArrayList<>();
        AnalisisVial analisis = new AnalisisVial(new RutaService(new RutaService.MotorRutas() {
            public Ruta calcular(double a, double b, double c, double d) {
                return new Ruta(1000, 100);
            }
            public Ruta calcular(double a, double b, double c, double d, long t, Criterio criterio) {
                pedidos.add(criterio);
                return new Ruta(1000, 100);
            }
        }));

        analisis.calcularRutas(candidatos(3), SIN_PLAZO);

        assertEquals(3, pedidos.size());
        for (Criterio criterio : pedidos) {
            assertEquals(Criterio.DISTANCIA, criterio);
        }
    }
}
