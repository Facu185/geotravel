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
 *   callesPropias: true solo en Salto, que tiene números de puerta en la base propia (sin internet). En el resto la dirección
 *     con número la resuelve la IDE. Los cruces de calles y el autocompletado son de todo el país (red vial de OpenStreetMap).
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
  // Todo el departamento de Salto, para ver los datos del interior (Belén, Constitución, Termas del Arapey, Daymán...).
  // Solo sirve para el botón "Ir a": las direcciones y las calles propias son las de la ciudad.
  departamento: {
    nombre: "Depto. de Salto",
    ide: { departamento: "salto", localidad: "salto" },
    callesPropias: false,
    ejemploDireccion: "Uruguay 1000",
    centro: [-31.2, -57.1],
    encuadre: [
      [-31.7, -58.05],
      [-30.7, -56.15],
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

/**
 * Desde qué zoom se cargan los objetos para ELEGIRLOS en una pantalla de consulta (Consultas, Tiempo de llegada). Es más
 * permisivo que en los ABM (donde se edita): acá solo se eligen y se miran, y el límite por pedido ya acota la cantidad.
 */
export const ZOOM_MINIMO_ELEGIR = Math.max(1, CARGA_POR_ZONA.zoomMinimo - 2);

/**
 * Dónde buscar una dirección: "todo" es todo el país (primero las puertas propias de Salto y después el servicio de
 * direcciones de la IDE, que cubre los 19 departamentos); los demás limitan la búsqueda a un departamento.
 */
export const DEPARTAMENTOS = [
  { valor: "artigas", nombre: "Artigas" },
  { valor: "canelones", nombre: "Canelones" },
  { valor: "cerro largo", nombre: "Cerro Largo" },
  { valor: "colonia", nombre: "Colonia" },
  { valor: "durazno", nombre: "Durazno" },
  { valor: "flores", nombre: "Flores" },
  { valor: "florida", nombre: "Florida" },
  { valor: "lavalleja", nombre: "Lavalleja" },
  { valor: "maldonado", nombre: "Maldonado" },
  { valor: "montevideo", nombre: "Montevideo" },
  { valor: "paysandu", nombre: "Paysandú" },
  { valor: "rio negro", nombre: "Río Negro" },
  { valor: "rivera", nombre: "Rivera" },
  { valor: "rocha", nombre: "Rocha" },
  { valor: "salto", nombre: "Salto" },
  { valor: "san jose", nombre: "San José" },
  { valor: "soriano", nombre: "Soriano" },
  { valor: "tacuarembo", nombre: "Tacuarembó" },
  { valor: "treinta y tres", nombre: "Treinta y Tres" },
];

const NOMBRE_DE = Object.fromEntries(DEPARTAMENTOS.map((d) => [d.valor, d.nombre]));
const MINUSCULAS = new Set(["y", "de", "del", "la", "el"]);

/** Cómo se muestra un departamento o una localidad que llegó en minúsculas y sin tildes: "rio negro" -> "Río Negro". */
export const nombreLugar = (texto) =>
  NOMBRE_DE[texto] ??
  (texto ?? "")
    .split(" ")
    .map((palabra, i) => (i > 0 && MINUSCULAS.has(palabra) ? palabra : palabra.charAt(0).toUpperCase() + palabra.slice(1)))
    .join(" ");
