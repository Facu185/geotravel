import { useRef, useState } from "react";
import { Aviso } from "../../components/ui.jsx";
import { IconoRecurso } from "../../components/iconos.jsx";
import { nombreTipoRecurso } from "../../components/colores.js";
import { api } from "../../api/client.js";
import useRutasDisponibles from "../../api/useRutasDisponibles.js";

/**
 * Del detalle de un incidente: busca el recurso más cercano POR LAS CALLES y traza su ruta en el mapa.
 *
 * El backend (GET /eta/incidentes/{id}/recurso-mas-cercano) toma los recursos más cercanos en línea recta (por defecto
 * solo los disponibles), calcula con pgRouting la ruta de cada uno respetando los sentidos de circulación y se queda con el
 * que llega antes. El trazado se dibuja en el mapa de la página (IncidentesPage); acá está el botón y el resultado.
 *
 *   incidente    el elegido (para pedir su ruta)
 *   datos        la respuesta del backend (la guarda la página, que dibuja la ruta), o null si no hay ruta trazada
 *   alResultado  se llama con la respuesta nueva, o con null al quitar la ruta
 */

const metros = (m) => (m == null ? "—" : m >= 1000 ? `${(m / 1000).toFixed(2)} km` : `${m} m`);

const TEXTO_ESTADO_RUTA = {
  sin_ruta: "sin ruta por calles",
  error: "no se pudo calcular",
  plazo_agotado: "sin tiempo para calcular",
  no_consultado: "no se consultó",
};

export default function RutaRecursoCercano({ incidente, datos, alResultado }) {
  const [soloDisponibles, setSoloDisponibles] = useState(true);
  const [buscando, setBuscando] = useState(false);
  const [error, setError] = useState(null);
  const { aviso: avisoRutas } = useRutasDisponibles();
  const pedido = useRef(0);

  async function trazar() {
    const numero = ++pedido.current;
    setBuscando(true);
    setError(null);
    alResultado(null);
    try {
      const respuesta = await api.get(`/eta/incidentes/${incidente.id}/recurso-mas-cercano?soloDisponibles=${soloDisponibles}`);
      if (numero === pedido.current) alResultado(respuesta);
    } catch (e) {
      if (numero === pedido.current) setError(e.message);
    } finally {
      if (numero === pedido.current) setBuscando(false);
    }
  }

  function quitar() {
    pedido.current += 1;
    setBuscando(false);
    setError(null);
    alResultado(null);
  }

  const recurso = datos?.recurso;
  const ruta = datos?.ruta;
  const otros = datos?.alternativas?.filter((a) => !a.elegido) ?? [];

  return (
    <section className="bloque">
      <h4 className="bloque__titulo">Recurso más cercano</h4>
      <p className="ayuda">
        Busca entre los recursos más cercanos el que llega antes por las calles (respetando los sentidos de circulación) y traza su ruta en el mapa.
      </p>
      <label className="casilla">
        <input type="checkbox" checked={soloDisponibles} onChange={(e) => setSoloDisponibles(e.target.checked)} disabled={buscando} />
        Solo recursos disponibles
      </label>
      <button type="button" className="btn btn--secundario btn--ancho" onClick={trazar} disabled={buscando || Boolean(avisoRutas)}>
        {buscando ? "Buscando…" : "Trazar ruta al recurso más cercano"}
      </button>
      {avisoRutas && <Aviso tipo="error">{avisoRutas}</Aviso>}
      {error && <Aviso tipo="error">{error}</Aviso>}

      {recurso && ruta && (
        <div className="ruta-recurso">
          <ul className="items">
            <li className="fila">
              <IconoRecurso tipo={recurso.tipo} estado={recurso.estadoOperativo} chico />
              <span className="item__texto">
                <span className="item__titulo">{recurso.identificacion || `Recurso ${recurso.id}`}</span>
                <span className="item__detalle">
                  {nombreTipoRecurso(recurso.tipo)} · {recurso.estadoOperativo}
                </span>
              </span>
            </li>
          </ul>
          <dl className="datos">
            <div>
              <dt>Tiempo estimado</dt>
              <dd>{ruta.tiempoEstimadoMinutos} min</dd>
            </div>
            <div>
              <dt>Distancia por calles</dt>
              <dd>{metros(ruta.distanciaMetros)}</dd>
            </div>
            <div>
              <dt>En línea recta</dt>
              <dd>{metros(ruta.distanciaDirectaMetros)}</dd>
            </div>
          </dl>
          {ruta.advertencia && <Aviso>{ruta.advertencia}</Aviso>}

          {otros.length > 0 && (
            <details className="ruta-recurso__otros">
              <summary>Los otros {otros.length} recursos evaluados</summary>
              <ul className="calles-ruta">
                {otros.map((a) => (
                  <li key={a.recursoId}>
                    <span>{a.identificacion || `Recurso ${a.recursoId}`}</span>
                    <span className="calles-ruta__metros">
                      {a.estadoRuta === "disponible"
                        ? `${a.tiempoEstimadoMinutos} min · ${metros(a.distanciaMetros)}`
                        : (TEXTO_ESTADO_RUTA[a.estadoRuta] ?? a.estadoRuta)}
                    </span>
                  </li>
                ))}
              </ul>
            </details>
          )}

          {ruta.calles?.length > 0 && (
            <details className="ruta-recurso__otros">
              <summary>Calles del recorrido</summary>
              <ol className="calles-ruta">
                {ruta.calles.map((c, n) => (
                  <li key={`${n}-${c.calle}`}>
                    <span>{c.calle}</span>
                    <span className="calles-ruta__metros">{metros(c.metros)}</span>
                  </li>
                ))}
              </ol>
            </details>
          )}

          <p className="ayuda">{datos.criterio}. Estimación sin tráfico en tiempo real.</p>
          <button type="button" className="btn btn--secundario btn--chico" onClick={quitar}>
            Quitar la ruta del mapa
          </button>
        </div>
      )}
    </section>
  );
}
