package uy.edu.fing.geotravel.config;

import javax.ws.rs.container.ContainerRequestContext;
import javax.ws.rs.container.ContainerResponseContext;
import javax.ws.rs.container.ContainerResponseFilter;
import javax.ws.rs.ext.Provider;
import java.io.IOException;

/**
 * Permite que el frontend (Vite en :5173) llame a esta API (Tomcat en :8080).
 * Jersey lo registra solo por estar bajo el paquete escaneado en web.xml.
 * "*" es aceptable para desarrollo; si se despliega en un servidor real,
 * restringirlo al origen del frontend.
 */
@Provider
public class CorsFilter implements ContainerResponseFilter {

    @Override
    public void filter(ContainerRequestContext request, ContainerResponseContext response) throws IOException {
        response.getHeaders().putSingle("Access-Control-Allow-Origin", "*");
        response.getHeaders().putSingle("Access-Control-Allow-Headers", "origin, content-type, accept, authorization");
        response.getHeaders().putSingle("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    }
}
