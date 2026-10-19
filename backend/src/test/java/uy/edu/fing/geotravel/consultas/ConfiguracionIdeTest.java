package uy.edu.fing.geotravel.consultas;

import org.junit.Test;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class ConfiguracionIdeTest {

    @Test
    public void usaSaltoPorDefecto() {
        ConfiguracionIde configuracion = ConfiguracionIde.desde(Collections.emptyMap());

        assertEquals("salto", configuracion.getDepartamento());
        assertEquals("salto", configuracion.getLocalidad());
        assertFalse(configuracion.usaPuertasLocales());
    }

    @Test
    public void permiteConfigurarMontevideoYUsarPuertasLocales() {
        Map<String, String> entorno = new HashMap<>();
        entorno.put("IDE_DEPARTAMENTO", "montevideo");
        entorno.put("IDE_LOCALIDAD", "montevideo");

        ConfiguracionIde configuracion = ConfiguracionIde.desde(entorno);

        assertTrue(configuracion.usaPuertasLocales());
    }

    @Test
    public void codificaLaDireccionYUsaIdeParaSalto() {
        ConfiguracionIde configuracion = new ConfiguracionIde("salto norte", "Salto");

        assertEquals(
                "https://ide.test/geocode?calle=Avenida+18+de+Julio+1000"
                        + "&departamento=salto+norte&localidad=Salto",
                configuracion.urlBusqueda(
                        "https://ide.test/geocode",
                        " Avenida 18 de Julio 1000 "
                )
        );
        assertFalse(configuracion.usaPuertasLocales());
    }

    @Test
    public void noIntentaBuscarPuertasDeMontevideoParaSalto() {
        ConfiguracionIde salto = new ConfiguracionIde("salto", "salto");

        assertEquals(null, ConsultaResource.coincidenciaPuertaLocal("18 de Julio 1000", salto));
    }

    @Test
    public void habilitaPuertasLocalesSoloConConfiguracionMontevideo() {
        ConfiguracionIde montevideo = new ConfiguracionIde("montevideo", "montevideo");

        assertTrue(ConsultaResource.coincidenciaPuertaLocal("18 de Julio 1000", montevideo) != null);
    }
}
