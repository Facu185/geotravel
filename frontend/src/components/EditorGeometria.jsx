import { useCallback, useEffect, useMemo, useRef } from "react";
import L from "leaflet";
import { FeatureGroup, useMap } from "react-leaflet";
import { EditControl } from "react-leaflet-draw";
import "leaflet-draw/dist/leaflet.draw.css";

/**
 * Dibujo de una geometría sobre el mapa: punto, línea o polígono. Es la pieza común para los ABM
 * que guardan una forma (hoy Incidentes; Zonas y Recursos pueden usarla igual).
 *
 * Va DENTRO del mapa (hijosMapa) y contiene el FeatureGroup editable, que tiene a lo sumo UNA forma:
 * la recién dibujada o la del objeto que se está editando. Las demás se muestran aparte, solo lectura.
 *
 *   grupoRef    ref que se llena con el FeatureGroup; el formulario lo usa para cargar la forma de un
 *               objeto (cargarGeometria), leer lo que hay al guardar (geometriaDelGrupo) y vaciarlo.
 *   formas      cuáles se pueden dibujar: { punto, linea, poligono } (todas por defecto)
 *   pedido      { forma: "Point" | "LineString" | "Polygon" }: empieza a dibujar esa forma ya, sin buscar
 *               el botón de la barra. Cada pedido nuevo (objeto distinto) vuelve a empezar.
 *   dibujando   ref que vale true mientras se dibuja o edita, para que un clic sobre otro objeto del
 *               mapa no lo seleccione a mitad del trazo
 *   alCrear(geometria)  se dibujó una forma (GeoJSON lon/lat); reemplaza a la anterior
 *   alEditar(geometria) se movieron vértices con la barra
 *   alBorrar()          se borró la forma con la barra
 *
 * Los manejadores se leen siempre en su última versión: react-leaflet-draw vuelve a registrar sus
 * eventos cada vez que le cambian las funciones, y acumularía manejadores viejos.
 */

/** Textos de la barra y de los avisos de dibujo (leaflet-draw los trae en inglés). */
const { drawLocal } = L;
Object.assign(drawLocal.draw.toolbar.actions, { title: "Cancelar el dibujo", text: "Cancelar" });
Object.assign(drawLocal.draw.toolbar.finish, { title: "Terminar el dibujo", text: "Terminar" });
Object.assign(drawLocal.draw.toolbar.undo, { title: "Borrar el último punto", text: "Borrar el último punto" });
Object.assign(drawLocal.draw.toolbar.buttons, {
  polyline: "Dibujar una línea",
  polygon: "Dibujar un polígono",
  circlemarker: "Marcar un punto",
});
Object.assign(drawLocal.draw.handlers.circlemarker.tooltip, { start: "Hacé clic en el mapa para ubicar el punto." });
Object.assign(drawLocal.draw.handlers.polyline.tooltip, {
  start: "Hacé clic para empezar la línea.",
  cont: "Hacé clic para seguir la línea.",
  end: "Hacé clic en el último punto para terminar.",
});
drawLocal.draw.handlers.polyline.error = "<strong>Error:</strong> la línea no puede cruzarse a sí misma.";
Object.assign(drawLocal.draw.handlers.polygon.tooltip, {
  start: "Hacé clic para empezar el polígono.",
  cont: "Hacé clic para seguir el polígono.",
  end: "Hacé clic en el primer punto para cerrarlo.",
});
drawLocal.draw.handlers.polygon.error = "<strong>Error:</strong> los lados del polígono no pueden cruzarse.";
Object.assign(drawLocal.edit.toolbar.actions.save, { title: "Guardar los cambios", text: "Guardar" });
Object.assign(drawLocal.edit.toolbar.actions.cancel, { title: "Descartar los cambios", text: "Descartar" });
Object.assign(drawLocal.edit.toolbar.actions.clearAll, { title: "Quitar la forma", text: "Quitar" });
Object.assign(drawLocal.edit.toolbar.buttons, {
  edit: "Modificar la forma",
  editDisabled: "No hay nada para modificar",
  remove: "Quitar la forma",
  removeDisabled: "No hay nada para quitar",
});
Object.assign(drawLocal.edit.handlers.edit.tooltip, { text: "Arrastrá los puntos para modificar la forma.", subtext: "Descartar deshace los cambios." });
Object.assign(drawLocal.edit.handlers.remove.tooltip, { text: "Tocá la forma para quitarla." });

