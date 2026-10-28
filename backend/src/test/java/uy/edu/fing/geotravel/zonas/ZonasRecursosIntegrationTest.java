package uy.edu.fing.geotravel.zonas;

import org.junit.After;
import org.junit.Assume;
import org.junit.Before;
import org.junit.Test;
import uy.edu.fing.geotravel.db.DataSourceProvider;
import uy.edu.fing.geotravel.recursos.RecursoResource;

import javax.ws.rs.core.Response;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/**
 * Pruebas de integración de Zonas y Recursos (P3) contra un PostGIS local con el esquema y el seed aplicados.
 * Se ejecutan con URBANSAFE_INTEGRATION_TESTS=true (y DB_HOST, DB_PORT, etc. si la base no es la de por defecto);
 * sin eso se omiten. Cada prueba borra lo que creó.
 */
public class ZonasRecursosIntegrationTest {

    private static final String BBOX_SALTO = "-58.06,-31.46,-57.86,-31.32";
    /** Un cuadrado chico en Salto, con una esquina del lado del río, donde el seed no tiene zonas. */
    private static final String CUADRADO = "{\"type\":\"Polygon\",\"coordinates\":[[[-58.0500,-31.4400],[-58.0480,-31.4400],"
            + "[-58.0480,-31.4380],[-58.0500,-31.4380],[-58.0500,-31.4400]]]}";
    private static final String CORBATA = "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[2,2],[2,0],[0,2],[0,0]]]}"; // se cruza a sí mismo

    private final ZonaResource zonas = new ZonaResource();
    private final RecursoResource recursos = new RecursoResource();
    private final List<Integer> zonasCreadas = new ArrayList<>();
    private final List<Integer> recursosCreados = new ArrayList<>();

    @Before
    public void soloConPostgis() {
        Assume.assumeTrue("Definí URBANSAFE_INTEGRATION_TESTS=true para correr contra PostGIS",
                "true".equalsIgnoreCase(System.getenv("URBANSAFE_INTEGRATION_TESTS")));
    }

    @After
    public void borrarLoCreado() throws Exception {
        if (zonasCreadas.isEmpty() && recursosCreados.isEmpty()) return; // sin base (prueba omitida) no hay nada que borrar
        try (Connection conn = DataSourceProvider.get().getConnection()) {
            borrar(conn, "zona_operativa", zonasCreadas);
            borrar(conn, "recurso", recursosCreados);
        }
    }

    private static void borrar(Connection conn, String tabla, List<Integer> ids) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement("DELETE FROM " + tabla + " WHERE id = ?")) {
            for (Integer id : ids) {
                ps.setInt(1, id);
                ps.addBatch();
            }
            ps.executeBatch();
        }
    }

    private ZonaResource.ZonaInput zona(String geojson) {
        ZonaResource.ZonaInput in = new ZonaResource.ZonaInput();
        in.nombre = "IT-ZONA-" + UUID.randomUUID();
        in.nivelPrioridad = 2;
        in.geomGeoJson = geojson;
        return in;
    }

    private RecursoResource.RecursoInput recurso(String tipo, String estado, String punto) {
        RecursoResource.RecursoInput in = new RecursoResource.RecursoInput();
        in.identificacion = "IT-REC-" + UUID.randomUUID().toString().substring(0, 8);
        in.tipo = tipo;
        in.estadoOperativo = estado;
        in.geomGeoJson = punto;
        return in;
    }

    private int idDe(Response r) {
        assertEquals(201, r.getStatus());
        int id = (Integer) ((Map<?, ?>) r.getEntity()).get("id");
        return id;
    }

    @Test
    public void lasZonasPuedenSuperponerse() throws Exception {
        int primera = idDe(zonas.crear(zona(CUADRADO)));
        zonasCreadas.add(primera);
        // exactamente la misma forma: antes daba 409; ahora el tutor la permite
        int segunda = idDe(zonas.crear(zona(CUADRADO)));
        zonasCreadas.add(segunda);
        assertTrue(primera != segunda);
    }

    @Test
    public void unaZonaConPoligonoInvalidoSeRechaza() throws Exception {
        assertEquals(400, zonas.crear(zona(CORBATA)).getStatus());
        assertEquals(400, zonas.crear(zona("{\"type\":\"Point\",\"coordinates\":[-57.9,-31.3]}")).getStatus());
        assertEquals(400, zonas.crear(zona("esto no es geojson")).getStatus());
    }

    @Test
    public void laPrioridadDeUnaZonaVaDe1A5() throws Exception {
        ZonaResource.ZonaInput in = zona(CUADRADO);
        in.nivelPrioridad = 6;
        assertEquals(400, zonas.crear(in).getStatus());
        in.nivelPrioridad = 0;
        assertEquals(400, zonas.crear(in).getStatus());
    }

    @Test
    @SuppressWarnings("unchecked")
    public void unaZonaCreadaApareceEnElListadoPorRectangulo() throws Exception {
        int id = idDe(zonas.crear(zona(CUADRADO)));
        zonasCreadas.add(id);

        Map<String, Object> r = (Map<String, Object>) zonas.listar(BBOX_SALTO, 2000).getEntity();
        List<Map<String, Object>> items = (List<Map<String, Object>>) r.get("items");
        assertTrue(items.stream().anyMatch(z -> Integer.valueOf(id).equals(z.get("id"))));

        // un rectángulo lejos (Montevideo) no la incluye
        Map<String, Object> lejos = (Map<String, Object>) zonas.listar("-56.30,-34.95,-56.10,-34.85", 2000).getEntity();
        assertTrue(((List<Map<String, Object>>) lejos.get("items")).stream().noneMatch(z -> Integer.valueOf(id).equals(z.get("id"))));
    }

    @Test
    public void elTipoDeRecursoEsUnaListaCerrada() throws Exception {
        String punto = "{\"type\":\"Point\",\"coordinates\":[-57.96,-31.38]}";
        assertEquals(400, recursos.crear(recurso("helicoptero", "Disponible", punto)).getStatus());
        assertEquals(400, recursos.crear(recurso("", "Disponible", punto)).getStatus());
        assertEquals(400, recursos.crear(recurso("ambulancia", "Volando", punto)).getStatus());
        assertEquals(400, recursos.crear(recurso("ambulancia", "Disponible", "{\"type\":\"Polygon\",\"coordinates\":[]}")).getStatus());

        // se guarda en minúsculas y sin espacios: "Ambulancia " pasa a "ambulancia"
        int id = idDe(recursos.crear(recurso(" Ambulancia ", "Disponible", punto)));
        recursosCreados.add(id);
    }

    @Test
    @SuppressWarnings("unchecked")
    public void unRecursoCreadoApareceEnElListadoPorRectangulo() throws Exception {
        int id = idDe(recursos.crear(recurso("bomberos", "En servicio", "{\"type\":\"Point\",\"coordinates\":[-57.9610,-31.3860]}")));
        recursosCreados.add(id);

        Map<String, Object> r = (Map<String, Object>) recursos.listar(BBOX_SALTO, 2000).getEntity();
        List<Map<String, Object>> items = (List<Map<String, Object>>) r.get("items");
        assertTrue(items.stream().anyMatch(x -> Integer.valueOf(id).equals(x.get("id")) && "bomberos".equals(x.get("tipo"))));
    }
}
