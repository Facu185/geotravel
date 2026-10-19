package uy.edu.fing.geotravel.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Sesiones del administrador. Hay un único usuario de prueba, configurado con las variables de
 * entorno ADMIN_USUARIO y ADMIN_CLAVE (por defecto admin / urbansafe: cambiarlas fuera de desarrollo).
 *
 * Al ingresar se genera un token aleatorio que el frontend manda en "Authorization: Bearer ...".
 * Las sesiones viven en memoria y vencen a las 8 horas: si se reinicia el backend hay que volver
 * a ingresar. Es un login básico para separar las vistas, no un sistema de usuarios.
 */
public final class Sesiones {

    static final Duration DURACION = Duration.ofHours(8);
    private static final SecureRandom ALEATORIO = new SecureRandom();
    private static final Map<String, Instant> ACTIVAS = new ConcurrentHashMap<>();

    private Sesiones() {
    }

    private static String variable(String nombre, String porDefecto) {
        String valor = System.getenv(nombre);
        return valor == null || valor.isEmpty() ? porDefecto : valor;
    }

    public static String usuarioAdmin() {
        return variable("ADMIN_USUARIO", "admin");
    }

    /** Compara sin que el tiempo de respuesta delate cuántos caracteres coinciden. */
    static boolean iguales(String a, String b) {
        if (a == null || b == null) {
            return false;
        }
        try {
            MessageDigest sha = MessageDigest.getInstance("SHA-256");
            return MessageDigest.isEqual(sha.digest(a.getBytes(StandardCharsets.UTF_8)), sha.digest(b.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    public static boolean credencialesValidas(String usuario, String clave) {
        boolean usuarioOk = iguales(usuario, usuarioAdmin());
        boolean claveOk = iguales(clave, variable("ADMIN_CLAVE", "urbansafe"));
        return usuarioOk && claveOk;
    }

    /** Abre una sesión y devuelve su token. */
    public static String crear() {
        Instant ahora = Instant.now();
        ACTIVAS.values().removeIf(vence -> vence.isBefore(ahora)); // limpia las vencidas
        byte[] bytes = new byte[32];
        ALEATORIO.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        ACTIVAS.put(token, ahora.plus(DURACION));
        return token;
    }

    /** Extrae el token de un encabezado "Bearer xxx"; null si no hay. */
    public static String tokenDe(String encabezado) {
        if (encabezado == null) {
            return null;
        }
        String texto = encabezado.trim();
        return texto.regionMatches(true, 0, "Bearer ", 0, 7) ? texto.substring(7).trim() : null;
    }

    public static boolean valida(String token) {
        if (token == null || token.isEmpty()) {
            return false;
        }
        Instant vence = ACTIVAS.get(token);
        if (vence == null) {
            return false;
        }
        if (vence.isBefore(Instant.now())) {
            ACTIVAS.remove(token);
            return false;
        }
        return true;
    }

    public static void cerrar(String token) {
        if (token != null) {
            ACTIVAS.remove(token);
        }
    }

    /** Solo para pruebas: deja la sesión por vencer o ya vencida. */
    static void vencerAhora(String token) {
        ACTIVAS.put(token, Instant.now().minusSeconds(1));
    }
}