const COLOR_TRAZO = "#13202c";
const TRAZO = { color: COLOR_TRAZO };

/** Punto como círculo (no como marcador con ícono), para que se pueda dibujar, mover y estilar igual que el resto. */
const puntoComoCirculo = (_, latlng) => L.circleMarker(latlng, { radius: 10, ...TRAZO, weight: 3, fillOpacity: 0.5 });

/** Pone en el grupo la forma de un objeto existente (GeoJSON lon/lat), reemplazando lo que hubiera. */
export function cargarGeometria(grupo, geometria) {
  grupo.clearLayers();
  if (!geometria) return;
  L.geoJSON(geometria, {
    pointToLayer: puntoComoCirculo,
    style: () => ({ ...TRAZO, weight: 5, fillOpacity: 0.3 }),
  }).eachLayer((capa) => grupo.addLayer(capa));
}

/** La forma que hay ahora en el mapa, con los vértices como estén (se hayan confirmado en la barra o no). */
export function geometriaDelGrupo(grupo) {
  const capas = grupo?.getLayers() ?? [];
  return capas.length > 0 ? capas[0].toGeoJSON().geometry : null;
}

/** "Point" | "LineString" | "Polygon" de una geometría (las Multi* cuentan como su tipo simple). */
export const formaDe = (geometria) => geometria.type.replace("Multi", "");

export default function EditorGeometria({ grupoRef, formas = {}, pedido, dibujando, alCrear, alEditar, alBorrar }) {
  const map = useMap();
  const { punto = true, linea = true, poligono = true } = formas;

  const ultimo = useRef({});
  ultimo.current = { alCrear, alEditar, alBorrar };

  const creada = useCallback(
    (e) => {
      const grupo = grupoRef.current;
      grupo.eachLayer((capa) => {
        if (capa !== e.layer) grupo.removeLayer(capa);
      });
      ultimo.current.alCrear?.(e.layer.toGeoJSON().geometry);
    },
    [grupoRef],
  );
  const editada = useCallback(
    (e) => {
      e.layers.eachLayer((capa) => ultimo.current.alEditar?.(capa.toGeoJSON().geometry));
    },
    [],
  );
  const borrada = useCallback(() => ultimo.current.alBorrar?.(), []);

  // Las opciones de la barra deben ser SIEMPRE el mismo objeto: leaflet-draw les agrega cosas al crear la
  // barra, y react-leaflet-draw, al verlas distintas, la rehace en cada render (y cancela el trazo en curso).
  const herramientas = useMemo(
    () => ({
      polyline: linea ? { shapeOptions: { ...TRAZO, weight: 5 } } : false,
      polygon: poligono ? { allowIntersection: false, showArea: false, shapeOptions: { ...TRAZO, weight: 3 } } : false,
      circlemarker: punto ? { ...TRAZO, weight: 3, fillOpacity: 0.5 } : false,
      rectangle: false,
      circle: false,
      marker: false,
    }),
    [punto, linea, poligono],
  );

  // Mientras se dibuja o se edita, los clics sobre otros objetos no deben seleccionarlos.
  useEffect(() => {
    if (!dibujando) return undefined;
    const marcar = (valor) => () => {
      dibujando.current = valor;
    };
    const eventos = {
      "draw:drawstart": marcar(true),
      "draw:editstart": marcar(true),
      "draw:deletestart": marcar(true),
      "draw:drawstop": marcar(false),
      "draw:editstop": marcar(false),
      "draw:deletestop": marcar(false),
    };
    map.on(eventos);
    return () => map.off(eventos);
  }, [map, dibujando]);

  // Empieza a dibujar la forma pedida.
  useEffect(() => {
    if (!pedido) return undefined;
    let manejador;
    if (pedido.forma === "Point") manejador = new L.Draw.CircleMarker(map, { ...TRAZO, weight: 3, fillOpacity: 0.5 });
    else if (pedido.forma === "LineString") manejador = new L.Draw.Polyline(map, { shapeOptions: { ...TRAZO, weight: 5 } });
    else manejador = new L.Draw.Polygon(map, { allowIntersection: false, showArea: false, shapeOptions: { ...TRAZO, weight: 3 } });
    manejador.enable();
    return () => manejador.disable();
  }, [map, pedido]);

  return (
    <FeatureGroup ref={grupoRef}>
      <EditControl
        position="topright"
        onCreated={creada}
        onEdited={editada}
        onDeleted={borrada}
        draw={herramientas}
      />
    </FeatureGroup>
  );
}
