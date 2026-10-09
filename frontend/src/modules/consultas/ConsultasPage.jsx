import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import { CircleMarker, FeatureGroup, GeoJSON, Marker, Polyline, Tooltip, useMap, useMapEvents } from "react-leaflet";
import { EditControl } from "react-leaflet-draw";
import "leaflet-draw/dist/leaflet.draw.css";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import { Aviso } from "../../components/ui.jsx";
import { COLOR_ESTADO_INCIDENTE, COLOR_ESTADO_RECURSO, COLOR_PRIORIDAD } from "../../components/colores.js";
import { api } from "../../api/client.js";
import { CONSULTAS, RESULTADO_VACIO } from "./paneles.jsx";

/**
 * Módulo Consultas geográficas y reportes (dueño: P5).
 *
 * Mapa a pantalla completa con un panel: se elige una consulta, se completan sus parámetros y
 * el resultado aparece como lista y dibujado en el mapa. Los cálculos los hace PostGIS en el
 * backend (backend/.../consultas/ConsultaResource.java); acá solo se piden y se muestran.
 * Cada consulta es un panel de paneles.jsx.
 *
 * Esta página carga una vez las zonas, incidentes y recursos (con su geometría) para poder
 * dibujar los resultados, que la API de consultas devuelve solo como ids y datos.
 */

const posicion = (geomTexto) => {
  const [lng, lat] = JSON.parse(geomTexto).coordinates;
  return [lat, lng];
};

function useDatosBase() {
  const [datos, setDatos] = useState({ zonas: [], incidentes: [], recursos: [] });
  const [error, setError] = useState(null);

  useEffect(() => {
    Promise.all([api.get("/zonas"), api.get("/incidentes"), api.get("/recursos")])
      .then(([zonas, incidentes, recursos]) =>
        setDatos({
          zonas: zonas.map((z) => ({ ...z, geometria: JSON.parse(z.geom) })),
          incidentes: incidentes.map((i) => ({ ...i, pos: posicion(i.geom) })),
          recursos: recursos.map((r) => ({ ...r, pos: posicion(r.geom) })),
        }),
      )
      .catch((e) => setError(e.message));
  }, []);

  return { datos, error };
}

/** Los recursos se dibujan como cuadrados (los incidentes, como círculos), igual que en GeoServer. */
const iconos = {};
const iconoRecurso = (color) => {
  if (!iconos[color]) {
    iconos[color] = L.divIcon({
      className: "",
      iconSize: [18, 18],
      iconAnchor: [9, 9],
      html: `<span style="display:block;width:18px;height:18px;box-sizing:border-box;background:${color};border:2px solid #fff;border-radius:4px;box-shadow:0 0 0 1px rgba(19,32,44,.55)"></span>`,
    });
  }
  return iconos[color];
};

function ClickEnMapa({ alClick }) {
  useMapEvents({ click: (e) => alClick([e.latlng.lat, e.latlng.lng]) });
  return null;
}

/**
 * Barra de dibujo para la consulta "línea o polígono": una sola figura a la vez, que se puede
 * editar o borrar. `alCambiar` recibe la geometría en lon/lat (GeoJSON), o null si se borra.
 */
function DibujoFigura({ alCambiar }) {
  const grupo = useRef(null);
  const estilo = { color: "#13202c", weight: 3 };
  return (
    <FeatureGroup ref={grupo}>
      <EditControl
        position="topright"
        onCreated={(e) => {
          grupo.current.eachLayer((capa) => {
            if (capa !== e.layer) grupo.current.removeLayer(capa);
          });
          alCambiar(e.layer.toGeoJSON().geometry);
        }}
        onEdited={(e) => e.layers.eachLayer((capa) => alCambiar(capa.toGeoJSON().geometry))}
        onDeleted={() => alCambiar(null)}
        draw={{
          polyline: { shapeOptions: { ...estilo, weight: 4 } },
          polygon: { allowIntersection: false, showArea: false, shapeOptions: estilo },
          rectangle: { shapeOptions: estilo },
          circle: false,
          marker: false,
          circlemarker: false,
        }}
      />
    </FeatureGroup>
  );
}

/** Si el punto elegido (p. ej. un cruce de calles) queda fuera de la vista, lleva el mapa hasta él. */
function CentrarEn({ punto }) {
  const map = useMap();
  useEffect(() => {
    if (punto && !map.getBounds().contains(punto)) map.flyTo(punto, Math.max(map.getZoom(), 15));
  }, [punto, map]);
  return null;
}

