import { useCallback, useEffect, useState } from "react";
import { api } from "./client.js";

const BASE = [
  { valor: "mas_rapida", etiqueta: "Más rápida (tiempo)", color: "#2563eb" },
  { valor: "mas_corta", etiqueta: "Más corta (distancia)", color: "#16a34a" },
];
const REFRESCO_MS = 15000;

/**
 * Opciones de criterio de ruta según el estado real de los motores OSRM (GET /eta/criterios).
 * Se consulta al montar, cada 15 s y al volver a la pestaña; el servidor cachea la salud 5 s.
 * No cambia el criterio elegido: quien lo usa recibe `mensajeDe(valor)` con el motivo.
 */
export default function useCriteriosRuta() {
  const [estado, setEstado] = useState(null);

  const refrescar = useCallback(() => {
    return api
      .get("/eta/criterios")
      .then(setEstado)
      .catch(() =>
        setEstado({ mas_rapida: false, mas_corta: false, motivos: { mas_rapida: "no se pudo consultar al servidor", mas_corta: "no se pudo consultar al servidor" } })
      );
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

  const opciones = BASE.map((o) => ({
    ...o,
    deshabilitada: estado != null && estado[o.valor] === false,
    motivo: `No disponible: ${estado?.motivos?.[o.valor] ?? "el motor de rutas no responde"}`,
  }));

  const mensajeDe = (valor) => {
    const o = opciones.find((x) => x.valor === valor);
    return o?.deshabilitada ? `El criterio "${o.etiqueta}" no está disponible (${o.motivo.replace("No disponible: ", "")}). Elegí otro criterio; no se cambia solo.` : null;
  };

  return { opciones, mensajeDe, refrescar };
}
