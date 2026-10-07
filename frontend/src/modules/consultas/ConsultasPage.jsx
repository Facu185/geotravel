import { useState } from "react";
import { api } from "../../api/client.js";

/** Módulo Consultas geográficas y reportes (dueño: P5). Stub de las 2 más simples de probar. */
export default function ConsultasPage() {
  const [zonasActivas, setZonasActivas] = useState(null);
  const [concentracion, setConcentracion] = useState(null);

  return (
    <div>
      <h2>Consultas geográficas</h2>

      <section>
        <button onClick={() => api.get("/consultas/zonas-mas-incidentes").then(setZonasActivas)}>
          Zonas con más incidentes
        </button>
        <ul>
          {zonasActivas?.map((z) => (
            <li key={z.id}>{z.nombre} — {z.cantidadIncidentes} incidentes</li>
          ))}
        </ul>
      </section>

      <section>
        <button onClick={() => api.get("/consultas/zonas-mayor-concentracion").then(setConcentracion)}>
          Zonas con mayor concentración (incidentes/km²)
        </button>
        <ul>
          {concentracion?.map((z) => (
            <li key={z.id}>{z.nombre} — {z.incidentesPorKm2} incidentes/km²</li>
          ))}
        </ul>
      </section>

      {/* TODO (P5): incidentes por zona y recursos por zona (seleccionables en el mapa),
          recursos cercanos a un incidente, incidente/zona más cercanos a una dirección o
          intersección de calles, incidentes por recurso, reporte filtrable -- ver
          docs/api/openapi.yaml para los endpoints ya disponibles en el backend. */}
    </div>
  );
}
