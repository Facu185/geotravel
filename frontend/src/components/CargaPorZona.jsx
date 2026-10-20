import { useEffect, useRef } from "react";
import { useMap } from "react-leaflet";
import { api } from "../api/client.js";
import { CARGA_POR_ZONA } from "./region.js";

/**
 * Carga "a demanda": pide al backend solo los objetos del rectángulo visible, hasta un límite,
 * en lugar de traer todos a memoria. Se usa en los ABM (zonas, recursos, incidentes) y sirve
 * igual para Consultas.
 *
 * Es un componente sin UI que va DENTRO del mapa (necesita useMap). Cada vez que el usuario
 * termina de mover o hacer zoom:
 *   - espera ~300 ms (no pide nada mientras el mapa se sigue moviendo),
 *   - cancela el pedido anterior si todavía no volvió,
 *   - por debajo de zoomMinimo no pide nada: ese nivel lo dibuja GeoServer como imagen,
 *   - si no, pide  GET {ruta}?bbox=oeste,sur,este,norte&limit=N  y avisa con alCambiar.
 * Los objetos que salen de la vista se descartan: la capa se reemplaza, nunca se acumula.
 *
 * alCambiar recibe { estado, items, total, truncado, error }, con estado:
 *   "lejos"    zoom por debajo del mínimo (items vacío)
 *   "cargando" pedido en curso (items conserva lo anterior, para que el mapa no parpadee)
 *   "listo"    items es lo que hay en la vista; truncado = quedaron objetos afuera por el límite
 *   "error"    error tiene el mensaje
 *
 * Para volver a pedir sin mover el mapa (después de guardar o borrar), cambiar "recarga".
 */
export const SIN_CARGAR = { estado: "cargando", items: [], total: 0, truncado: false, error: null };

const ESPERA_MS = 300;

export default function CargaPorZona({ ruta, alCambiar, recarga = 0, zoomMinimo = CARGA_POR_ZONA.zoomMinimo, limite = CARGA_POR_ZONA.limite }) {
  const map = useMap();
  // El callback suele ser una función nueva en cada render: se guarda en una ref para no
  // reiniciar la escucha del mapa por eso.
  const avisar = useRef(alCambiar);
  avisar.current = alCambiar;
  // Lo último informado vive fuera del efecto: al pedir de nuevo (p. ej. tras guardar, cambia
  // "recarga") los objetos de antes siguen en el mapa hasta que llegan los nuevos, sin parpadeo.
  const anterior = useRef(SIN_CARGAR);

  useEffect(() => {
    let temporizador;
    let controlador;
    const emitir = (estado) => {
      anterior.current = estado;
      avisar.current(estado);
    };

    const pedir = () => {
      clearTimeout(temporizador);
      temporizador = setTimeout(async () => {
        controlador?.abort();
        if (map.getZoom() < zoomMinimo) {
          emitir({ estado: "lejos", items: [], total: 0, truncado: false, error: null });
          return;
        }
        controlador = new AbortController();
        const propio = controlador;
        emitir({ ...anterior.current, estado: "cargando", error: null });
        const bbox = map.getBounds().pad(0.1).toBBoxString(); // un 10 % de margen: al mover un poco ya está cargado
        try {
          const r = await api.get(`${ruta}?bbox=${bbox}&limit=${limite}`, { signal: propio.signal });
          emitir({ estado: "listo", items: r.items, total: r.total, truncado: r.truncado, error: null });
        } catch (e) {
          if (e.name !== "AbortError") emitir({ ...anterior.current, estado: "error", error: e.message });
        }
      }, ESPERA_MS);
    };

    pedir();
    map.on("moveend", pedir); // también se dispara al terminar un zoom
    return () => {
      map.off("moveend", pedir);
      clearTimeout(temporizador);
      controlador?.abort();
    };
  }, [map, ruta, recarga, zoomMinimo, limite]);

  return null;
}

/**
 * Aviso sobre el mapa con el estado de la carga a demanda. "nombre" va en plural ("zonas").
 * Va en la prop "aviso" de PaginaMapa.
 */
export function AvisoCarga({ carga, nombre }) {
  let texto = null;
  if (carga.estado === "lejos") texto = `Acercá el mapa para ver y editar ${nombre}`;
  else if (carga.estado === "error") texto = `No se pudieron cargar ${nombre}: ${carga.error}`;
  else if (carga.truncado) texto = `Mostrando ${carga.items.length} de ${carga.total} ${nombre}: acercá el mapa para ver el resto`;
  return texto ? (
    <p className="pagina-mapa__vacio pagina-mapa__vacio--carga" role="status">
      {texto}
    </p>
  ) : null;
}
