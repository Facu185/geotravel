package uy.edu.fing.geotravel.auth;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/** El login básico: sesiones y rutas públicas (no necesita base de datos ni servidor). */
public class AuthTest {

    @Test
    public void unaSesionNuevaEsValidaYSeCierra() {
        String token = Sesiones.crear();
        assertTrue(Sesiones.valida(token));
        Sesiones.cerrar(token);
        assertFalse(Sesiones.valida(token));
    }

    @Test
    public void losTokensSonDistintosYLosInventadosNoValen() {
        assertNotEquals(Sesiones.crear(), Sesiones.crear());
        assertFalse(Sesiones.valida("inventado"));
        assertFalse(Sesiones.valida(null));
        assertFalse(Sesiones.valida(""));
    }

    @Test
    public void unaSesionVencidaNoVale() {
        String token = Sesiones.crear();
        Sesiones.vencerAhora(token);
        assertFalse(Sesiones.valida(token));
    }

    @Test
    public void extraeElTokenDelEncabezado() {
        assertEquals("abc", Sesiones.tokenDe("Bearer abc"));
        assertEquals("abc", Sesiones.tokenDe("bearer  abc "));
        assertNull(Sesiones.tokenDe("Basic abc"));
        assertNull(Sesiones.tokenDe(null));
    }

    @Test
    public void lasCredencialesPorDefectoSonLasDeDesarrollo() {
        // Sin ADMIN_USUARIO / ADMIN_CLAVE en el entorno de la prueba.
        if (System.getenv("ADMIN_USUARIO") == null && System.getenv("ADMIN_CLAVE") == null) {
            assertTrue(Sesiones.credencialesValidas("admin", "urbansafe"));
        }
        assertFalse(Sesiones.credencialesValidas("admin", "otra"));
        assertFalse(Sesiones.credencialesValidas(null, null));
    }

    @Test
    public void soloEsPublicoLoQueSeDeclara() {
        assertTrue(AuthFilter.esPublica("GET", "health"));
        assertTrue(AuthFilter.esPublica("POST", "/auth/login"));
        assertTrue(AuthFilter.esPublica("OPTIONS", "zonas"));
        assertTrue(AuthFilter.esPublica("GET", "consultas/tipos-incidente"));
        assertTrue(AuthFilter.esPublica("GET", "fotos/12"));

        // Las Consultas del invitado: solo lectura.
        assertTrue(AuthFilter.esPublica("GET", "consultas/buscar"));
        assertTrue(AuthFilter.esPublica("GET", "/consultas/recursos-cercanos/4/analisis-vial"));
        assertTrue(AuthFilter.esPublica("GET", "zonas"));
        assertTrue(AuthFilter.esPublica("GET", "incidentes/"));
        assertTrue(AuthFilter.esPublica("GET", "recursos"));
        assertTrue(AuthFilter.esPublica("GET", "eta/criterios"));

        assertFalse(AuthFilter.esPublica("GET", "consultas/reportes/incidentes-por-zona"));
        assertFalse(AuthFilter.esPublica("GET", "zonas/3"));
        assertFalse(AuthFilter.esPublica("GET", "eta/recursos/1/incidentes/2"));
        assertFalse(AuthFilter.esPublica("POST", "zonas"));
        assertFalse(AuthFilter.esPublica("POST", "incidentes"));
        assertFalse(AuthFilter.esPublica("DELETE", "incidentes/3"));
        assertFalse(AuthFilter.esPublica("POST", "consultas/tipos-incidente"));
        assertFalse(AuthFilter.esPublica("POST", "fotos/12"));
        assertFalse(AuthFilter.esPublica("GET", "auth/yo"));
    }
}
