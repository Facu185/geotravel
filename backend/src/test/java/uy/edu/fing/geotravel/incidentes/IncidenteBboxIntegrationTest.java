package uy.edu.fing.geotravel.incidentes;

import org.junit.After;
import org.junit.Assume;
import org.junit.Before;
import org.junit.Test;
import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.core.Response;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

/** Integration tests against a local PostGIS database; opt in with URBANSAFE_INTEGRATION_TESTS=true. */
public class IncidenteBboxIntegrationTest {

    private static final String BBOX_SALTO = "-57.995,-31.405,-57.925,-31.365";
    private static final ObjectMapper JSON = new ObjectMapper();

    private final List<Integer> fixtureIds = new ArrayList<>();
    private IncidenteResource resource;
    private String prefijo;
    private int totalInicial;

    @Before
    public void prepararPostgis() throws Exception {
        Assume.assumeTrue("Set URBANSAFE_INTEGRATION_TESTS=true to run against local PostGIS",
                "true".equalsIgnoreCase(System.getenv("URBANSAFE_INTEGRATION_TESTS")));

        resource = new IncidenteResource();
        prefijo = "IT-BBOX-" + UUID.randomUUID();
        totalInicial = totalEnBbox();

        insertar("PUNTO", "{\"type\":\"Point\",\"coordinates\":[-57.96215,-31.39029]}");
        insertar("LINEA", "{\"type\":\"LineString\",\"coordinates\":[[-57.966,-31.392],[-57.958,-31.392]]}");
        insertar("POLIGONO", "{\"type\":\"Polygon\",\"coordinates\":[[[-57.970,-31.395],[-57.968,-31.395],[-57.968,-31.393],[-57.970,-31.393],[-57.970,-31.395]]]}" );
    }

    @After
    public void borrarSoloFixturesPropios() throws Exception {
        if (fixtureIds.isEmpty()) return;

        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM incidente WHERE id = ?")) {
            for (Integer id : fixtureIds) {
                ps.setInt(1, id);
                ps.addBatch();
            }
            ps.executeBatch();
        }
    }

    @Test
    public void bboxSaltoDevuelvePaginacionYGeometriasGenericas() throws Exception {
        Map<String, Object> respuesta = listar(BBOX_SALTO, "500");
        List<Map<String, Object>> items = items(respuesta);

        assertEquals(totalInicial + 3, respuesta.get("total"));
        assertEquals(false, respuesta.get("truncado"));
        assertEquals(totalInicial + 3, items.size());

        Set<String> tiposFixture = new HashSet<>();
        for (Map<String, Object> item : items) {
            if (!fixtureIds.contains(item.get("id"))) continue;
            JsonNode geometria = JSON.readTree((String) item.get("geom"));
            tiposFixture.add(geometria.path("type").asText());
        }
        assertEquals(new HashSet<>(Arrays.asList("Point", "LineString", "Polygon")), tiposFixture);
    }

    @Test
    public void limitSeAplicaAntesDelTotal() throws Exception {
        Map<String, Object> respuesta = listar(BBOX_SALTO, "1");

        assertEquals(1, items(respuesta).size());
        assertEquals(totalInicial + 3, respuesta.get("total"));
        assertEquals(true, respuesta.get("truncado"));
    }

    @Test
    public void limitOmitidoYMaximoAceptanElEscenario() throws Exception {
        Map<String, Object> sinLimite = listar(BBOX_SALTO, null);
        Map<String, Object> sobreMaximo = listar(BBOX_SALTO, "2500");

        assertEquals(totalInicial + 3, sinLimite.get("total"));
        assertEquals(totalInicial + 3, items(sinLimite).size());
        assertEquals(false, sinLimite.get("truncado"));
        assertEquals(totalInicial + 3, sobreMaximo.get("total"));
        assertEquals(totalInicial + 3, items(sobreMaximo).size());
    }

    @Test
    public void bboxSinCoincidenciasDevuelveResultadoVacio() throws Exception {
        Map<String, Object> respuesta = listar("10,40,11,41", "500");

        assertTrue(items(respuesta).isEmpty());
        assertEquals(0, respuesta.get("total"));
        assertEquals(false, respuesta.get("truncado"));
    }

    @Test
    public void conservaArregloTradicionalSinBbox() throws Exception {
        Response response = resource.listar(null, null);

        assertEquals(200, response.getStatus());
        assertTrue(response.getEntity() instanceof List);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> todos = (List<Map<String, Object>>) response.getEntity();
        Map<String, Object> fixture = todos.stream()
                .filter(row -> fixtureIds.contains(row.get("id")))
                .findFirst()
                .orElse(null);

        assertNotNull(fixture);
        assertTrue(fixture.get("titulo") instanceof String);
        assertTrue(fixture.get("fechaHoraRegistro") instanceof String);
        assertTrue(fixture.get("geom") instanceof String);
    }

    @Test
    public void parametrosInvalidosDevuelven400() throws Exception {
        assertEquals(400, resource.listar("no-es-un-bbox", "500").getStatus());
        assertEquals(400, resource.listar(BBOX_SALTO, "0").getStatus());
        assertEquals(400, resource.listar(BBOX_SALTO, "abc").getStatus());
    }

    private int totalEnBbox() throws Exception {
        Map<String, Object> respuesta = listar(BBOX_SALTO, "500");
        return (Integer) respuesta.get("total");
    }

    private Map<String, Object> listar(String bbox, String limit) throws Exception {
        Response response = resource.listar(bbox, limit);
        assertEquals(200, response.getStatus());
        assertTrue(response.getEntity() instanceof Map);
        @SuppressWarnings("unchecked")
        Map<String, Object> respuesta = (Map<String, Object>) response.getEntity();
        assertTrue(respuesta.containsKey("items"));
        assertTrue(respuesta.containsKey("total"));
        assertTrue(respuesta.containsKey("truncado"));
        return respuesta;
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> items(Map<String, Object> respuesta) {
        return (List<Map<String, Object>>) respuesta.get("items");
    }

    private void insertar(String tipo, String geoJson) throws Exception {
        String sql = "INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, geom) "
                + "VALUES (?, 'fixture temporal integración', 'accidente_transito', 3, "
                + "ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)) RETURNING id";
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, prefijo + "-" + tipo);
            ps.setString(2, geoJson);
            try (ResultSet rs = ps.executeQuery()) {
                assertTrue(rs.next());
                fixtureIds.add(rs.getInt(1));
            }
        }
    }
}
