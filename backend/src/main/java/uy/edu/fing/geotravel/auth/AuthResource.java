package uy.edu.fing.geotravel.auth;

import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.HeaderParam;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Login básico del administrador (ver Sesiones).
 *
 *   POST /auth/login   {usuario, clave}  ->  {token, usuario, rol, venceEnHoras}  (401 si no coinciden)
 *   POST /auth/logout                    ->  204, cierra la sesión del token que se manda
 *   GET  /auth/yo                        ->  {usuario, rol} si el token sigue vigente (401 si no)
 */
@Path("/auth")
@Produces(MediaType.APPLICATION_JSON)
public class AuthResource {

    public static class LoginInput {
        public String usuario;
        public String clave;
    }

    @POST
    @Path("/login")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response login(LoginInput in) throws InterruptedException {
        if (in == null || !Sesiones.credencialesValidas(in.usuario, in.clave)) {
            Thread.sleep(400); // frena los intentos de adivinar la clave
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(Map.of("error", "Usuario o contraseña incorrectos")).build();
        }
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("token", Sesiones.crear());
        cuerpo.put("usuario", Sesiones.usuarioAdmin());
        cuerpo.put("rol", "admin");
        cuerpo.put("venceEnHoras", Sesiones.DURACION.toHours());
        return Response.ok(cuerpo).build();
    }

    @POST
    @Path("/logout")
    public Response logout(@HeaderParam("Authorization") String autorizacion) {
        Sesiones.cerrar(Sesiones.tokenDe(autorizacion));
        return Response.noContent().build();
    }

    /** Llega acá solo con un token vigente (AuthFilter): sirve para que el frontend compruebe su sesión. */
    @GET
    @Path("/yo")
    public Map<String, Object> yo() {
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("usuario", Sesiones.usuarioAdmin());
        cuerpo.put("rol", "admin");
        return cuerpo;
    }
}
