/**
 * Colores de los datos, iguales a los que dibuja GeoServer (geoserver/styles/*.sld).
 * Se usan para que los controles de los formularios (prioridad, estado) tengan el mismo
 * color que ese dato en el mapa. Si se cambia un color en un SLD, cambiarlo acá también.
 */

// Prioridad de zonas e incidentes: 1 = máxima ... 5 = mínima.
export const COLOR_PRIORIDAD = {
  1: "#c0392b",
  2: "#d9754f",
  3: "#e6a95f",
  4: "#9db08f",
  5: "#c7d0c3",
};

export const COLOR_ESTADO_INCIDENTE = {
  Registrado: "#2b6b9e",
  "En atención": "#9a5a12",
  Derivado: "#7a3b8f",
  Resuelto: "#1f7a5c",
  Cancelado: "#a8392b",
};

export const COLOR_ESTADO_RECURSO = {
  Disponible: "#1f7a5c",
  "En servicio": "#9a5a12",
  "Fuera de servicio": "#a8392b",
};

// Tipos de recurso que conoce el estilo de GeoServer (recursos_tipo.sld).
export const TIPOS_RECURSO = ["ambulancia", "bomberos", "patrulla", "centro_atencion", "otro"];

export const OPCIONES_PRIORIDAD = [1, 2, 3, 4, 5].map((n) => ({
  valor: n,
  etiqueta: String(n),
  color: COLOR_PRIORIDAD[n],
}));
