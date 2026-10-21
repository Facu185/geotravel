package uy.edu.fing.geotravel.consultas;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/** Configuración del servicio IDE, independiente de la región del frontend. */
public final class ConfiguracionIde {

    public static final String DEPARTAMENTO_POR_DEFECTO = "salto";
    public static final String LOCALIDAD_POR_DEFECTO = "salto";

    private final String departamento;
    private final String localidad;

    public ConfiguracionIde(String departamento, String localidad) {
        this.departamento = valorOReemplazo(departamento, DEPARTAMENTO_POR_DEFECTO);
        this.localidad = valorOReemplazo(localidad, LOCALIDAD_POR_DEFECTO);
    }

    public static ConfiguracionIde desdeEntorno() {
        return desde(System.getenv());
    }

    public static ConfiguracionIde desde(Map<String, String> entorno) {
        return new ConfiguracionIde(
                entorno.get("IDE_DEPARTAMENTO"),
                entorno.get("IDE_LOCALIDAD")
        );
    }

    /** Las tablas propias de calles (via) y puertas (acceso) son de Salto: solo ahí se usan en vez de la IDE. */
    public boolean usaPuertasLocales() {
        return "salto".equalsIgnoreCase(departamento)
                && "salto".equalsIgnoreCase(localidad);
    }

    public String getDepartamento() {
        return departamento;
    }

    public String getLocalidad() {
        return localidad;
    }

    public String urlBusqueda(String endpoint, String direccion) {
        return urlBusqueda(endpoint, direccion, null);
    }

    /** Con esquina (segunda calle) el servicio ubica el cruce de las dos calles. */
    public String urlBusqueda(String endpoint, String direccion, String esquina) {
        return endpoint
                + "?calle=" + codificar(direccion.trim())
                + (esquina != null ? "&esquina=" + codificar(esquina) : "")
                + "&departamento=" + codificar(departamento)
                + "&localidad=" + codificar(localidad);
    }

    private static String valorOReemplazo(String valor, String reemplazo) {
        return valor == null || valor.trim().isEmpty() ? reemplazo : valor.trim();
    }

    private static String codificar(String valor) {
        return URLEncoder.encode(valor, StandardCharsets.UTF_8);
    }
}
