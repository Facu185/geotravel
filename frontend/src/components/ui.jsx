/** Piezas de interfaz compartidas por los formularios y paneles. Los estilos están en styles.css. */

/** Mensaje de resultado: "error" se anuncia a los lectores de pantalla, "ok" e "info" son avisos suaves. */
export function Aviso({ tipo = "info", children }) {
  return (
    <p className={`aviso aviso--${tipo}`} role={tipo === "error" ? "alert" : "status"}>
      {children}
    </p>
  );
}

/**
 * Grupo de opciones excluyentes (radio) dibujado como botones, cada uno con un punto del
 * color del dato. Se usa para prioridad (1-5) y para los estados.
 *   opciones: [{ valor, etiqueta, color }]
 */
export function Segmentado({ leyenda, nombre, opciones, valor, onChange }) {
  return (
    <fieldset className="segmentado">
      <legend className="campo__etiqueta">{leyenda}</legend>
      <div className="segmentado__opciones">
        {opciones.map((o) => (
          <label key={o.valor} className={o.valor === valor ? "segmentado__opcion segmentado__opcion--activa" : "segmentado__opcion"}>
            <input type="radio" name={nombre} value={o.valor} checked={o.valor === valor} onChange={() => onChange(o.valor)} />
            <span className="segmentado__punto" style={{ "--color": o.color }} aria-hidden="true" />
            {o.etiqueta}
          </label>
        ))}
      </div>
    </fieldset>
  );
}

/** Botón "← Volver" que encabeza los formularios y detalles del panel. */
export function BotonVolver({ onClick, children }) {
  return (
    <button type="button" className="btn-volver" onClick={onClick}>
      <svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" focusable="false">
        <path d="M15 5 8 12l7 7" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      {children}
    </button>
  );
}

/** Ícono "+" para los botones de alta. */
export function IconoMas() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true" focusable="false">
      <path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
    </svg>
  );
}

/** Flecha que indica que una fila de la lista se puede abrir. */
export function IconoFlecha() {
  return (
    <svg className="item__flecha" viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" focusable="false">
      <path d="m9 5 7 7-7 7" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/** Etiqueta con el color del dato (p. ej. el estado de un incidente). */
export function Insignia({ color, children }) {
  return (
    <span className="insignia" style={{ "--color": color }}>
      {children}
    </span>
  );
}

/**
 * Lista desplegable con una etiqueta. `opciones`: [{ valor, texto }]; `vacio` es el texto de
 * la opción sin valor (p. ej. "Todos"). onChange recibe el valor elegido, como texto.
 */
export function Selector({ etiqueta, valor, onChange, opciones, vacio }) {
  return (
    <label className="campo">
      <span className="campo__etiqueta">{etiqueta}</span>
      <select value={valor} onChange={(e) => onChange(e.target.value)}>
        <option value="">{vacio}</option>
        {opciones.map((o) => (
          <option key={o.valor} value={o.valor}>
            {o.texto}
          </option>
        ))}
      </select>
    </label>
  );
}
