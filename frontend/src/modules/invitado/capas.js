/**
 * Capas del mapa público: qué capa de GeoServer es cada una y cómo se lee su leyenda.
 *
 * Los colores salen de los estilos SLD que publica GeoServer (geoserver/styles/*.sld).
 * Si se cambia un color allá, hay que cambiarlo acá para que la leyenda no mienta.
 *
 * El orden importa: la primera capa queda abajo y la última arriba en el mapa
 * (las zonas son áreas grandes, los incidentes y recursos son puntos encima).
 */
export const CAPAS = [
  {
    id: "zonas",
    capa: "geotravel:zona_operativa",
    nombre: "Zonas operativas",
    descripcion: "Áreas de atención, según su prioridad",
    forma: "zona",
    leyenda: [
      { color: "#c0392b", etiqueta: "1 · Máxima" },
      { color: "#d9754f", etiqueta: "2" },
      { color: "#e6a95f", etiqueta: "3" },
      { color: "#9db08f", etiqueta: "4" },
      { color: "#c7d0c3", etiqueta: "5 · Mínima" },
    ],
  },
  {
    id: "incidentes",
    capa: "geotravel:incidente",
    nombre: "Incidentes",
    descripcion: "Eventos urbanos, según su estado",
    forma: "circulo",
    leyenda: [
      { color: "#2b6b9e", etiqueta: "Registrado" },
      { color: "#9a5a12", etiqueta: "En atención" },
      { color: "#7a3b8f", etiqueta: "Derivado" },
      { color: "#1f7a5c", etiqueta: "Resuelto" },
      { color: "#a8392b", etiqueta: "Cancelado" },
    ],
  },
  {
    id: "recursos",
    capa: "geotravel:recurso",
    nombre: "Recursos",
    descripcion: "Ambulancias, bomberos y patrullas, según su tipo",
    forma: "cuadrado",
    leyenda: [
      { color: "#c0392b", etiqueta: "Ambulancia" },
      { color: "#a0522d", etiqueta: "Bomberos" },
      { color: "#2980b9", etiqueta: "Patrulla" },
      { color: "#27ae60", etiqueta: "Centro de atención" },
      { color: "#7f8c8d", etiqueta: "Otro" },
    ],
  },
];
