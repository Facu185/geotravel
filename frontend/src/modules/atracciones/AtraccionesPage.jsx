import { useEffect, useState } from "react";
import MapView from "../../components/MapView.jsx";
import { api } from "../../api/client.js";

/** Módulo Atracciones (dueño: P3). ABM Atracciones Turísticas -- este stub solo lista. */
export default function AtraccionesPage() {
  const [atracciones, setAtracciones] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    api.get("/atracciones").then(setAtracciones).catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <h2>Atracciones turísticas</h2>
      {error && <p style={{ color: "crimson" }}>No se pudo cargar: {error}</p>}
      <MapView layers={["geotravel:atraccion"]} />
      <ul>
        {atracciones.map((a) => (
          <li key={a.id}>
            {a.nombre} — {a.clasificacion}
          </li>
        ))}
      </ul>
      {/* TODO (P3): formulario de alta/edición + subida de foto (opcional). */}
    </div>
  );
}
