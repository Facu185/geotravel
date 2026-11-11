package uy.edu.fing.geotravel.eta;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.Assume;
import org.junit.Before;
import org.junit.Test;

import java.io.IOException;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

/**
 * Pruebas de integracion del ruteo contra la red vial de OpenStreetMap de todo Uruguay en PostgreSQL/pgRouting.
 * Se activan con URBANSAFE_PGROUTING_TESTS=true y la base apuntada por DB_HOST/DB_PORT, con la red vial ya cargada
 * (servicio red-vial de infra/docker-compose.yml).
 *
 * Pares usados:
 *   DEMO:     recurso TEST-ETA-SALTO-01 (-57.96215,-31.39029) -> incidente TEST ETA Salto (-57.95340,-31.38927)
 *   LARGO:    Salto (-57.9606,-31.3857) -> Montevideo (-56.1949,-34.9063), unos 490 km.
 *   MONTEVIDEO: dos puntos del centro de Montevideo (la red cubre todo el pais, no solo Salto).
 *   MAR:      dos puntos en el Atlantico: quedan a mas de 500 m de cualquier calle.
 */
public class PgRoutingIntegrationTest {

    private static final double[] DEMO = {-57.96215, -31.39029, -57.95340, -31.38927};
    private static final double[] LARGO = {-57.9606, -31.3857, -56.1949, -34.9063};
    private static final double[] MONTEVIDEO = {-56.19, -34.90, -56.1685, -34.9158};
    private static final double[] MAR = {-55.0, -35.8, -54.9, -35.85};
    /** Sale de una avenida de dos calzadas de mano unica (Av. Wilson Ferreira Aldunate, Salto): hay que dar la vuelta. */
    private static final double[] CALZADA_UNICA = {-57.94953, -31.40363, -57.953308, -31.405874};

    private final MotorPgRouting motor = new MotorPgRouting();

    @Before
    public void preparar() {
        Assume.assumeTrue("Definir URBANSAFE_PGROUTING_TESTS=true con la base pgRouting levantada",
                "true".equalsIgnoreCase(System.getenv("URBANSAFE_PGROUTING_TESTS")));
        Assume.assumeTrue("Se requiere la extension, el grafo de P1 y la funcion de P2 instalados",
                motor.saludable());
    }

    @Test
    public void saludableInformaExtensionGrafoYFuncion() {
        assertTrue(new MotorPgRouting().saludable());
    }

    @Test
    public void elMotorSeReportaComoPgRouting() {
        RutaService servicio = new RutaService(motor);
        assertEquals("pgRouting (PostgreSQL)", servicio.nombreMotor());
        assertTrue(servicio.disponible());
    }

    @Test
    public void calculaRutaEnPostgreSQL() throws Exception {
        Ruta ruta = motor.calcular(DEMO[0], DEMO[1], DEMO[2], DEMO[3]);

        assertTrue("distancia positiva", ruta.distanciaMetros > 0);
        assertTrue("duracion positiva", ruta.duracionSegundos > 0);
        assertEquals("LineString", ruta.geometriaRuta.path("type").asText());
        JsonNode primera = ruta.geometriaRuta.path("coordinates").path(0);
        assertTrue("longitud en Salto", primera.path(0).asDouble() < -57.8 && primera.path(0).asDouble() > -58.1);
        assertTrue("latitud en Salto", primera.path(1).asDouble() < -31.3 && primera.path(1).asDouble() > -31.5);
        assertNotNull("informa el ajuste del origen", ruta.ajusteOrigenMetros);
        assertNotNull("informa el ajuste del destino", ruta.ajusteDestinoMetros);
    }

    @Test
    public void laRutaNoRecorreDosVecesElMismoTramo() throws Exception {
        for (double[] par : new double[][] {CALZADA_UNICA, DEMO, MONTEVIDEO}) {
            for (Criterio criterio : Criterio.values()) {
                Ruta ruta = motor.calcular(par[0], par[1], par[2], par[3], 20_000, criterio);
                JsonNode puntos = ruta.geometriaRuta.path("coordinates");
                java.util.Set<String> tramos = new java.util.HashSet<>();
                for (int i = 1; i < puntos.size(); i++) {
                    String a = puntos.path(i - 1).toString();
                    String b = puntos.path(i).toString();
                    if (a.equals(b)) continue;
                    String clave = a.compareTo(b) < 0 ? a + "|" + b : b + "|" + a;
                    assertTrue("tramo repetido " + clave + " (" + criterio + ")", tramos.add(clave));
                }
            }
        }
    }

