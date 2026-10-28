package uy.edu.fing.geotravel.auth;

import javax.annotation.Priority;
import javax.ws.rs.Priorities;
import javax.ws.rs.container.ContainerRequestContext;
import javax.ws.rs.container.ContainerRequestFilter;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import javax.ws.rs.ext.Provider;
import java.io.IOException;
import java.util.Map;

/**
 * Protege la API: todo exige una sesión de administrador, salvo una lista corta de rutas públicas.
 * Es "denegar por defecto": una ruta nueva queda protegida sin tocar este archivo.
 *
 * Públicas:
 *   - OPTIONS (el navegador lo manda antes de cada pedido entre orígenes distintos, sin token),
 *   - /health y /auth/login y /auth/logout,
 *   - GET /consultas/tipos-incidente (lo usa el filtro del mapa público),
 *   - las Consultas geográficas que ve el invitado, todas de solo lectura: GET /consultas/... (menos el reporte,
 *     que es del administrador), el listado de zonas, incidentes y recursos de la vista (GET /zonas, /incidentes
 *     y /recursos, sin id) con el que se elige qué consultar, y GET /eta/criterios (qué criterios de ruta hay),
 *   - GET /fotos/... (las imágenes no pueden mandar encabezados).
 * El mapa público dibuja con GeoServer, que no pasa por esta API.
 *
 * Jersey lo registra solo por estar bajo el paquete escaneado en web.xml, como CorsFilter.
 */
@Provider
@Priority(Priorities.AUTHENTICATION)
public class AuthFilter implements ContainerRequestFilter {

    @Override
    public void filter(ContainerRequestContext pedido) throws IOException {
        if (esPublica(pedido.getMethod(), pedido.getUriInfo().getPath())) {
            return;
        }
        if (!Sesiones.valida(Sesiones.tokenDe(pedido.getHeaderString("Authorization")))) {
            pedido.abortWith(Response.status(Response.Status.UNAUTHORIZED)
                    .type(MediaType.APPLICATION_JSON)
                    .entity(Map.of("error", "Necesitás iniciar sesión como administrador"))
                    .build());
        }
    }

    /** @param ruta la ruta relativa a /api, con o sin "/" al comienzo (por ejemplo "zonas/3") */
    static boolean esPublica(String metodo, String ruta) {
        if ("OPTIONS".equals(metodo)) {
            return true;
        }
        String r = ruta == null ? "" : ruta.replaceAll("^/+", "").replaceAll("/+$", "");
        if (r.equals("health") || r.equals("auth/login") || r.equals("auth/logout")) {
            return true;
        }
        if ("GET".equals(metodo)) {
            return r.equals("fotos") || r.startsWith("fotos/")
                    || (r.startsWith("consultas/") && !r.startsWith("consultas/reportes"))
                    || r.equals("zonas") || r.equals("incidentes") || r.equals("recursos")
                    || r.equals("eta/criterios");
        }
        return false;
    }
}
