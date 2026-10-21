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
 *
 * Búsqueda de direcciones (consultas 4 y 5):
 *   ide: departamento y localidad que se mandan al servicio de direcciones de la IDE (cubre todo el país).
 *   callesPropias: true solo en Salto, que tiene calles y números de puerta en la base propia
 *     (cruce de calles y autocompletado, sin internet). En el resto la dirección y la esquina las resuelve la IDE.
 *   ejemploDireccion: texto de ayuda del campo.
 */
export const REGIONES = {
  salto: {
    nombre: "Salto",
    ide: { departamento: "salto", localidad: "salto" },
    callesPropias: true,
    ejemploDireccion: "Uruguay 1000",
    centro: [-31.3857, -57.9606],
    encuadre: [
      [-31.405, -57.995],
      [-31.365, -57.925],
    ],
  },
  montevideo: {
    nombre: "Montevideo",
    ide: { departamento: "montevideo", localidad: "montevideo" },
    callesPropias: false,
    ejemploDireccion: "Buenos Aires 451",
    centro: [-34.88, -56.16],
    encuadre: [
      [-34.915, -56.205],
      [-34.845, -56.115],
    ],
  },
};

export const REGION = REGIONES[import.meta.env.VITE_REGION] ?? REGIONES.salto;

const numero = (valor, porDefecto) => (Number.isFinite(Number(valor)) && valor !== "" ? Number(valor) : porDefecto);

export const CARGA_POR_ZONA = {
  zoomMinimo: numero(import.meta.env.VITE_ZOOM_MINIMO_EDICION, 13),
  limite: numero(import.meta.env.VITE_LIMITE_POR_PANTALLA, 500),
};
