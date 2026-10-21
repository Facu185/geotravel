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
        assertTrue(configuracion.usaPuertasLocales());
    }

    @Test
    public void conMontevideoUsaLaIdeEnVezDeLasPuertasLocales() {
        Map<String, String> entorno = new HashMap<>();
        entorno.put("IDE_DEPARTAMENTO", "montevideo");
        entorno.put("IDE_LOCALIDAD", "montevideo");

        ConfiguracionIde configuracion = ConfiguracionIde.desde(entorno);

        assertFalse(configuracion.usaPuertasLocales());
    }

    @Test
    public void codificaLaDireccionParaLaIde() {
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
    public void noIntentaBuscarPuertasDeSaltoParaMontevideo() {
        ConfiguracionIde montevideo = new ConfiguracionIde("montevideo", "montevideo");

        assertEquals(null, ConsultaResource.coincidenciaPuertaLocal("18 de Julio 1000", montevideo));
    }

    @Test
    public void habilitaPuertasLocalesSoloConConfiguracionSalto() {
        ConfiguracionIde salto = new ConfiguracionIde("salto", "salto");

        assertTrue(ConsultaResource.coincidenciaPuertaLocal("Uruguay 1000", salto) != null);
    }

    @Test
    public void escribeLasPalabrasCompletasComoEnLaBase() {
        ConfiguracionIde salto = new ConfiguracionIde("salto", "salto");

        assertEquals("GENERAL FRUCTUOSO RIVERA", ConsultaResource.coincidenciaPuertaLocal("Gral. Fructuoso Rivera 500", salto).group(1));
        assertEquals("AVENIDA URUGUAY", ConsultaResource.coincidenciaPuertaLocal("Av Uruguay 1000", salto).group(1));
        assertEquals("19 DE ABRIL", ConsultaResource.coincidenciaPuertaLocal("19 de Abril 300", salto).group(1));
    }
}
