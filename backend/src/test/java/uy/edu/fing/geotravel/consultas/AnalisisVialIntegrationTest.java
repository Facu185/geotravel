package uy.edu.fing.geotravel.consultas;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.After;
import org.junit.Assume;
import org.junit.Before;
import org.junit.Test;
import uy.edu.fing.geotravel.db.DataSourceProvider;
import uy.edu.fing.geotravel.eta.OsrmClient;
import uy.edu.fing.geotravel.eta.RutaService;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/** Pruebas contra PostGIS local; se activan con URBANSAFE_INTEGRATION_TESTS=true. El motor de rutas es simulado. */
public class AnalisisVialIntegrationTest {

    private static final double LON = -57.96215;
    private static final double LAT = -31.39029;

    private final List<Integer> incidentes = new ArrayList<>();
    private final List<Integer> recursos = new ArrayList<>();
    private String prefijo;
    private AnalisisVial analisis;

    @Before
    public void preparar() {
        Assume.assumeTrue("Definir URBANSAFE_INTEGRATION_TESTS=true para usar PostGIS local",
                "true".equalsIgnoreCase(System.getenv("URBANSAFE_INTEGRATION_TESTS")));
        prefijo = "IT-AV-" + UUID.randomUUID();
        analisis = new AnalisisVial(new RutaService((a, b, c, d) -> new OsrmClient.Ruta(1200, 150)));
    }

    @After
    public void limpiar() throws Exception {
        if (incidentes.isEmpty() && recursos.isEmpty()) return;
        try (Connection c = DataSourceProvider.get().getConnection()) {
            borrar(c, "recurso", recursos);
            borrar(c, "incidente", incidentes);
        }
    }

    private static void borrar(Connection c, String tabla, List<Integer> ids) throws Exception {
        try (PreparedStatement ps = c.prepareStatement("DELETE FROM " + tabla + " WHERE id = ?")) {
            for (Integer id : ids) {
                ps.setInt(1, id);
                ps.executeUpdate();
            }
        }
    }

