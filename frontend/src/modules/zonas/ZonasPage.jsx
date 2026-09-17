import { useEffect, useState } from "react";
import MapView from "../../components/MapView.jsx";
import { api } from "../../api/client.js";

/** Módulo Zonas (dueño: P3). ABM Zonas Turísticas -- este stub solo lista. */
export default function ZonasPage() {
  const [zonas, setZonas] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    api.get("/zonas").then(setZonas).catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <h2>Zonas turísticas</h2>
      {error && <p style={{ color: "crimson" }}>No se pudo cargar: {error}</p>}
      <MapView layers={["geotravel:zona_turistica"]} />
      <ul>
        {zonas.map((z) => (
          <li key={z.id}>
            {z.nombre} — nivel de atractivo {z.nivelAtractivo}
          </li>
        ))}
      </ul>
      {/* TODO (P3): formulario de alta/edición dibujando el polígono sobre el mapa
          (ej. react-leaflet-draw) + POST/PUT a /api/zonas. */}
    </div>
  );
}
