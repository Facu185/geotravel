import { useEffect, useMemo, useRef, useState } from "react";
import L from "leaflet";
import { GeoJSON } from "react-leaflet";

import PaginaMapa from "../../components/PaginaMapa.jsx";
import Enfocar from "../../components/Enfocar.jsx";
import { Aviso, Selector } from "../../components/ui.jsx";
import { api } from "../../api/client.js";

function obtenerGeometria(elemento) {
  if (!elemento?.geom) return null;

  try {
    return typeof elemento.geom === "string"
      ? JSON.parse(elemento.geom)
      : elemento.geom;
  } catch {
    return null;
  }
}

export default function EtaPage() {
  const [incidentes, setIncidentes] = useState([]);
  const [recursos, setRecursos] = useState([]);
  const [incidenteId, setIncidenteId] = useState("");
  const [recursoId, setRecursoId] = useState("");
  const [cargandoDatos, setCargandoDatos] = useState(true);
  const [calculando, setCalculando] = useState(false);
  const [resultado, setResultado] = useState(null);
  const [error, setError] = useState(null);
  const solicitudActual = useRef(0);

  useEffect(() => {
    let activo = true;

    Promise.all([api.get("/incidentes"), api.get("/recursos")])
      .then(([listaIncidentes, listaRecursos]) => {
        if (!activo) return;
        setIncidentes(listaIncidentes);
        setRecursos(listaRecursos);
      })
      .catch((e) => {
        if (activo) setError(e.message);
      })
      .finally(() => {
        if (activo) setCargandoDatos(false);
      });

    return () => {
      activo = false;
      solicitudActual.current += 1;
    };
  }, []);

  const incidentesActivos = incidentes.filter(
    (incidente) => !["Resuelto", "Cancelado"].includes(incidente.estado)
  );
  const incidente = incidentes.find((item) => String(item.id) === incidenteId);
  const recurso = recursos.find((item) => String(item.id) === recursoId);

  const geometriaIncidente = useMemo(
    () => obtenerGeometria(incidente),
    [incidente]
  );
  const geometriaRecurso = useMemo(
    () => obtenerGeometria(recurso),
    [recurso]
  );
  const objetivoMapa = useMemo(() => {
    const geometrias = [
      geometriaIncidente,
      geometriaRecurso,
      resultado?.geometriaRuta,
    ].filter(Boolean);
    if (geometrias.length === 0) return null;

    return {
      geom: {
        type: "GeometryCollection",
        geometries: geometrias,
      },
    };
  }, [geometriaIncidente, geometriaRecurso, resultado]);

  function limpiarResultado() {
    solicitudActual.current += 1;
    setResultado(null);
    setError(null);
    setCalculando(false);
  }

  async function calcular() {
    if (!incidenteId || !recursoId) return;

    const numeroSolicitud = ++solicitudActual.current;
    setCalculando(true);
    setResultado(null);
    setError(null);

    try {
      const datos = await api.get(
        `/eta/recursos/${recursoId}/incidentes/${incidenteId}`
      );
      if (numeroSolicitud === solicitudActual.current) setResultado(datos);
    } catch (e) {
      if (numeroSolicitud === solicitudActual.current) setError(e.message);
    } finally {
      if (numeroSolicitud === solicitudActual.current) setCalculando(false);
    }
  }

  const hijosMapa = (
    <>
      {resultado?.geometriaRuta && (
        <GeoJSON
          key={`ruta-${recursoId}-${incidenteId}`}
          data={resultado.geometriaRuta}
          style={{ color: "#0f766e", weight: 6, opacity: 0.9 }}
        />
      )}
      {objetivoMapa && <Enfocar objetivo={objetivoMapa} />}
      {geometriaIncidente && (
        <GeoJSON
          key={`incidente-${incidenteId}`}
          data={geometriaIncidente}
          style={{ color: "#dc2626", weight: 4 }}
          pointToLayer={(_, latlng) =>
            L.circleMarker(latlng, {
              radius: 10,
              color: "#dc2626",
              fillOpacity: 0.8,
            })
          }
        />
      )}
      {geometriaRecurso && (
        <GeoJSON
          key={`recurso-${recursoId}`}
          data={geometriaRecurso}
          style={{ color: "#2563eb", weight: 4 }}
          pointToLayer={(_, latlng) =>
            L.circleMarker(latlng, {
              radius: 10,
              color: "#2563eb",
              fillOpacity: 0.8,
            })
          }
        />
      )}
    </>
  );

  return (
    <PaginaMapa
      etiqueta="P2 · Geolocalización"
      titulo="Tiempo estimado de llegada"
      etiquetaBoton="Calcular ETA"
      hijosMapa={hijosMapa}
      mapaProps={{ layers: ["geotravel:incidente", "geotravel:recurso"] }}
    >
      <div className="panel__seccion">
        <p className="ayuda">
          Seleccioná un incidente y un recurso de emergencia. OSRM calculará la
          distancia y la duración por calles.
        </p>

        {cargandoDatos && <Aviso>Cargando recursos e incidentes...</Aviso>}

        {!cargandoDatos && (
          <>
            <Selector
              etiqueta="Incidente"
              valor={incidenteId}
              onChange={(valor) => {
                limpiarResultado();
                setIncidenteId(valor);
              }}
              opciones={incidentesActivos.map((item) => ({
                valor: String(item.id),
                texto: `${item.id} · ${item.titulo}`,
              }))}
              vacio="Seleccioná un incidente"
            />

            <Selector
              etiqueta="Recurso de emergencia"
              valor={recursoId}
              onChange={(valor) => {
                limpiarResultado();
                setRecursoId(valor);
              }}
              opciones={recursos.map((item) => ({
                valor: String(item.id),
                texto: item.identificacion || `Recurso ${item.id}`,
              }))}
              vacio="Seleccioná un recurso"
            />

            <button
              type="button"
              className="btn btn--primario btn--ancho"
              onClick={calcular}
              disabled={!incidenteId || !recursoId || calculando}
            >
              {calculando ? "Calculando..." : "Calcular llegada"}
            </button>
          </>
        )}

        {error && <Aviso tipo="error">{error}</Aviso>}

        {resultado && (
          <section className="bloque">
            <h3 className="bloque__titulo">Resultado de la ruta</h3>
            <dl className="datos">
              <div>
                <dt>Distancia</dt>
                <dd>{(resultado.distanciaMetros / 1000).toFixed(2)} km</dd>
              </div>
              <div>
                <dt>Duración</dt>
                <dd>{resultado.duracionSegundos} segundos</dd>
              </div>
              <div>
                <dt>Tiempo estimado</dt>
                <dd>{resultado.tiempoEstimadoMinutos} minutos</dd>
              </div>
              <div>
                <dt>Motor</dt>
                <dd>{resultado.motor}</dd>
              </div>
            </dl>
            <p className="ayuda">Estimación vial sin tráfico en tiempo real.</p>
          </section>
        )}
      </div>
    </PaginaMapa>
  );
}
