import { useRef } from "react";
import L from "leaflet";
import { GeoJSON } from "react-leaflet";
import { COLOR_ESTADO_INCIDENTE, COLOR_PRIORIDAD } from "./colores.js";
import { iconoIncidente, iconoRecurso } from "./iconos.jsx";

/** Texto del rótulo de un objeto para elegir. */
const etiquetaDe = (tipo, o) => (tipo === "zona" ? o.nombre : tipo === "incidente" ? `${o.titulo} — ${o.estado}` : `${o.identificacion} — ${o.tipo}`);

/**
 * Los objetos de la vista que se pueden elegir con un clic en el mapa: zonas, incidentes o recursos, cada uno con su
 * color (prioridad, estado) o su ícono. El elegido se dibuja más marcado. Va dentro del mapa, todo en UNA capa GeoJSON.
 * La usan las Consultas y la pantalla de tiempo de llegada.
 *
 *   elegibles: { tipo: "zona" | "incidente" | "recurso", items (con `geometria`, ver consultas/geometria.js),
 *                elegidoId, elegir(objeto) }; las zonas pueden traer "intensidad" (0 a 1).
 */
export default function CapaElegibles({ elegibles }) {
  const ultimo = useRef(elegibles);
  ultimo.current = elegibles;
  if (!elegibles || elegibles.items.length === 0) return null;

  const { tipo, items, elegidoId } = elegibles;
  const datos = {
    type: "FeatureCollection",
    features: items.map((o) => ({ type: "Feature", properties: { id: o.id }, geometry: o.geometria })),
  };
  const porId = new Map(items.map((o) => [o.id, o]));

  const estilo = (f) => {
    const o = porId.get(f.properties.id);
    const elegido = o.id === elegidoId;
    const forma = f.geometry.type.replace("Multi", "");
    if (tipo === "zona") {
      return {
        color: elegido ? "#13202c" : "#5b6b52",
        weight: elegido ? 4 : 1.5,
        fillColor: COLOR_PRIORIDAD[o.nivelPrioridad] ?? "#999",
        fillOpacity: elegido ? 0.55 : o.intensidad != null ? 0.12 + 0.5 * o.intensidad : 0.4,
      };
    }
    const color = tipo === "incidente" ? (COLOR_ESTADO_INCIDENTE[o.estado] ?? "#555") : "#555";
    if (forma === "Point") return { color: elegido ? "#13202c" : "#ffffff", weight: elegido ? 4 : 1.5, fillColor: color, fillOpacity: 0.9 };
    if (forma === "LineString") return { color: elegido ? "#13202c" : color, weight: elegido ? 8 : 5, opacity: 0.9 };
    return { color: elegido ? "#13202c" : color, weight: elegido ? 4 : 2, fillColor: color, fillOpacity: elegido ? 0.45 : 0.3 };
  };

  return (
    <GeoJSON
      key={`${tipo}|${elegidoId}|${items.map((o) => `${o.id}:${o.intensidad ?? ""}`).join(",")}`}
      data={datos}
      pointToLayer={(f, latlng) => {
        const o = porId.get(f.properties.id);
        const resaltado = o.id === elegidoId;
        if (tipo === "recurso") return L.marker(latlng, { icon: iconoRecurso(o.tipo, o.estadoOperativo, { resaltado }) });
        return L.marker(latlng, { icon: iconoIncidente(o.tipoIncidente, o.estado, { resaltado }) });
      }}
      style={estilo}
      onEachFeature={(f, capa) => {
        const o = porId.get(f.properties.id);
        capa.bindTooltip(etiquetaDe(tipo, o), { sticky: true });
        capa.on("click", (e) => {
          L.DomEvent.stopPropagation(e);
          ultimo.current.elegir(o);
        });
      }}
    />
  );
}
