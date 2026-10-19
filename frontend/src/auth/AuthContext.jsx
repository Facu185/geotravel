import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { api } from "../api/client.js";
import { borrarToken, EVENTO_VENCIDA, guardarToken, obtenerToken } from "./sesion.js";

/**
 * Sesión del administrador para toda la aplicación.
 *
 *   const { sesion, esAdmin, cargando, ingresar, salir } = useAuth();
 *
 * El invitado no inicia sesión: entra directo al mapa público. Las pantallas de administración
 * (zonas, recursos, incidentes, consultas) piden ser administrador (ver RutaAdmin) y la API las
 * protege también del lado del backend (ver AuthFilter).
 */
const Contexto = createContext(null);

export function AuthProvider({ children }) {
  const [sesion, setSesion] = useState(null); // { usuario, rol } o null
  // Si había un token guardado, se comprueba con el backend antes de decidir (evita un parpadeo al recargar).
  const [cargando, setCargando] = useState(() => Boolean(obtenerToken()));

  useEffect(() => {
    if (!obtenerToken()) return undefined;
    let vigente = true;
    api
      .get("/auth/yo")
      .then((d) => vigente && setSesion({ usuario: d.usuario, rol: d.rol }))
      .catch(() => {
        borrarToken();
      })
      .finally(() => vigente && setCargando(false));
    return () => {
      vigente = false;
    };
  }, []);

  // Si el backend rechaza el token en cualquier pedido, se cierra la sesión acá.
  useEffect(() => {
    const alVencer = () => setSesion(null);
    window.addEventListener(EVENTO_VENCIDA, alVencer);
    return () => window.removeEventListener(EVENTO_VENCIDA, alVencer);
  }, []);

  const ingresar = useCallback(async (usuario, clave) => {
    const r = await api.post("/auth/login", { usuario, clave });
    guardarToken(r.token);
    setSesion({ usuario: r.usuario, rol: r.rol });
  }, []);

  const salir = useCallback(async () => {
    try {
      await api.post("/auth/logout");
    } catch {
      // si el backend no responde, igual se cierra la sesión acá
    }
    borrarToken();
    setSesion(null);
  }, []);

  const valor = useMemo(() => ({ sesion, esAdmin: sesion?.rol === "admin", cargando, ingresar, salir }), [sesion, cargando, ingresar, salir]);
  return <Contexto.Provider value={valor}>{children}</Contexto.Provider>;
}

export function useAuth() {
  const valor = useContext(Contexto);
  if (!valor) throw new Error("useAuth se usa dentro de <AuthProvider>");
  return valor;
}
