import { useState } from "react";
import MapView from "../../components/MapView.jsx";

/** Módulo Invitado (dueño: P5). Sin login: mapa público con filtros. */
export default function InvitadoPage() {
  const [verIncidentes, setVerIncidentes] = useState(true);
  const [verRecursos, setVerRecursos] = useState(true);
  const [verZonas, setVerZonas] = useState(true);

  const layers = [
    ...(verZonas ? ["geotravel:zona_operativa"] : []),
    ...(verIncidentes ? ["geotravel:incidente"] : []),
    ...(verRecursos ? ["geotravel:recurso"] : []),
  ];

  return (
    <div>
      <h2>Mapa público</h2>
      <label>
        <input type="checkbox" checked={verZonas} onChange={(e) => setVerZonas(e.target.checked)} />
        {" "}Zonas operativas
      </label>{" "}
      <label>
        <input type="checkbox" checked={verIncidentes} onChange={(e) => setVerIncidentes(e.target.checked)} />
        {" "}Incidentes
      </label>{" "}
      <label>
        <input type="checkbox" checked={verRecursos} onChange={(e) => setVerRecursos(e.target.checked)} />
        {" "}Recursos
      </label>
      <MapView layers={layers} />
      {/* TODO (P5): filtro por tipo/estado/prioridad/fecha de incidentes y por tipo de
          recurso (vía CQL_FILTER en la WMSTileLayer, o consumiendo /api/incidentes y
          /api/recursos y filtrando en frontend). */}
    </div>
  );
}
