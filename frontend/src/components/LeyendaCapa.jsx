import { IconoIncidente, IconoRecurso } from "./iconos.jsx";
import { CAPAS } from "../modules/invitado/capas.js";

/**
 * La leyenda de una capa del mapa (qué significa cada ícono o color), tal como la lee el mapa público. Una sola
 * definición (modules/invitado/capas.js) para el mapa público y para las Consultas.
 *
 *   capa    un elemento de CAPAS
 *   suelta  sin la sangría que la alinea bajo el texto de la capa del panel del mapa público
 */
export function LeyendaCapa({ capa, suelta = false }) {
  return (
    <ul className={suelta ? "leyenda leyenda--suelta" : "leyenda"} aria-label={`Leyenda de ${capa.nombre}`}>
      {capa.leyenda.map((item) => (
        <li key={item.etiqueta} className="leyenda__item">
          {item.tipoIncidente ? (
            <IconoIncidente tipo={item.tipoIncidente} chico />
          ) : item.recurso ? (
            <IconoRecurso tipo={item.recurso} estado="" chico />
          ) : item.grupo ? (
            <span className="grupo__numero grupo__numero--chico" style={{ "--color": item.grupo }} aria-hidden="true">
              3
            </span>
          ) : (
            <span className={`leyenda__marca leyenda__marca--${capa.id === "recursos" || capa.id === "incidentes" ? "circulo" : capa.forma}`} style={{ "--color": item.color }} aria-hidden="true" />
          )}
          {item.etiqueta}
        </li>
      ))}
    </ul>
  );
}

const CAPAS_EN_CONSULTAS = ["incidentes", "recursos", "zonas"];

/** "Qué significa cada ícono": la leyenda de incidentes, recursos y zonas, plegable, para el panel de las Consultas. */
export default function LeyendaIconos() {
  return (
    <details className="leyenda-plegable">
      <summary>¿Qué significa cada ícono?</summary>
      {CAPAS_EN_CONSULTAS.map((id) => {
        const capa = CAPAS.find((c) => c.id === id);
        return (
          <section key={id} className="leyenda-plegable__capa">
            <h4 className="leyenda-plegable__titulo">{capa.nombre}</h4>
            <p className="ayuda">{capa.descripcion}</p>
            <LeyendaCapa capa={capa} suelta />
          </section>
        );
      })}
    </details>
  );
}
