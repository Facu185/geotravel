/**
 * Capas del mapa público: qué capa de GeoServer es cada una y cómo se lee su leyenda.
 *
 * Los colores salen de los estilos SLD que publica GeoServer (geoserver/styles/*.sld).
 * Si se cambia un color allá, hay que cambiarlo acá para que la leyenda no mienta.
 *
 * Incidentes y recursos se dibujan con íconos (ver docs/ICONOS.md): en la leyenda, un ítem con `incidente: estado`
 * muestra el triángulo del color de ese estado, y uno con `recurso: tipo` muestra el ícono de ese tipo de recurso.
 *
 * El orden importa: la primera capa queda abajo y la última arriba en el mapa
 * (las calles son líneas de referencia, las zonas son áreas, y los incidentes y recursos
 * son puntos encima). `activaPorDefecto: false` la deja apagada hasta que se prenda.
 */
export const CAPAS = [
  {
    id: "calles",
    capa: "geotravel:via",
    nombre: "Calles",
    descripcion: "Red vial de Salto, como referencia",
    forma: "linea",
    activaPorDefecto: false,
    leyenda: [
      { color: "#5f6f7e", etiqueta: "Avenida, bulevar, rambla" },
      { color: "#98a5b1", etiqueta: "Calle" },
      { color: "#b9c3cc", etiqueta: "Peatonal o proyectada" },
    ],
  },
  {
    id: "puertas",
    capa: "geotravel:acceso",
    nombre: "Números de puerta",
    descripcion: "Se dibujan al acercar mucho el mapa",
    forma: "circulo",
    activaPorDefecto: false,
    leyenda: [{ color: "#5f6f7e", etiqueta: "Puerta con su número" }],
  },
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
    descripcion: "Eventos urbanos: el color es el estado",
    forma: "circulo",
    leyenda: [
      { incidente: "Registrado", etiqueta: "Registrado" },
      { incidente: "En atención", etiqueta: "En atención" },
      { incidente: "Derivado", etiqueta: "Derivado" },
      { incidente: "Resuelto", etiqueta: "Resuelto" },
      { incidente: "Cancelado", etiqueta: "Cancelado" },
    ],
  },
  {
    id: "recursos",
    capa: "geotravel:recurso",
    nombre: "Recursos",
    descripcion: "La forma del ícono es el tipo; el color, el estado operativo",
    forma: "cuadrado",
    leyenda: [
      { recurso: "ambulancia", etiqueta: "Ambulancia" },
      { recurso: "bomberos", etiqueta: "Bomberos" },
      { recurso: "patrulla", etiqueta: "Patrulla" },
      { recurso: "centro_atencion", etiqueta: "Centro de atención" },
      { recurso: "otro", etiqueta: "Otro" },
      { color: "#1f7a5c", etiqueta: "Disponible" },
      { color: "#9a5a12", etiqueta: "En servicio" },
      { color: "#a8392b", etiqueta: "Fuera de servicio" },
    ],
  },
];
