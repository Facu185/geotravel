import { useState } from "react";
import MapView, { ENCUADRE_MONTEVIDEO } from "./MapView.jsx";

/**
 * Página con el mapa a pantalla completa y un panel flotante: en escritorio es una tarjeta
 * arriba a la izquierda; en pantallas chicas es una hoja que sube desde abajo, para poder
 * seguir viendo (y tocando) el mapa mientras se completa un formulario.
 *
 * Es la estructura común del mapa público y de las pantallas de administración, para que
 * todas se vean y se comporten igual.
 *
 *   etiqueta, titulo  texto de la cabecera del panel
 *   etiquetaBoton     texto del botón que reabre el panel cuando está oculto
 *   abiertoEnMovil    si el panel arranca abierto en pantallas chicas (en escritorio siempre abre)
 *   hijosMapa         lo que se dibuja DENTRO del mapa (marcadores, polígonos, controles)
 *   mapaProps         props extra para MapView (p. ej. layers y wmsExtra)
 *   aviso             elemento que se superpone al mapa (p. ej. "todas las capas ocultas")
 *   pie               contenido fijo al pie del panel
 *   children          contenido del panel (scrollea si no entra)
 */
export default function PaginaMapa({
  etiqueta,
  titulo,
  etiquetaBoton = "Panel",
  abiertoEnMovil = true,
  hijosMapa,
  mapaProps,
  aviso,
  pie,
  children,
}) {
  const [esEscritorio] = useState(() => window.matchMedia("(min-width: 800px)").matches);
  const [abierto, setAbierto] = useState(esEscritorio || abiertoEnMovil);

  // Márgenes con los que se encuadran los datos, para que no queden tapados por el panel.
  const [margen] = useState(() => {
    if (esEscritorio) return { izquierda: 390, abajo: 16 };
    return { izquierda: 16, abajo: abiertoEnMovil ? Math.round(window.innerHeight * 0.46) + 8 : 16 };
  });

  return (
    <section className="pagina-mapa" aria-label={titulo}>
      <MapView
        base="claro"
        zoomPosition="bottomright"
        height="100%"
        bounds={ENCUADRE_MONTEVIDEO}
        boundsOptions={{ paddingTopLeft: [margen.izquierda, 32], paddingBottomRight: [16, margen.abajo] }}
        {...mapaProps}
      >
        {hijosMapa}
      </MapView>

      {aviso}

      {!abierto && (
        <button type="button" className="boton-panel" onClick={() => setAbierto(true)} aria-expanded="false" aria-controls="panel-mapa">
          <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true" focusable="false">
            <path d="m12 3 9 5-9 5-9-5zM3 12.5l9 5 9-5M3 16.5l9 5 9-5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round" />
          </svg>
          {etiquetaBoton}
        </button>
      )}

      {abierto && (
        <aside className="panel" id="panel-mapa" aria-label={titulo}>
          <header className="panel__cabecera">
            <div>
              <p className="panel__etiqueta">{etiqueta}</p>
              <h2 className="panel__titulo">{titulo}</h2>
            </div>
            <button type="button" className="panel__cerrar" onClick={() => setAbierto(false)} aria-label="Ocultar el panel" aria-expanded="true" aria-controls="panel-mapa">
              <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true" focusable="false">
                <path d="m6 6 12 12M18 6 6 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
            </button>
          </header>
          <div className="panel__cuerpo">{children}</div>
          {pie && <footer className="panel__pie">{pie}</footer>}
        </aside>
      )}
    </section>
  );
}
