import { useCallback, useEffect, useState } from "react";
import L from "leaflet";
import { CircleMarker, GeoJSON, Marker, Polyline, Tooltip, useMap, useMapEvents } from "react-leaflet";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import CargaPorZona, { SIN_CARGAR } from "../../components/CargaPorZona.jsx";
import { ZOOM_MINIMO_ELEGIR } from "../../components/region.js";
import CapaElegibles from "../../components/CapaElegibles.jsx";
import { COLOR_ESTADO_INCIDENTE, COLOR_PRIORIDAD } from "../../components/colores.js";
import { iconoIncidente, iconoRecurso } from "../../components/iconos.jsx";
import { CONSULTAS, RESULTADO_VACIO } from "./paneles.jsx";

/**
 * Módulo Consultas geográficas y reportes (dueño: P5).
 *
 * Mapa a pantalla completa con un panel: se elige una consulta, se completan sus parámetros y
 * el resultado aparece como lista y dibujado en el mapa. Los cálculos los hace PostGIS en el
 * backend (backend/.../consultas/ConsultaResource.java); acá solo se piden y se muestran.
 * Cada consulta es un panel de paneles.jsx.
 *
 * Es una pantalla "a demanda": nunca carga todos los objetos. Hay tres clases de cosas en el mapa:
 *   - El FONDO: todo lo que existe, dibujado por GeoServer como imagen (WMS).
 *   - Los OBJETOS PARA ELEGIR (consultas 1, 2, 3, 6 y 7): las zonas, incidentes o recursos de la parte
 *     visible del mapa, hasta un límite (CargaPorZona). El front los dibuja y se eligen con un clic en el
 *     mapa o en la lista del panel. Mientras están dibujados así, GeoServer no dibuja ese mismo tipo.
 *   - El RESULTADO de la consulta: cada consulta devuelve ya la geometría de lo que encontró.
 */

/**
 * Capas que GeoServer dibuja de fondo (imágenes, sin cargar nada en el navegador). Cada consulta pide solo el tipo
 * de objeto con el que trabaja (campo "fondo" de paneles.jsx): no se dibuja todo lo que existe.
 */
const CAPA_DE = { zona: "geotravel:zona_operativa", incidente: "geotravel:incidente", recurso: "geotravel:recurso" };

function ClickEnMapa({ alClick }) {
  useMapEvents({ click: (e) => alClick([e.latlng.lat, e.latlng.lng]) });
  return null;
}

/** Si el punto elegido (p. ej. un cruce de calles) queda fuera de la vista, lleva el mapa hasta él. */
function CentrarEn({ punto }) {
  const map = useMap();
  useEffect(() => {
    if (punto && !map.getBounds().contains(punto)) map.flyTo(punto, Math.max(map.getZoom(), 15));
  }, [punto, map]);
  return null;
}

/** Informa la parte visible del mapa (bbox en lon/lat) cuando se deja de mover; la usan las consultas que filtran por vista. */
function VigilarVista({ alCambiar }) {
  const map = useMap();
  useEffect(() => {
    let espera;
    const medir = () => {
      clearTimeout(espera);
      espera = setTimeout(() => alCambiar({ bbox: map.getBounds().toBBoxString(), zoom: map.getZoom() }), 300);
    };
    medir();
    map.on("moveend", medir);
    return () => {
      map.off("moveend", medir);
      clearTimeout(espera);
    };
  }, [map, alCambiar]);
  return null;
}

/**
 * Encuadra el mapa en el resultado de la consulta: como los objetos pueden estar en cualquier
 * parte del país, no alcanza con mirar la zona inicial. Deja libre el lado del panel.
 * Con porSeleccion (se eligió algo de lo que ya se ve) solo se aleja si el resultado no entra en la vista:
 * nunca se acerca, para no mover el mapa debajo de quien está eligiendo. Si el resultado trae un área (el buffer
 * de la consulta 3), sí encuadra en ella aunque haya que acercar. Un panel puede poner `ajuste` para que se
 * reencuadre solo cuando esa clave cambia (y no cada vez que se suma algo, como un camino por calles).
 */
function AjustarVista({ resultado, punto, porSeleccion }) {
  const map = useMap();
  useEffect(() => {
    const capas = [
      ...resultado.zonas.map((z) => z.geometria),
      ...resultado.incidentes.map((i) => i.geometria),
      ...resultado.recursos.map((r) => r.geometria),
      ...(resultado.buffer ? [resultado.buffer] : []),
      ...(resultado.area ? [resultado.area] : []),
      ...resultado.rutas.map((r) => r.geometria),
    ];
    if (capas.length === 0) return;
    const limites = L.geoJSON({ type: "GeometryCollection", geometries: capas }).getBounds();
    if (punto) limites.extend(punto);
    if (!limites.isValid()) return;
    const soloAlejar = porSeleccion && !resultado.area && !resultado.buffer;
    if (soloAlejar && map.getBounds().contains(limites)) return;
    const escritorio = window.matchMedia("(min-width: 800px)").matches;
    map.fitBounds(limites, {
      paddingTopLeft: [escritorio ? 390 : 24, 40],
      paddingBottomRight: [24, escritorio ? 24 : 260],
      maxZoom: soloAlejar ? map.getZoom() : 16,
    });
    // Solo cuando cambia el resultado (o su clave de ajuste), no cuando se elige un punto
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resultado.ajuste ?? resultado, map]);
  return null;
}