/** Zonas (de fondo y resaltadas), contexto, resultado de la consulta y punto elegido. */
function CapaResultado({ datos, resultado, punto }) {
  const incidentesResaltados = new Set(resultado.incidentes);
  const recursosResaltados = new Set(resultado.recursos);

  return (
    <>
      {resultado.area && (
        <GeoJSON
          key={`area-${JSON.stringify(resultado.area.coordinates).length}-${JSON.stringify(resultado.area.coordinates[0][0])}`}
          data={resultado.area}
          interactive={false}
          style={{ color: "#13202c", weight: 1.5, dashArray: "6 5", fillColor: "#13202c", fillOpacity: 0.07 }}
        />
      )}
      {datos.zonas.map((z) => {
        const intensidad = resultado.zonas[z.id];
        const resaltada = intensidad !== undefined;
        return (
          <GeoJSON
            key={`${z.id}-${intensidad ?? "fondo"}`}
            data={z.geometria}
            interactive={false}
            style={{
              color: resaltada ? COLOR_PRIORIDAD[z.nivelPrioridad] : "#8a98a6",
              weight: resaltada ? 3 : 1,
              fillColor: COLOR_PRIORIDAD[z.nivelPrioridad],
              fillOpacity: resaltada ? 0.12 + 0.5 * intensidad : 0.05,
            }}
          >
            {resaltada && (
              <Tooltip permanent direction="center">
                {z.nombre}
              </Tooltip>
            )}
          </GeoJSON>
        );
      })}

      {datos.incidentes
        .filter((i) => !incidentesResaltados.has(i.id))
        .map((i) => (
          <CircleMarker key={`i${i.id}`} center={i.pos} radius={4} interactive={false} pathOptions={{ color: "#7b8794", weight: 1, fillOpacity: 0.35 }} />
        ))}
      {datos.recursos
        .filter((r) => !recursosResaltados.has(r.id))
        .map((r) => (
          <CircleMarker key={`r${r.id}`} center={r.pos} radius={4} interactive={false} pathOptions={{ color: "#7b8794", weight: 1, fillOpacity: 0.35 }} />
        ))}

      {resultado.lineas.map((l, n) => (
        <Polyline key={`l${n}`} positions={[l.desde, l.hasta]} pathOptions={{ color: "#13202c", weight: 2, dashArray: "6 6" }}>
          <Tooltip sticky>{l.texto}</Tooltip>
        </Polyline>
      ))}

      {datos.incidentes
        .filter((i) => incidentesResaltados.has(i.id))
        .map((i) => (
          <CircleMarker
            key={`I${i.id}`}
            center={i.pos}
            radius={10}
            bubblingMouseEvents={false}
            pathOptions={{ color: COLOR_ESTADO_INCIDENTE[i.estado] ?? "#555", weight: 3, fillOpacity: 0.85 }}
          >
            <Tooltip>
              {i.titulo} — {i.estado}
            </Tooltip>
          </CircleMarker>
        ))}
      {datos.recursos
        .filter((r) => recursosResaltados.has(r.id))
        .map((r) => (
          <Marker key={`R${r.id}`} position={r.pos} icon={iconoRecurso(COLOR_ESTADO_RECURSO[r.estadoOperativo] ?? "#555")} bubblingMouseEvents={false}>
            <Tooltip>
              {r.identificacion} — {r.tipo}
            </Tooltip>
          </Marker>
        ))}

      {punto && (
        <CircleMarker center={punto} radius={12} pathOptions={{ color: "#13202c", weight: 4, fillOpacity: 0.25 }}>
          <Tooltip permanent>Punto elegido</Tooltip>
        </CircleMarker>
      )}
    </>
  );
}

export default function ConsultasPage() {
  const { datos, error } = useDatosBase();
  const [consultaId, setConsultaId] = useState(CONSULTAS[0].id);
  const [resultado, setResultado] = useState(RESULTADO_VACIO);
  const [punto, setPunto] = useState(null);
  const [figura, setFigura] = useState(null); // línea o polígono dibujado (GeoJSON en lon/lat)

  const consulta = CONSULTAS.find((c) => c.id === consultaId);
  const { Panel } = consulta;

  const elegir = (id) => {
    setConsultaId(id);
    setResultado(RESULTADO_VACIO);
    setPunto(null);
    setFigura(null);
  };

  const hijosMapa = (
    <>
      {consulta.pideClic && <ClickEnMapa alClick={setPunto} />}
      {consulta.pideClic && <CentrarEn punto={punto} />}
      {consulta.dibuja && <DibujoFigura alCambiar={setFigura} />}
      <CapaResultado datos={datos} resultado={resultado} punto={consulta.pideClic ? punto : null} />
    </>
  );

  return (
    <PaginaMapa etiqueta="Análisis espacial" titulo="Consultas geográficas" etiquetaBoton="Consultas" hijosMapa={hijosMapa}>
      <div className="panel__seccion">
        {error && <Aviso tipo="error">No se pudieron cargar los datos: {error}</Aviso>}
        <label className="campo">
          <span className="campo__etiqueta">Consulta</span>
          <select value={consultaId} onChange={(e) => elegir(e.target.value)}>
            {CONSULTAS.map((c) => (
              <option key={c.id} value={c.id}>
                {c.titulo}
              </option>
            ))}
          </select>
        </label>
        <p className="ayuda">{consulta.descripcion}</p>
        <p className="ayuda">
          <strong>PostGIS:</strong> {consulta.postgis}
        </p>
      </div>
      <div className="panel__seccion">
        <Panel key={consulta.id} datos={datos} punto={punto} setPunto={setPunto} figura={figura} setResultado={setResultado} />
      </div>
    </PaginaMapa>
  );
}
