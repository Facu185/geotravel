import { useCallback, useEffect, useState } from "react";
import { api } from "./client.js";

const REFRESCO_MS = 15000;

/**
 * Si se pueden calcular rutas por calles: pgRouting, la red vial y la función de rutas tienen que estar en la base
 * (GET /eta/disponible). Se consulta al montar, cada 15 s y al volver a la pestaña; el servidor cachea la salud 5 s.
 *
 * Devuelve `aviso`: el texto para mostrar cuando NO se pueden calcular rutas, o null si se puede (o todavía no se sabe).
 */
export default function useRutasDisponibles() {
  const [estado, setEstado] = useState(null);

  const refrescar = useCallback(() => {
    return api
      .get("/eta/disponible")
      .then(setEstado)
      .catch(() => setEstado({ disponible: false, motivo: "no se pudo consultar al servidor" }));
  }, []);

  useEffect(() => {
    refrescar();
    const visible = () => document.visibilityState === "visible";
    const id = setInterval(() => visible() && refrescar(), REFRESCO_MS);
    const alVolver = () => visible() && refrescar();
    document.addEventListener("visibilitychange", alVolver);
    return () => {
      clearInterval(id);
      document.removeEventListener("visibilitychange", alVolver);
    };
  }, [refrescar]);

  const aviso = estado && estado.disponible === false ? `No se pueden calcular rutas: ${estado.motivo ?? "el motor de rutas no está disponible"}.` : null;
  return { aviso, refrescar };
}
