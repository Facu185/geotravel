/**
 * Geometrías de los resultados de las consultas. El backend devuelve la geometría de cada objeto
 * encontrado como texto GeoJSON en lon/lat (campo "geom"); acá se convierte en algo que el mapa
 * pueda dibujar. Así el navegador solo maneja lo que se está mostrando, no todos los objetos.
 */

/**
 * Punto [lat, lng] que representa una geometría GeoJSON: el punto mismo, el vértice del medio de una
 * línea o el promedio de los vértices de un polígono. Los incidentes pueden ser puntos, líneas o
 * polígonos, y esto sirve para ubicarlos en el mapa (distancias dibujadas) sin importar su forma.
 */
export const posicion = (geometria) => {
  const { type, coordinates } = geometria;
  let punto;
  if (type === "Point") punto = coordinates;
  else if (type === "LineString") punto = coordinates[Math.floor(coordinates.length / 2)];
  else {
    const anillo = type === "Polygon" ? coordinates[0].slice(0, -1) : coordinates.flat(type === "MultiPolygon" ? 2 : 1);
    punto = anillo.reduce((a, c) => [a[0] + c[0] / anillo.length, a[1] + c[1] / anillo.length], [0, 0]);
  }
  return [punto[1], punto[0]];
};

/** Un objeto de la API (con "geom" como texto) con su geometría ya leída y un punto representativo. */
export const conGeometria = (objeto) => {
  const geometria = JSON.parse(objeto.geom);
  return { ...objeto, geometria, pos: posicion(geometria) };
};
