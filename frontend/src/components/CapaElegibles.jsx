import { useMemo, useRef } from "react";
import L from "leaflet";
import { GeoJSON } from "react-leaflet";
import CapaAgrupada from "./CapaAgrupada.jsx";
import { COLOR_ESTADO_INCIDENTE, COLOR_PRIORIDAD } from "./colores.js";
import { iconoIncidente, iconoRecurso } from "./iconos.jsx";

/** Texto del rótulo de un objeto para elegir. */
const etiquetaDe = (tipo, o) => (tipo === "zona" ? o.nombre : tipo === "incidente" ? `${o.titulo} — ${o.estado}` : `${o.identificacion} — ${o.tipo}`);

const COLOR_GRUPO = { incidente: "#13202c", recurso: "#0f766e" };

/**
 * Los objetos de la vista que se pueden elegir con un clic en el mapa: zonas, incidentes o recursos, cada uno con su
 * color (prioridad, estado) o su ícono. El elegido se dibuja más marcado. Va dentro del mapa.
 * La usan las Consultas y la pantalla de tiempo de llegada.
 *
 * Los incidentes y recursos se agrupan con un número cuando el mapa está alejado (ver CapaAgrupada): los puntos con su
 * ícono, y las líneas y polígonos con su forma, que además cuentan en el grupo por su centro.
 *
 *   elegibles: { tipo: "zona" | "incidente" | "recurso", items (con `geometria` y `pos`, ver consultas/geometria.js),
 *                elegidoId, elegir(objeto) }; las zonas pueden traer "intensidad" (0 a 1).
 */
export default function CapaElegibles({ elegibles }) {
  const ultimo = useRef(elegibles);
  ultimo.current = elegibles;

  const tipo = elegibles?.tipo;
  const items = elegibles?.items;
  const elegidoId = elegibles?.elegidoId;

  // Lo que se agrupa: los íconos (y el centro de lo que no es un punto). Las zonas no se agrupan.
  const agrupables = useMemo(() => {
    if (!items || tipo === "zona") return [];
    return items.map((o) => {
      const resaltado = o.id === elegidoId;
      return {
        id: o.id,
        pos: o.pos,
        icon: tipo === "recurso" ? iconoRecurso(o.tipo, o.estadoOperativo, { resaltado }) : iconoIncidente(o.tipoIncidente, o.estado, { resaltado }),
        etiqueta: etiquetaDe(tipo, o),
        alClick: () => ultimo.current.elegir(o),
        soloAgrupado: o.geometria.type !== "Point",
        libre: resaltado,
      };
    });
  }, [items, tipo, elegidoId]);

  if (!elegibles || items.length === 0) return null;

  // Se dibujan aparte las formas: las zonas (todas) y las líneas y polígonos de incidentes.
  const formas = tipo === "zona" ? items : items.filter((o) => o.geometria.type !== "Point");
  const datos = {
    type: "FeatureCollection",
    features: formas.map((o) => ({ type: "Feature", properties: { id: o.id }, geometry: o.geometria })),
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
    if (forma === "LineString") return { color: elegido ? "#13202c" : color, weight: elegido ? 8 : 5, opacity: 0.9 };
    return { color: elegido ? "#13202c" : color, weight: elegido ? 4 : 2, fillColor: color, fillOpacity: elegido ? 0.45 : 0.3 };
  };

  return (
    <>
      {formas.length > 0 && (
        <GeoJSON
          key={`${tipo}|${elegidoId}|${formas.map((o) => `${o.id}:${o.intensidad ?? ""}`).join(",")}`}
          data={datos}
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
      )}
      {agrupables.length > 0 && <CapaAgrupada items={agrupables} color={COLOR_GRUPO[tipo]} />}
    </>
  );
}
