import { useState } from "react";
import MapView from "../../components/MapView.jsx";

/** Módulo Invitado (dueño: P5). Sin login: mapa público con filtros. */
export default function InvitadoPage() {
  const [verRecorridos, setVerRecorridos] = useState(true);
  const [verAtracciones, setVerAtracciones] = useState(true);

  const layers = [
    ...(verRecorridos ? ["geotravel:v_recorrido_geom"] : []),
    ...(verAtracciones ? ["geotravel:atraccion"] : []),
  ];

  return (
    <div>
      <h2>Mapa público</h2>
      <label>
        <input type="checkbox" checked={verRecorridos} onChange={(e) => setVerRecorridos(e.target.checked)} />
        {" "}Recorridos
      </label>{" "}
      <label>
        <input type="checkbox" checked={verAtracciones} onChange={(e) => setVerAtracciones(e.target.checked)} />
        {" "}Atracciones
      </label>
      <MapView layers={layers} />
      {/* TODO (P5): filtro por estado/estacionalidad de recorridos y por
          clasificación de atracciones (vía CQL_FILTER en la WMSTileLayer, o
          consumiendo /api/recorridos y /api/atracciones y filtrando en frontend). */}
    </div>
  );
}
