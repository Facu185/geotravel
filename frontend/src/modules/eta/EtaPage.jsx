import { useCallback, useMemo, useRef, useState } from "react";
import { GeoJSON } from "react-leaflet";

import PaginaMapa from "../../components/PaginaMapa.jsx";
import Enfocar from "../../components/Enfocar.jsx";
import CapaElegibles from "../../components/CapaElegibles.jsx";
import CargaPorZona, { AvisoCarga, SIN_CARGAR } from "../../components/CargaPorZona.jsx";
import { IconoIncidente, IconoRecurso } from "../../components/iconos.jsx";
import { nombreTipoIncidente, nombreTipoRecurso } from "../../components/colores.js";
import { ZOOM_MINIMO_ELEGIR } from "../../components/region.js";
import { Aviso, Segmentado } from "../../components/ui.jsx";
import { api } from "../../api/client.js";
import useCriteriosRuta from "../../api/useCriteriosRuta.js";
import { SelectorBuscable, useObjetosDeLaVista } from "../consultas/paneles.jsx";

/**
 * Tiempo estimado de llegada de un recurso a un incidente (P2), por calles.
 *
 * Se eligen el incidente y el recurso con un CLIC en el mapa o en un desplegable en el que se puede buscar. Como en las Consultas, no se cargan
 * todos los objetos: solo los de la parte visible (CargaPorZona) y, con el mapa alejado, los dibuja GeoServer. Lo elegido
 * queda marcado en el mapa y en el panel aunque después se mueva el mapa.
 */

const ESTADOS_FINALES = ["Resuelto", "Cancelado"];

function formatearMetros(metros) {
  if (metros == null) return "—";
  return metros >= 1000 ? `${(metros / 1000).toFixed(2)} km` : `${metros} m`;
}

/** Lo elegido (incidente o recurso), con un botón para cambiarlo. */
function Elegido({ icono, titulo, detalle, onCambiar }) {
  return (
    <ul className="items">
      <li className="fila">
        {icono}
        <span className="item__texto">
          <span className="item__titulo">{titulo}</span>
          <span className="item__detalle">{detalle}</span>
        </span>
        <button type="button" className="btn btn--secundario btn--chico" onClick={onCambiar}>
          Cambiar
        </button>
      </li>
    </ul>
  );
}

