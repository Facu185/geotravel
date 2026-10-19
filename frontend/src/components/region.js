/**
 * Región que muestra el mapa al abrir y parámetros de la carga "a demanda".
 *
 * Se elige con variables de entorno (frontend/.env.local), sin tocar código:
 *   VITE_REGION=salto | montevideo        (por defecto: salto, donde se hace la defensa)
 *   VITE_ZOOM_MINIMO_EDICION=13            desde qué zoom se cargan los objetos editables
 *   VITE_LIMITE_POR_PANTALLA=500           máximo de objetos por pedido
 *
 * Para agregar un departamento o localidad alcanza con sumar una entrada a REGIONES.
 * encuadre: [[lat sur, lng oeste], [lat norte, lng este]], con un poco de aire.
 */
const REGIONES = {
  salto: {
    nombre: "Salto",
    centro: [-31.3857, -57.9606],
    encuadre: [
      [-31.405, -57.995],
      [-31.365, -57.925],
    ],
  },
  montevideo: {
    nombre: "Montevideo",
    centro: [-34.9011, -56.1645],
    encuadre: [
      [-34.9205, -56.2215],
      [-34.9005, -56.1395],
    ],
  },
};

export const REGION = REGIONES[import.meta.env.VITE_REGION] ?? REGIONES.salto;

const numero = (valor, porDefecto) => (Number.isFinite(Number(valor)) && valor !== "" ? Number(valor) : porDefecto);

export const CARGA_POR_ZONA = {
  zoomMinimo: numero(import.meta.env.VITE_ZOOM_MINIMO_EDICION, 13),
  limite: numero(import.meta.env.VITE_LIMITE_POR_PANTALLA, 500),
};
