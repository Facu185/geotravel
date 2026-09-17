import { useState } from "react";
import { api } from "../../api/client.js";

/** Módulo Consultas geográficas y reportes (dueño: P5). Stub del más simple de probar. */
export default function ConsultasPage() {
  const [populares, setPopulares] = useState(null);
  const [zonasActivas, setZonasActivas] = useState(null);

  return (
    <div>
      <h2>Consultas geográficas</h2>

      <section>
        <button onClick={() => api.get("/consultas/puntos-populares").then(setPopulares)}>
          Puntos más populares
        </button>
        <ul>
          {populares?.map((p) => (
            <li key={p.id}>{p.nombre} — en {p.cantidadRecorridos} recorridos</li>
          ))}
        </ul>
      </section>

      <section>
        <button onClick={() => api.get("/consultas/zonas-mas-activas").then(setZonasActivas)}>
          Zonas con más recorridos activos
        </button>
        <ul>
          {zonasActivas?.map((z) => (
            <li key={z.id}>{z.nombre} — {z.recorridosActivos} recorridos activos</li>
          ))}
        </ul>
      </section>

      {/* TODO (P5): recorridos por zona (seleccionable en el mapa), recorrido más
          cercano a una intersección de calles, zona de una dirección ingresada
          -- ver docs/api/openapi.yaml para los endpoints ya disponibles en el backend. */}
    </div>
  );
}