const colorEstado = (i) => COLOR_ESTADO_INCIDENTE[i.estado] ?? "#555";

/** Lo que devolvió la consulta, dibujado con su propia geometría, y el punto elegido. */
function CapaResultado({ resultado, punto }) {
  const pocasZonas = resultado.zonas.length <= 8; // con muchas, los rótulos se amontonan
  const hayRutaElegida = resultado.rutas.some((r) => r.elegida);

  return (
    <>
      {resultado.buffer && (
        <GeoJSON
          key={`buffer-${JSON.stringify(resultado.buffer.coordinates[0]?.[0])}-${resultado.buffer.coordinates[0]?.length}`}
          data={resultado.buffer}
          interactive={false}
          style={{ color: "#1d6fb8", weight: 2, fillColor: "#3b8fe0", fillOpacity: 0.12 }}
        />
      )}

      {resultado.area && (
        <GeoJSON
          key={`area-${JSON.stringify(resultado.area.coordinates[0][0])}-${resultado.area.coordinates[0].length}`}
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
            color: "#13202c",
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

      {/* Línea directa (punteada) del incidente a cada recurso. */}
      {resultado.lineas.map((l, n) => (
        <Polyline
          key={`l${n}-${l.elegida ? "e" : ""}`}
          positions={[l.desde, l.hasta]}
          pathOptions={{ color: l.color ?? "#13202c", weight: l.elegida ? 3 : 2, dashArray: "6 6" }}
        >
          <Tooltip sticky>{l.texto}</Tooltip>
        </Polyline>
      ))}

      {/* Camino por calles (continuo y de otro color) que calcula el servicio de rutas. */}
      {resultado.rutas.map((r) => (
        <GeoJSON
          key={`ruta-${r.id}-${r.elegida ? "e" : ""}-${hayRutaElegida ? "h" : ""}`}
          data={r.geometria}
          bubblingMouseEvents={false}
          style={{ color: "#16a34a", weight: r.elegida ? 7 : 5, opacity: hayRutaElegida && !r.elegida ? 0.4 : 0.9 }}
        >
          <Tooltip sticky>{r.texto}</Tooltip>
        </GeoJSON>
      ))}

      {resultado.incidentes.map((i) =>
        i.geometria.type === "Point" ? (
          <Marker key={`I${i.id}`} position={i.pos} icon={iconoIncidente(i.tipoIncidente, i.estado)} bubblingMouseEvents={false}>
            <Tooltip>
              {i.titulo} — {i.estado}
            </Tooltip>
          </Marker>
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
        <Marker
          key={`R${r.id}-${r.elegido ? "e" : ""}`}
          position={r.pos}
          icon={iconoRecurso(r.tipo, r.estadoOperativo, { resaltado: Boolean(r.elegido) })}
          bubblingMouseEvents={false}
          eventHandlers={r.alElegir ? { click: r.alElegir } : undefined}
        >
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
  const [elegibles, setElegibles] = useState(null); // objetos de la vista para elegir con un clic (ver CapaElegibles)
  const [carga, setCarga] = useState(SIN_CARGAR); // objetos de la vista que pide CargaPorZona
  const [vista, setVista] = useState(null); // parte visible del mapa: { bbox, zoom }
  const [punto, setPunto] = useState(null);

  const consulta = CONSULTAS.find((c) => c.id === consultaId);
  const { Panel } = consulta;

  const elegir = (id) => {
    setConsultaId(id);
    setResultado(RESULTADO_VACIO);
    setElegibles(null);
    setCarga(SIN_CARGAR);
    setPunto(null);
  };

  const alVerCambiar = useCallback((nueva) => setVista(nueva), []);

  const hijosMapa = (
    <>
      {consulta.pideClic && <ClickEnMapa alClick={setPunto} />}
      {consulta.pideClic && <CentrarEn punto={punto} />}
      {consulta.objetos && <CargaPorZona key={consulta.id} ruta={consulta.objetos} alCambiar={setCarga} zoomMinimo={ZOOM_MINIMO_ELEGIR} />}
      <VigilarVista alCambiar={alVerCambiar} />
      <AjustarVista resultado={resultado} punto={consulta.pideClic ? punto : null} porSeleccion={Boolean(consulta.objetos || consulta.sobreVista)} />
      <CapaElegibles elegibles={elegibles} />
      <CapaResultado resultado={resultado} punto={consulta.pideClic ? punto : null} />
    </>
  );

  // De fondo, solo el tipo de la consulta; y ese tampoco cuando el front ya dibuja los objetos para elegir (se vería doble).
  const capasFondo = [CAPA_DE[consulta.fondo]].filter((capa) => !(elegibles && elegibles.items.length > 0 && capa === CAPA_DE[elegibles.tipo]));

  return (
    <PaginaMapa
      etiqueta="Análisis espacial"
      titulo="Consultas geográficas"
      etiquetaBoton="Consultas"
      hijosMapa={hijosMapa}
      mapaProps={{ layers: capasFondo, mostrarZoom: Boolean(consulta.objetos), zoomMinimo: ZOOM_MINIMO_ELEGIR }}
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
        <Panel
          key={consulta.id}
          punto={punto}
          setPunto={setPunto}
          setResultado={setResultado}
          setElegibles={setElegibles}
          carga={carga}
          vista={vista}
        />
      </div>
    </PaginaMapa>
  );
}
