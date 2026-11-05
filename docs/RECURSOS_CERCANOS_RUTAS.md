# Consulta 3: recursos cercanos con buffer y rutas por calles

Endpoint: `GET /consultas/recursos-cercanos/{incidenteId}/analisis-vial`
(es el único endpoint de la consulta 3; el anterior `/consultas/recursos-cercanos/{id}` se quitó).

## Parámetros

| Parámetro | Defecto | Rango |
|---|---|---|
| `radioMetros` | 2000 | 1..10000 (fuera de rango: 400) |
| `limite` | 5 | 1..10 |
| `soloDisponibles` | true | |
| `conRutas` | false | si es true calcula la ruta por calles de los más cercanos |

## Cómo funciona

1. **Buffer**: `ST_Buffer(incidente.geom, radio)` en EPSG:32721 (metros), devuelto en 4326 como `bufferGeom`.
2. **Selección**: `ST_DWithin(recurso.geom, incidente.geom, radio)` ordenado por `ST_Distance`.
   Funciona con incidentes Point, LineString y Polygon.
3. **Distancia directa**: `ST_Distance` y línea `ST_ShortestLine` (`lineaDirecta`).
4. **Ruta por calles** (`conRutas=true`): servicio compartido `RutaService` (el mismo de ETA) calcula, con pgRouting, la ruta
   de los 5 más cercanos, de forma secuencial y con un plazo total de 25 s.
   Si un recurso no tiene ruta queda con `estadoRuta` `sin_ruta` o `error` y conserva su distancia directa.
   Cada ruta trae además las calles por las que pasa (`calles`).
5. Para incidentes lineales o poligonales el destino es el punto del incidente más cercano al recurso.
   La ruta se engancha al punto exacto de la calle más cercana y llega hasta el marcador: se informa
   `ajusteOrigenM`/`ajusteDestinoM` y hay `advertencia` si es ≥ 100 m.

## Un solo camino

Hay una sola ruta: la de **menor duración** (el costo de cada calle es su largo dividido por su velocidad, más una demora por
esquina), respetando los sentidos de circulación. No hay selector de criterio ni ruta "más corta".

Cómo se arma la red (OpenStreetMap de todo Uruguay, con sentidos y velocidades), cómo se engancha cada extremo a la calle y
cuáles son los límites: ver [RED_VIAL.md](RED_VIAL.md). `GET /eta/disponible` informa si se pueden calcular rutas
(`{"disponible":bool,"motivo":...}`); el frontend lo consulta al abrir, cada 15 s (solo con la pestaña visible) y al volver a la
pestaña, y avisa y deshabilita el botón si no están.

### Comportamiento ante fallas

- Cada ruta tiene un límite estricto de tiempo (10 s, o el tiempo restante de los 25 s de la consulta); al vencer, el recurso queda con
  `estadoRuta` `plazo_agotado`.
- Sin camino entre los dos puntos (por ejemplo, un extremo a más de 500 m de cualquier calle) la ETA responde 422 y la consulta
  deja `sin_ruta`.
- Si falta pgRouting, la red vial o la función en la base, la ETA responde 503 y la pantalla lo avisa.
  No hay otro motor de respaldo.

### Pruebas

Unitarias (sin servicios): `mvn -f backend/pom.xml test`. Opt-in con servicios levantados:
`URBANSAFE_INTEGRATION_TESTS=true` (PostGIS; usar una base de pruebas) y `URBANSAFE_PGROUTING_TESTS=true` (pgRouting contra la
red vial real; apuntar `DB_HOST`/`DB_PORT` a la base con la red cargada).

### Limitaciones

- No se modelan giros prohibidos ni semáforos (solo una demora fija por esquina); la duración usa la velocidad máxima de la calle.
- Sin tráfico en tiempo real. La calidad depende de OpenStreetMap (sentidos, cierres, velocidades).
- Los extremos se enganchan a la calle más cercana (ver `advertencia`).

## Uso en el frontend

Consultas → "Recursos cercanos": elegir incidente, radio y cantidad. Se ve el buffer (azul),
las líneas directas (gris punteado) y, con "Calcular rutas por calles", los recorridos (verde).
La pantalla ETA muestra además la distancia directa, las advertencias y las calles del recorrido.

En la pantalla ETA (`/eta`, solo administrador) el incidente y el recurso se eligen **con un clic en el mapa** o en un
**desplegable con búsqueda** (al hacer clic en el campo se abre la lista; escribiendo se filtra, sobre todo el sistema:
`GET /consultas/buscar`). Lo elegido queda marcado en el mapa y no se agrupa. Como en las Consultas, no se cargan todos los
objetos: solo los de la parte visible (`CargaPorZona`) y, con el mapa lejos, los dibuja GeoServer.
