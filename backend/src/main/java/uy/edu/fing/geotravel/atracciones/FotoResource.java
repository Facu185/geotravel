package uy.edu.fing.geotravel.atracciones;

import org.glassfish.jersey.media.multipart.FormDataParam;

import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.UriInfo;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Fotos de las atracciones (dueño: P3, opcional "Fotos").
 *
 * POST /api/fotos        (multipart, campo "archivo") -> 201 {"url": "http://.../api/fotos/<uuid>.jpg"}
 * GET  /api/fotos/{name} -> la imagen
 *
 * El flujo es de dos pasos: primero se sube el archivo y se obtiene una URL; después esa URL se
 * guarda en el campo fotoUrl de la atracción (POST/PUT /api/atracciones). Se hace así porque al
 * CREAR una atracción todavía no existe su id.
 *
 * Seguridad:
 *  - El tipo se decide por el CONTENIDO del archivo (bytes iniciales), nunca por el nombre ni por
 *    el Content-Type que declara el cliente, que se pueden falsificar.
 *  - El nombre en disco lo genera el servidor (UUID): el cliente no elige rutas (sin path traversal).
 *  - Tamaño máximo de 5 MB.
 *
 * Dónde se guardan: variable de entorno FOTOS_DIR (en docker-compose apunta a un volumen, para que
 * sobrevivan a los redespliegues del .war). Si no está definida, una carpeta temporal.
 */
@Path("/fotos")
public class FotoResource {

    private static final long MAX_BYTES = 5L * 1024 * 1024;

    private static final Pattern NOMBRE_VALIDO = Pattern.compile(
            "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.(jpg|png|gif|webp)$");

    @POST
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    @Produces(MediaType.APPLICATION_JSON)
    public Response subir(@FormDataParam("archivo") InputStream contenido, @Context UriInfo uriInfo)
            throws IOException {
        if (contenido == null) {
            return error(400, "Falta el archivo (campo \"archivo\")");
        }
        byte[] datos = leerConLimite(contenido, MAX_BYTES);
        if (datos == null) {
            return error(413, "La imagen supera el máximo de 5 MB");
        }
        String extension = extensionSegunContenido(datos);
        if (extension == null) {
            return error(400, "El archivo no es una imagen JPG, PNG, GIF o WEBP");
        }

        String nombre = UUID.randomUUID() + "." + extension;
        Files.write(directorio().resolve(nombre), datos);

        String url = uriInfo.getBaseUriBuilder().path("fotos").path(nombre).build().toString();
        return Response.status(Response.Status.CREATED).entity(Map.of("url", url)).build();
    }

    @GET
    @Path("/{nombre}")
    public Response ver(@PathParam("nombre") String nombre) throws IOException {
        // Solo nombres con el formato exacto que genera subir(): imposible pedir "../algo".
        if (!NOMBRE_VALIDO.matcher(nombre).matches()) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        java.nio.file.Path archivo = directorio().resolve(nombre);
        if (!Files.isRegularFile(archivo)) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(archivo.toFile(), tipoMime(nombre))
                .header("Cache-Control", "public, max-age=86400")
                .header("X-Content-Type-Options", "nosniff")
                .build();
    }

    // ------------------------------------------------------------------ utilidades

    private static java.nio.file.Path directorio() throws IOException {
        String configurado = System.getenv("FOTOS_DIR");
        java.nio.file.Path dir = (configurado == null || configurado.isEmpty())
                ? Paths.get(System.getProperty("java.io.tmpdir"), "geotravel-fotos")
                : Paths.get(configurado);
        return Files.createDirectories(dir);
    }

    /** Lee todo el stream, o devuelve null apenas supera el límite (sin cargar archivos enormes en memoria). */
    private static byte[] leerConLimite(InputStream in, long maximo) throws IOException {
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        long total = 0;
        int leidos;
        while ((leidos = in.read(buffer)) != -1) {
            total += leidos;
            if (total > maximo) {
                return null;
            }
            salida.write(buffer, 0, leidos);
        }
        return salida.toByteArray();
    }

    /** Identifica el formato por sus bytes iniciales ("firma"). null si no es una imagen soportada. */
    private static String extensionSegunContenido(byte[] b) {
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) {
            return "jpg";
        }
        if (b.length >= 8 && (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G'
                && b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
            return "png";
        }
        if (b.length >= 6 && b[0] == 'G' && b[1] == 'I' && b[2] == 'F' && b[3] == '8'
                && (b[4] == '7' || b[4] == '9') && b[5] == 'a') {
            return "gif";
        }
        if (b.length >= 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F'
                && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') {
            return "webp";
        }
        return null;
    }

    private static String tipoMime(String nombre) {
        if (nombre.endsWith(".png")) return "image/png";
        if (nombre.endsWith(".gif")) return "image/gif";
        if (nombre.endsWith(".webp")) return "image/webp";
        return "image/jpeg";
    }

    private static Response error(int status, String mensaje) {
        return Response.status(status).type(MediaType.APPLICATION_JSON).entity(Map.of("error", mensaje)).build();
    }
}
