import { useEffect, useState } from "react";
import MapView from "../../components/MapView.jsx";
import { api } from "../../api/client.js";

/** Módulo Recorridos (dueño: P4). ABM + avanzar estado + histórico -- este stub lista y avanza. */
export default function RecorridosPage() {
  const [recorridos, setRecorridos] = useState([]);
  const [error, setError] = useState(null);

  const cargar = () => api.get("/recorridos").then(setRecorridos).catch((e) => setError(e.message));

  useEffect(() => {
    cargar();
  }, []);

  const avanzar = async (id) => {
    try {
      await api.post(`/recorridos/${id}/avanzar`);
      cargar();
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <div>
      <h2>Recorridos</h2>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <MapView layers={["geotravel:v_recorrido_geom"]} />
      <table>
        <thead>
          <tr>
            <th>Nombre</th>
            <th>Estado</th>
            <th>Estado efectivo</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {recorridos.map((r) => (
            <tr key={r.id}>
              <td>{r.nombre}</td>
              <td>{r.estado}</td>
              <td>{r.estadoEfectivo}</td>
              <td>
                <button onClick={() => avanzar(r.id)}>Avanzar</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {/* TODO (P4): ABM completo, selección/orden de atracciones, histórico de estados,
          y el opcional "gráfica de popularidad de recorridos por zona". */}
    </div>
  );
}
