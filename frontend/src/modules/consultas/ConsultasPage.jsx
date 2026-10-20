import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import { CircleMarker, FeatureGroup, GeoJSON, Marker, Polyline, Tooltip, useMap, useMapEvents } from "react-leaflet";
import { EditControl } from "react-leaflet-draw";
import "leaflet-draw/dist/leaflet.draw.css";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import { COLOR_ESTADO_INCIDENTE, COLOR_ESTADO_RECURSO, COLOR_PRIORIDAD } from "../../components/colores.js";
import { CONSULTAS, RESULTADO_VACIO } from "./paneles.jsx";

/**
 * Módulo Consultas geográficas y reportes (dueño: P5).
 *
 * Mapa a pantalla completa con un panel: se elige una consulta, se completan sus parámetros y
 * el resultado aparece como lista y dibujado en el mapa. Los cálculos los hace PostGIS en el
 * backend (backend/.../consultas/ConsultaResource.java); acá solo se piden y se muestran.
 * Cada consulta es un panel de paneles.jsx.
 *
 * Es una pantalla "a demanda": no carga las zonas, incidentes ni recursos al abrirse. Cada
 * consulta devuelve ya la geometría de lo que encontró, y el fondo (todo lo demás) lo dibuja
 * GeoServer como imagen. Así funciona igual con miles de objetos.
 */

/** Capas que GeoServer dibuja de fondo (imágenes): todo lo que existe, sin cargarlo en el navegador. */
const CAPAS_FONDO = ["geotravel:zona_operativa", "geotravel:incidente", "geotravel:recurso"];

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

/**
 * Encuadra el mapa en el resultado de la consulta: como los objetos pueden estar en cualquier
 * parte del país, no alcanza con mirar la zona inicial. Deja libre el lado del panel.
 */
function AjustarVista({ resultado, punto }) {
  const map = useMap();
  useEffect(() => {
    const capas = [
      ...resultado.zonas.map((z) => z.geometria),
      ...resultado.incidentes.map((i) => i.geometria),
      ...resultado.recursos.map((r) => r.geometria),
      ...(resultado.area ? [resultado.area] : []),
    ];
    if (capas.length === 0) return;
    const limites = L.geoJSON({ type: "GeometryCollection", geometries: capas }).getBounds();
    if (punto) limites.extend(punto);
    if (!limites.isValid()) return;
    const escritorio = window.matchMedia("(min-width: 800px)").matches;
    map.fitBounds(limites, { paddingTopLeft: [escritorio ? 390 : 24, 40], paddingBottomRight: [24, escritorio ? 24 : 260], maxZoom: 16 });
    // Solo cuando cambia el resultado, no cuando se elige un punto
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resultado, map]);
  return null;
}

const colorEstado = (i) => COLOR_ESTADO_INCIDENTE[i.estado] ?? "#555";

/** Lo que devolvió la consulta, dibujado con su propia geometría, y el punto elegido. */
function CapaResultado({ resultado, punto }) {
  const pocasZonas = resultado.zonas.length <= 8; // con muchas, los rótulos se amontonan

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

      {resultado.zonas.map((z) => (
        <GeoJSON
          key={`z${z.id}-${z.intensidad}`}
          data={z.geometria}
          interactive={false}
          style={{
            color: COLOR_PRIORIDAD[z.nivelPrioridad] ?? "#13202c",
            weight: 3,
            fillColor: COLOR_PRIORIDAD[z.nivelPrioridad] ?? "#13202c",
            fillOpacity: 0.12 + 0.5 * z.intensidad,
          }}
        >
          {pocasZonas && (
            <Tooltip permanent direction="center">
              {z.nombre}
            </Tooltip>
          )}
        </GeoJSON>
      ))}

      {resultado.lineas.map((l, n) => (
        <Polyline key={`l${n}`} positions={[l.desde, l.hasta]} pathOptions={{ color: "#13202c", weight: 2, dashArray: "6 6" }}>
          <Tooltip sticky>{l.texto}</Tooltip>
        </Polyline>
      ))}

      {resultado.incidentes.map((i) =>
        i.geometria.type === "Point" ? (
          <CircleMarker
            key={`I${i.id}`}
            center={i.pos}
            radius={10}
            bubblingMouseEvents={false}
            pathOptions={{ color: colorEstado(i), weight: 3, fillOpacity: 0.85 }}
          >
            <Tooltip>
              {i.titulo} — {i.estado}
            </Tooltip>
          </CircleMarker>
        ) : (
          // Un incidente lineal (calle cortada) o un polígono: se dibuja con su forma y el color de su estado.
          <GeoJSON key={`I${i.id}`} data={i.geometria} bubblingMouseEvents={false} style={{ color: colorEstado(i), weight: 6, opacity: 0.9, fillOpacity: 0.25 }}>
            <Tooltip sticky>
              {i.titulo} — {i.estado}
            </Tooltip>
          </GeoJSON>
        ),
      )}

      {resultado.recursos.map((r) => (
        <Marker key={`R${r.id}`} position={r.pos} icon={iconoRecurso(COLOR_ESTADO_RECURSO[r.estadoOperativo] ?? "#555")} bubblingMouseEvents={false}>
          <Tooltip>
            {r.identificacion} — {r.tipo ?? r.estadoOperativo}
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
      <AjustarVista resultado={resultado} punto={consulta.pideClic ? punto : null} />
      <CapaResultado resultado={resultado} punto={consulta.pideClic ? punto : null} />
    </>
  );

  return (
    <PaginaMapa
      etiqueta="Análisis espacial"
      titulo="Consultas geográficas"
      etiquetaBoton="Consultas"
      hijosMapa={hijosMapa}
      mapaProps={{ layers: CAPAS_FONDO }}
    >
      <div className="panel__seccion">
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
        <Panel key={consulta.id} punto={punto} setPunto={setPunto} figura={figura} setResultado={setResultado} />
      </div>
    </PaginaMapa>
  );
}
