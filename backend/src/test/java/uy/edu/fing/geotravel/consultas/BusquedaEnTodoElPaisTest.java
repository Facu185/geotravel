package uy.edu.fing.geotravel.consultas;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/** La búsqueda de direcciones en todo el país: el pedido a la IDE y la elección de la mejor coincidencia. */
public class BusquedaEnTodoElPaisTest {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String ENDPOINT = "https://direcciones.ide.uy/api/v0/geocode/BusquedaDireccion";

    private static JsonNode candidato(String departamento, String localidad, int puerta, boolean exacto) throws Exception {
        return JSON.readTree("{\"direccion\":{\"departamento\":{\"nombre_normalizado\":\"" + departamento + "\"},"
                + "\"localidad\":{\"nombre_normalizado\":\"" + localidad + "\"},"
                + "\"calle\":{\"nombre_normalizado\":\"MINAS\"},\"numero\":{\"nro_puerta\":" + puerta + "}},"
                + "\"puntoX\":-56.1,\"puntoY\":-34.9,\"error\":\"" + (exacto ? "" : "PUNTO NO ENCONTRADO") + "\"}");
    }

    private static JsonNode lista(JsonNode... candidatos) {
        return JSON.createArrayNode().addAll(java.util.Arrays.asList(candidatos));
    }

    @Test
    public void sinDepartamentoNiLocalidadElPedidoBuscaEnTodoElPais() {
        String url = ConfiguracionIde.urlBusqueda(ENDPOINT, " Minas 2091 ", null, null, null);
        assertEquals(ENDPOINT + "?calle=Minas+2091", url);
        assertFalse(url.contains("departamento"));
    }

    @Test
    public void soloConDepartamentoBuscaEnTodoElDepartamento() {
        String url = ConfiguracionIde.urlBusqueda(ENDPOINT, "Minas 2091", null, "lavalleja", null);
        assertTrue(url.contains("departamento=lavalleja"));
        assertFalse(url.contains("localidad"));
    }

    @Test
    public void conDepartamentoLocalidadYEsquinaVanLosTres() {
        String url = ConfiguracionIde.urlBusqueda(ENDPOINT, "Uruguay", "Yatay", "salto", "salto");
        assertTrue(url.contains("esquina=Yatay") && url.contains("departamento=salto") && url.contains("localidad=salto"));
    }

    @Test
    public void ganaElPortalExactoAunqueNoSeaElPrimero() throws Exception {
        JsonNode exacta = candidato("montevideo", "montevideo", 2091, true);
        JsonNode lista = lista(candidato("rio negro", "young", 2054, false), candidato("salto", "belen", 5, false), exacta);

        assertEquals(exacta, ConsultaResource.elegirMejor(lista, "salto"));
    }

    @Test
    public void entreDosExactosGanaElDelDepartamentoPreferido() throws Exception {
        JsonNode enSalto = candidato("salto", "salto", 100, true);
        JsonNode lista = lista(candidato("montevideo", "montevideo", 100, true), enSalto);

        assertEquals(enSalto, ConsultaResource.elegirMejor(lista, "salto"));
    }

    @Test
    public void sinExactosGanaLaDelDepartamentoPreferidoYSiNoLaPrimera() throws Exception {
        JsonNode primera = candidato("rio negro", "young", 2054, false);
        JsonNode deSalto = candidato("salto", "belen", 5, false);

        assertEquals(deSalto, ConsultaResource.elegirMejor(lista(primera, deSalto), "salto"));
        assertEquals(primera, ConsultaResource.elegirMejor(lista(primera, deSalto), "artigas"));
    }
}
