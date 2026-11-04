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
 * Pruebas de integracion de P2 contra el grafo real de P1 (Salto) en PostgreSQL/pgRouting.
 * Se activan con URBANSAFE_PGROUTING_TESTS=true y la base apuntada por DB_HOST/DB_PORT
 * (el entorno aislado de validacion usa DB_PORT=55432). No interviene OSRM en ninguna prueba.
 *
 * Pares usados (datos del seed de Salto):
 *   DEMO:  recurso TEST-ETA-SALTO-01 (-57.96215,-31.39029) -> incidente TEST ETA Salto (-57.95340,-31.38927)
 *   LARGO: recurso 62 (-57.86743,-31.36814) -> incidente 71 (-57.98734,-31.39775), ~11,9 km en linea recta;
 *          verificado a mano: mas_rapida 14,4 km / 17 min, mas_corta 13,5 km / 19 min (rutas distintas).
 */
public class PgRoutingIntegrationTest {

    private static final double[] DEMO = {-57.96215, -31.39029, -57.95340, -31.38927};
    private static final double[] LARGO = {-57.86743, -31.36814, -57.98734, -31.39775};
    /** Montevideo: fuera de la cobertura del grafo de Salto. */
    private static final double[] FUERA = {-56.19, -34.90, -56.1685, -34.9158};

    private final MotorPgRouting rapida = new MotorPgRouting(Criterio.MAS_RAPIDA);
    private final MotorPgRouting corta = new MotorPgRouting(Criterio.MAS_CORTA);

    @Before
    public void preparar() {
        Assume.assumeTrue("Definir URBANSAFE_PGROUTING_TESTS=true con la base pgRouting levantada",
                "true".equalsIgnoreCase(System.getenv("URBANSAFE_PGROUTING_TESTS")));
        Assume.assumeTrue("Se requiere la extension, el grafo de P1 y la funcion de P2 instalados",
                rapida.saludable());
    }

    @Test
    public void saludableInformaExtensionGrafoYFuncion() {
        assertTrue(new MotorPgRouting(Criterio.MAS_RAPIDA).saludable());
        assertTrue(new MotorPgRouting(Criterio.MAS_CORTA).saludable());
    }

    @Test
    public void elMotorSeReportaComoPgRouting() {
        RutaService servicio = new RutaService(rapida, corta);
        assertEquals("pgRouting (PostgreSQL)", servicio.nombreMotor(Criterio.MAS_RAPIDA));
        assertEquals("pgRouting (PostgreSQL)", servicio.nombreMotor(Criterio.MAS_CORTA));
        assertTrue(servicio.disponible(Criterio.MAS_RAPIDA));
        assertTrue(servicio.disponible(Criterio.MAS_CORTA));
    }

    @Test
    public void calculaRutaEnPostgreSQL() throws Exception {
        OsrmClient.Ruta ruta = rapida.calcular(DEMO[0], DEMO[1], DEMO[2], DEMO[3]);

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
    public void masCortaMinimizaDistanciaYMasRapidaMinimizaDuracion() throws Exception {
        OsrmClient.Ruta rapidaRuta = rapida.calcular(LARGO[0], LARGO[1], LARGO[2], LARGO[3]);
        OsrmClient.Ruta cortaRuta = corta.calcular(LARGO[0], LARGO[1], LARGO[2], LARGO[3]);

        assertTrue("la corta nunca es mas larga",
                cortaRuta.distanciaMetros <= rapidaRuta.distanciaMetros + 0.5);
        assertTrue("la rapida nunca es mas lenta",
                rapidaRuta.duracionSegundos <= cortaRuta.duracionSegundos + 0.5);
    }

    @Test
    public void enViajeLargoLosCriteriosDifieren() throws Exception {
        OsrmClient.Ruta rapidaRuta = rapida.calcular(LARGO[0], LARGO[1], LARGO[2], LARGO[3]);
        OsrmClient.Ruta cortaRuta = corta.calcular(LARGO[0], LARGO[1], LARGO[2], LARGO[3]);

        assertTrue("las rutas difieren en mas de 1 m",
                Math.abs(rapidaRuta.distanciaMetros - cortaRuta.distanciaMetros) > 1.0);
    }

    @Test
    public void fueraDeCoberturaEsSinRuta() throws Exception {
        try {
            rapida.calcular(FUERA[0], FUERA[1], FUERA[2], FUERA[3]);
            fail("Un par fuera del grafo no tiene ruta");
        } catch (OsrmClient.SinRutaException esperada) {
            // El extremo queda a mas de 250 m del nodo mas cercano: la funcion no devuelve filas.
        }
    }

    @Test
    public void mismoPuntoDaRutaNula() throws Exception {
        OsrmClient.Ruta ruta = rapida.calcular(DEMO[0], DEMO[1], DEMO[0], DEMO[1]);
        assertEquals(0.0, ruta.distanciaMetros, 0.001);
        assertEquals(0.0, ruta.duracionSegundos, 0.001);
    }

    @Test
    public void criterioInvalidoLoRechazaLaFuncionSQL() throws Exception {
        // Desde Java no se puede falsificar el enum Criterio; la validacion es de la funcion SQL.
        try (java.sql.Connection c = uy.edu.fing.geotravel.db.DataSourceProvider.get().getConnection();
             java.sql.PreparedStatement ps = c.prepareStatement(
                     "SELECT 1 FROM public.p2_calcular_ruta(?, ?, ?, ?, 'barata')")) {
            ps.setDouble(1, DEMO[0]);
            ps.setDouble(2, DEMO[1]);
            ps.setDouble(3, DEMO[2]);
            ps.setDouble(4, DEMO[3]);
            ps.executeQuery();
            fail("un criterio desconocido debe ser rechazado");
        } catch (java.sql.SQLException esperada) {
            assertEquals("22023", esperada.getSQLState());
        }
    }

    @Test
    public void plazoAgotadoSeTraduce() {
        try {
            rapida.calcular(DEMO[0], DEMO[1], DEMO[2], DEMO[3], 0);
            fail("timeout 0 debe agotar el plazo");
        } catch (OsrmClient.PlazoAgotadoException esperada) {
            // limite estricto de tiempo, igual que con OSRM
        } catch (Exception e) {
            fail("se esperaba PlazoAgotadoException y llego " + e);
        }
    }
}