    @Test
    public void elCriterioDistanciaDaRutaIgualOMasCortaYElDeTiempoIgualOMasRapida() throws Exception {
        for (double[] par : new double[][] {DEMO, LARGO, MONTEVIDEO}) {
            Ruta rapida = motor.calcular(par[0], par[1], par[2], par[3], 20_000, Criterio.TIEMPO);
            Ruta corta = motor.calcular(par[0], par[1], par[2], par[3], 20_000, Criterio.DISTANCIA);

            assertTrue("la ruta por distancia no es mas larga que la de tiempo",
                    corta.distanciaMetros <= rapida.distanciaMetros + 0.5);
            assertTrue("la ruta por tiempo no es mas lenta que la de distancia",
                    rapida.duracionSegundos <= corta.duracionSegundos + 0.5);
            assertTrue(corta.duracionSegundos > 0 && rapida.distanciaMetros > 0);
        }
    }

    @Test
    public void sinCriterioSeUsaElTiempo() throws Exception {
        Ruta sinCriterio = motor.calcular(DEMO[0], DEMO[1], DEMO[2], DEMO[3]);
        Ruta conTiempo = motor.calcular(DEMO[0], DEMO[1], DEMO[2], DEMO[3], 20_000, Criterio.TIEMPO);

        assertEquals(conTiempo.distanciaMetros, sinCriterio.distanciaMetros, 0.001);
        assertEquals(conTiempo.duracionSegundos, sinCriterio.duracionSegundos, 0.001);
    }

    @Test
    public void laRutaSaleYLlegaALosPuntosPedidos() throws Exception {
        Ruta ruta = motor.calcular(DEMO[0], DEMO[1], DEMO[2], DEMO[3]);
        JsonNode coordenadas = ruta.geometriaRuta.path("coordinates");
        JsonNode primera = coordenadas.path(0);
        JsonNode ultima = coordenadas.path(coordenadas.size() - 1);
        // El trazado empieza en el recurso y termina en el incidente (tramo recto hasta la calle incluido), no en una esquina.
        assertEquals(DEMO[0], primera.path(0).asDouble(), 0.00002);
        assertEquals(DEMO[1], primera.path(1).asDouble(), 0.00002);
        assertEquals(DEMO[2], ultima.path(0).asDouble(), 0.00002);
        assertEquals(DEMO[3], ultima.path(1).asDouble(), 0.00002);
    }

    @Test
    public void informaLasCallesDelRecorrido() throws Exception {
        Ruta ruta = motor.calcular(DEMO[0], DEMO[1], DEMO[2], DEMO[3]);
        assertNotNull("lista las calles", ruta.calles);
        assertTrue("al menos una calle", ruta.calles.size() >= 1);
        assertTrue("con su largo", ruta.calles.path(0).path("metros").asDouble() >= 0);
        assertTrue("con su nombre", ruta.calles.path(0).has("calle"));
    }

    @Test
    public void rutaEnMontevideoPorqueLaRedCubreTodoElPais() throws Exception {
        Ruta ruta = motor.calcular(MONTEVIDEO[0], MONTEVIDEO[1], MONTEVIDEO[2], MONTEVIDEO[3]);
        assertTrue(ruta.distanciaMetros > 1000 && ruta.distanciaMetros < 6000);
        assertTrue(ruta.duracionSegundos > 0);
    }

    @Test
    public void unViajeLargoEntreCiudadesTienePocasCallesNombradas() throws Exception {
        Ruta ruta = motor.calcular(LARGO[0], LARGO[1], LARGO[2], LARGO[3]);
        assertTrue("es una ruta de varios cientos de km (Salto - Montevideo)", ruta.distanciaMetros > 400_000);
        assertTrue("con su lista de calles", ruta.calles.size() > 5);
    }

    @Test
    public void fueraDeCoberturaEsSinRuta() throws Exception {
        try {
            motor.calcular(MAR[0], MAR[1], MAR[2], MAR[3]);
            fail("Un par fuera de la red vial no tiene ruta");
        } catch (SinRutaException esperada) {
            // Los extremos quedan a mas de 500 m de cualquier calle: la funcion no devuelve filas.
        }
    }

    @Test
    public void mismoPuntoDaRutaNula() throws Exception {
        Ruta ruta = motor.calcular(DEMO[0], DEMO[1], DEMO[0], DEMO[1]);
        // Sin calles de por medio: solo cuentan los tramos rectos hasta la calle (el ajuste de cada extremo).
        assertEquals(ruta.ajusteOrigenMetros + ruta.ajusteDestinoMetros, ruta.distanciaMetros, 0.01);
    }

    @Test
    public void plazoAgotadoSeTraduce() {
        try {
            motor.calcular(DEMO[0], DEMO[1], DEMO[2], DEMO[3], 0);
            fail("timeout 0 debe agotar el plazo");
        } catch (PlazoAgotadoException esperada) {
            // limite estricto de tiempo
        } catch (Exception e) {
            fail("se esperaba PlazoAgotadoException y llego " + e);
        }
    }
}