export default function EtaPage() {
  const [cargaIncidentes, setCargaIncidentes] = useState(SIN_CARGAR);
  const [cargaRecursos, setCargaRecursos] = useState(SIN_CARGAR);
  const [incidente, setIncidente] = useState(null); // el elegido (objeto con su geometría)
  const [recurso, setRecurso] = useState(null);
  const [calculando, setCalculando] = useState(false);
  const [resultado, setResultado] = useState(null);
  const [error, setError] = useState(null);
  const [criterio, setCriterio] = useState("mas_rapida");
  const [foco, setFoco] = useState(null); // lo último que se eligió buscando: el mapa va hasta ahí
  const { opciones: criteriosRuta, mensajeDe } = useCriteriosRuta();
  const avisoCriterio = mensajeDe(criterio);
  const solicitudActual = useRef(0);

  const incidentesDeLaVista = useObjetosDeLaVista(cargaIncidentes);
  const incidentesActivos = useMemo(
    () => incidentesDeLaVista?.filter((i) => !ESTADOS_FINALES.includes(i.estado)) ?? null,
    [incidentesDeLaVista],
  );
  const recursosDeLaVista = useObjetosDeLaVista(cargaRecursos);

  const limpiarResultado = useCallback(() => {
    solicitudActual.current += 1;
    setResultado(null);
    setError(null);
    setCalculando(false);
  }, []);

  const elegirIncidente = useCallback(
    (objeto) => {
      limpiarResultado();
      setIncidente(objeto);
    },
    [limpiarResultado],
  );
  const elegirRecurso = useCallback(
    (objeto) => {
      limpiarResultado();
      setRecurso(objeto);
    },
    [limpiarResultado],
  );
  // Lo buscado puede estar lejos de la vista: además de elegirlo, el mapa va hasta él.
  const elegirBuscado = (elegir) => (objeto) => {
    elegir(objeto);
    setFoco({ geom: objeto.geometria });
  };

  async function calcular() {
    if (!incidente || !recurso || avisoCriterio) return;

    const numeroSolicitud = ++solicitudActual.current;
    setCalculando(true);
    setResultado(null);
    setError(null);

    try {
      const datos = await api.get(`/eta/recursos/${recurso.id}/incidentes/${incidente.id}?criterio=${criterio}`);
      if (numeroSolicitud === solicitudActual.current) setResultado(datos);
    } catch (e) {
      if (numeroSolicitud === solicitudActual.current) setError(e.message);
    } finally {
      if (numeroSolicitud === solicitudActual.current) setCalculando(false);
    }
  }

  // Con los dos elegidos, el mapa se encuadra en ambos (y en la ruta, cuando llega). Elegir solo uno no mueve el mapa.
  const objetivoMapa = useMemo(() => {
    if (!incidente || !recurso) return null;
    const geometrias = [incidente.geometria, recurso.geometria, resultado?.geometriaRuta].filter(Boolean);
    return { geom: { type: "GeometryCollection", geometries: geometrias } };
  }, [incidente, recurso, resultado]);

  // Lo que se ve en el mapa: los incidentes y recursos de la vista (clickeables) y, siempre, lo elegido resaltado.
  const elegiblesIncidentes = useMemo(
    () => (incidentesActivos ? { tipo: "incidente", items: incidentesActivos, elegidoId: incidente?.id ?? null, elegir: elegirIncidente } : null),
    [incidentesActivos, incidente, elegirIncidente],
  );
  const elegiblesRecursos = useMemo(
    () => (recursosDeLaVista ? { tipo: "recurso", items: recursosDeLaVista, elegidoId: recurso?.id ?? null, elegir: elegirRecurso } : null),
    [recursosDeLaVista, recurso, elegirRecurso],
  );
  const elegidos = useMemo(
    () => ({
      incidente: incidente ? { tipo: "incidente", items: [incidente], elegidoId: incidente.id, elegir: elegirIncidente } : null,
      recurso: recurso ? { tipo: "recurso", items: [recurso], elegidoId: recurso.id, elegir: elegirRecurso } : null,
    }),
    [incidente, recurso, elegirIncidente, elegirRecurso],
  );

  const hijosMapa = (
    <>
      <CargaPorZona key="incidentes" ruta="/incidentes" alCambiar={setCargaIncidentes} zoomMinimo={ZOOM_MINIMO_ELEGIR} />
      <CargaPorZona key="recursos" ruta="/recursos" alCambiar={setCargaRecursos} zoomMinimo={ZOOM_MINIMO_ELEGIR} />
      <CapaElegibles elegibles={elegiblesIncidentes} />
      <CapaElegibles elegibles={elegiblesRecursos} />
      <CapaElegibles elegibles={elegidos.incidente} />
      <CapaElegibles elegibles={elegidos.recurso} />
      {resultado?.geometriaRuta && (
        <GeoJSON key={`ruta-${recurso?.id}-${incidente?.id}-${criterio}`} data={resultado.geometriaRuta} interactive={false} style={{ color: "#0f766e", weight: 6, opacity: 0.9 }} />
      )}
      {objetivoMapa ? <Enfocar objetivo={objetivoMapa} /> : foco && <Enfocar objetivo={foco} />}
    </>
  );

  // De fondo, GeoServer dibuja el tipo que el front todavía no dibuja (con el mapa muy alejado).
  const capasFondo = [
    ...(elegiblesIncidentes?.items.length ? [] : ["geotravel:incidente"]),
    ...(elegiblesRecursos?.items.length ? [] : ["geotravel:recurso"]),
  ];

  return (
    <PaginaMapa
      etiqueta="P2 · Geolocalización"
      titulo="Tiempo estimado de llegada"
      etiquetaBoton="Calcular ETA"
      hijosMapa={hijosMapa}
      mapaProps={{ layers: capasFondo, mostrarZoom: true, zoomMinimo: ZOOM_MINIMO_ELEGIR }}
      aviso={<AvisoCarga carga={cargaIncidentes} nombre="incidentes y recursos" />}
    >
      <div className="panel__seccion">
        <p className="ayuda">
          Elegí un incidente y un recurso de emergencia con un clic en el mapa o en el desplegable (se puede buscar escribiendo). Se calcula el recorrido por calles
          transitables (OSRM) hasta el incidente.
        </p>

        <section className="bloque">
          <h4 className="bloque__titulo">1. Incidente</h4>
          {incidente ? (
            <Elegido
              icono={<IconoIncidente tipo={incidente.tipoIncidente} estado={incidente.estado} chico />}
              titulo={incidente.titulo}
              detalle={`${nombreTipoIncidente(incidente.tipoIncidente)} · ${incidente.estado}`}
              onCambiar={() => elegirIncidente(null)}
            />
          ) : (
            <SelectorBuscable
              etiqueta="Incidente"
              tipo="incidente"
              placeholder="Hacé clic para elegir o escribí para buscar"
              onElegir={elegirBuscado(elegirIncidente)}
              filtrar={(i) => !ESTADOS_FINALES.includes(i.estado)}
            />
          )}
        </section>

        <section className="bloque">
          <h4 className="bloque__titulo">2. Recurso de emergencia</h4>
          {recurso ? (
            <Elegido
              icono={<IconoRecurso tipo={recurso.tipo} estado={recurso.estadoOperativo} chico />}
              titulo={recurso.identificacion || `Recurso ${recurso.id}`}
              detalle={`${nombreTipoRecurso(recurso.tipo)} · ${recurso.estadoOperativo}`}
              onCambiar={() => elegirRecurso(null)}
            />
          ) : (
            <SelectorBuscable
              etiqueta="Recurso"
              tipo="recurso"
              placeholder="Hacé clic para elegir o escribí para buscar"
              onElegir={elegirBuscado(elegirRecurso)}
            />
          )}
        </section>

        <Segmentado
          leyenda="Criterio de la ruta"
          nombre="criterioEta"
          opciones={criteriosRuta}
          valor={criterio}
          onChange={(valor) => {
            limpiarResultado();
            setCriterio(valor);
          }}
        />

        <button type="button" className="btn btn--primario btn--ancho" onClick={calcular} disabled={!incidente || !recurso || calculando || Boolean(avisoCriterio)}>
          {calculando ? "Calculando..." : "Calcular llegada"}
        </button>

        {error && <Aviso tipo="error">{error}</Aviso>}
        {avisoCriterio && <Aviso tipo="error">{avisoCriterio}</Aviso>}

        {resultado && (
          <section className="bloque">
            <h3 className="bloque__titulo">Resultado de la ruta</h3>
            <dl className="datos">
              <div>
                <dt>Distancia por calles</dt>
                <dd>{formatearMetros(resultado.distanciaMetros)}</dd>
              </div>
              <div>
                <dt>Distancia directa</dt>
                <dd>{formatearMetros(resultado.distanciaDirectaMetros)}</dd>
              </div>
              <div>
                <dt>Tiempo estimado</dt>
                <dd>{resultado.tiempoEstimadoMinutos} min</dd>
              </div>
              <div>
                <dt>Duración</dt>
                <dd>{resultado.duracionSegundos} s</dd>
              </div>
              <div>
                <dt>Criterio</dt>
                <dd>{resultado.criterioRutaTexto}</dd>
              </div>
              <div>
                <dt>Motor</dt>
                <dd>{resultado.motor}</dd>
              </div>
            </dl>
            {resultado.advertencia && <Aviso>{resultado.advertencia}</Aviso>}
            <p className="ayuda">Tiempo estimado sin tráfico en tiempo real.</p>
            <p className="ayuda">
              {resultado.criterioRuta === "mas_corta"
                ? "El recorrido minimiza la distancia por calles permitidas; su duración puede ser mayor que la de la ruta más rápida."
                : "El recorrido optimiza la duración, no la distancia: puede no ser el camino de menor distancia vial."}
            </p>
          </section>
        )}
      </div>
    </PaginaMapa>
  );
}
