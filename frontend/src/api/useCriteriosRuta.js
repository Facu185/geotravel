import { useEffect, useState } from "react";
import { api } from "./client.js";

const BASE = [
  { valor: "mas_rapida", etiqueta: "Más rápida (tiempo)", color: "#2563eb" },
  { valor: "mas_corta", etiqueta: "Más corta (distancia)", color: "#16a34a" },
];

/** Opciones de criterio de ruta; "más corta" se deshabilita si el servidor no tiene el OSRM propio. */
export default function useCriteriosRuta() {
  const [disponibles, setDisponibles] = useState(null);

  useEffect(() => {
    let activo = true;
    api.get("/eta/criterios")
      .then((d) => activo && setDisponibles(d))
      .catch(() => activo && setDisponibles({ mas_rapida: true, mas_corta: false }));
    return () => {
      activo = false;
    };
  }, []);

  return BASE.map((o) => ({
    ...o,
    deshabilitada: disponibles != null && disponibles[o.valor] === false,
    motivo: "No disponible: el servidor no tiene configurado el OSRM de ruta más corta",
  }));
}