    private int incidente(String geojson) throws Exception {
        try (Connection c = DataSourceProvider.get().getConnection();
             PreparedStatement ps = c.prepareStatement(
                     "INSERT INTO incidente (titulo, tipo_incidente, prioridad, geom) VALUES (?, 'otro', 3, "
                             + "ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)) RETURNING id")) {
            ps.setString(1, prefijo);
            ps.setString(2, geojson);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                incidentes.add(rs.getInt(1));
                return rs.getInt(1);
            }
        }
    }

    /** Un recurso a "metrosAlEste" metros al este del punto base (en UTM, donde el eje x es metros). */
    private int recurso(String nombre, String estado, double metrosAlEste) throws Exception {
        try (Connection c = DataSourceProvider.get().getConnection();
             PreparedStatement ps = c.prepareStatement(
                     "INSERT INTO recurso (identificacion, tipo, estado_operativo, geom) VALUES (?, 'ambulancia', ?, "
                             + "ST_Translate(ST_Transform(ST_SetSRID(ST_MakePoint(?, ?), 4326), 32721), ?, 0)) RETURNING id")) {
            ps.setString(1, prefijo + nombre);
            ps.setString(2, estado);
            ps.setDouble(3, LON);
            ps.setDouble(4, LAT);
            ps.setDouble(5, metrosAlEste);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                recursos.add(rs.getInt(1));
                return rs.getInt(1);
            }
        }
    }

    private static final String PUNTO = "{\"type\":\"Point\",\"coordinates\":[" + LON + "," + LAT + "]}";

    private Map<String, Object> analizar(int incidenteId, int radio, int limite, boolean soloDisp, boolean rutas)
            throws Exception {
        try (Connection c = DataSourceProvider.get().getConnection()) {
            return analisis.analizar(c, incidenteId, AnalisisVial.validar(radio, limite), soloDisp, rutas);
        }
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> items(Map<String, Object> r) {
        return (List<Map<String, Object>>) r.get("items");
    }

    /** Solo cuenta los recursos creados por esta prueba (la base puede tener otros). */
    private List<Map<String, Object>> propios(Map<String, Object> r) {
        List<Map<String, Object>> propios = new ArrayList<>();
        for (Map<String, Object> item : items(r)) {
            if (String.valueOf(item.get("identificacion")).startsWith(prefijo)) propios.add(item);
        }
        return propios;
    }

    @Test
    public void bufferDePuntoSeleccionaSoloRecursosDentroDelRadio() throws Exception {
        int inc = incidente(PUNTO);
        recurso("-cerca", "Disponible", 300);
        recurso("-lejos", "Disponible", 3000);

        Map<String, Object> r = analizar(inc, 1000, 10, false, false);

        List<Map<String, Object>> propios = propios(r);
        assertEquals(1, propios.size());
        assertEquals(prefijo + "-cerca", propios.get(0).get("identificacion"));
        double directa = ((Number) propios.get(0).get("distanciaDirectaM")).doubleValue();
        assertEquals(300, directa, 1.0);
        assertEquals("no_calculada", propios.get(0).get("estadoRuta"));
        JsonNode buffer = (JsonNode) r.get("bufferGeom");
        assertEquals("Polygon", buffer.get("type").asText());
        assertEquals("LineString", ((JsonNode) propios.get(0).get("lineaDirecta")).get("type").asText());
    }

    @Test
    public void radioMayorIncorporaMasRecursos() throws Exception {
        int inc = incidente(PUNTO);
        recurso("-cerca", "Disponible", 300);
        recurso("-lejos", "Disponible", 3000);

        assertEquals(2, propios(analizar(inc, 5000, 10, false, false)).size());
    }

    @Test
    public void bufferDeLineaFormaUnCorredor() throws Exception {
        int inc = incidente("{\"type\":\"LineString\",\"coordinates\":[[" + LON + "," + LAT + "],["
                + (LON + 0.02) + "," + LAT + "]]}");
        recurso("-junto-a-la-linea", "Disponible", 1000);

        Map<String, Object> r = analizar(inc, 500, 10, false, false);

        assertEquals(1, propios(r).size());
        assertEquals("Polygon", ((JsonNode) r.get("bufferGeom")).get("type").asText());
    }

    @Test
    public void bufferDePoligonoSeExtiendeMasAllaDelArea() throws Exception {
        double d = 0.002;
        int inc = incidente("{\"type\":\"Polygon\",\"coordinates\":[[[" + LON + "," + LAT + "],[" + (LON + d) + ","
                + LAT + "],[" + (LON + d) + "," + (LAT + d) + "],[" + LON + "," + (LAT + d) + "],[" + LON + "," + LAT
                + "]]]}");
        recurso("-dentro", "Disponible", 50);
        recurso("-fuera-del-radio", "Disponible", 4000);

        Map<String, Object> r = analizar(inc, 500, 10, false, false);

        List<Map<String, Object>> propios = propios(r);
        assertEquals(1, propios.size());
        assertEquals(0.0, ((Number) propios.get(0).get("distanciaDirectaM")).doubleValue(), 0.5);
    }

    @Test
    public void soloDisponiblesDescartaLosDemasEstados() throws Exception {
        int inc = incidente(PUNTO);
        recurso("-libre", "Disponible", 100);
        recurso("-ocupado", "En servicio", 120);

        assertEquals(1, propios(analizar(inc, 1000, 10, true, false)).size());
        assertEquals(2, propios(analizar(inc, 1000, 10, false, false)).size());
    }

    @Test
    public void conRutasCompletaDistanciaViaYDuracion() throws Exception {
        int inc = incidente(PUNTO);
        recurso("-cerca", "Disponible", 300);

        Map<String, Object> r = analizar(inc, 1000, 10, true, true);

        Map<String, Object> item = propios(r).get(0);
        assertEquals("disponible", item.get("estadoRuta"));
        assertEquals(1200L, item.get("distanciaViaM"));
        assertEquals(150L, item.get("duracionS"));
        assertEquals("mas_rapida", r.get("criterioRuta"));
        assertTrue(((Number) item.get("distanciaViaM")).doubleValue()
                >= ((Number) item.get("distanciaDirectaM")).doubleValue());
    }

    @Test
    public void incidenteInexistenteDevuelveNull() throws Exception {
        assertNull(analizar(Integer.MAX_VALUE, 1000, 5, true, false));
    }

    @Test
    public void incidenteExistenteSinRecursosDevuelveListaVacia() throws Exception {
        int inc = incidente("{\"type\":\"Point\",\"coordinates\":[-55.0,-33.0]}");

        Map<String, Object> r = analizar(inc, 500, 5, false, false);

        assertNotNull(r);
        assertEquals(0, items(r).size());
        assertEquals(0, r.get("totalEnRadio"));
    }
}
