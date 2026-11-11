# Consulta 3: recursos más cercanos a un incidente y rutas por calles

Endpoint: `GET /consultas/recursos-cercanos/{incidenteId}/analisis-vial`
(es el único endpoint de la consulta 3; el anterior `/consultas/recursos-cercanos/{id}` se quitó).

## Parámetros

| Parámetro | Defecto | Rango |
|---|---|---|
| `limite` | 5 | 1..10: cuántos recursos (fuera de rango: 400) |
| `soloDisponibles` | true | |
| `conRutas` | false | si es true calcula la ruta por calles más corta de los más cercanos |

No hay radio ni buffer: se devuelven los `limite` recursos más cercanos, sea cual sea su distancia.

## Cómo funciona

1. **Selección**: los recursos se ordenan por cercanía al incidente con el operador de vecino más cercano
   (`recurso.geom <-> incidente.geom`, apoyado en el índice GiST) y se toman los primeros `limite`.
   Funciona con incidentes Point, LineString y Polygon.
2. **Distancia directa**: `ST_Distance`, en metros (`distanciaDirectaM`). El mapa no dibuja líneas directas.
3. **Ruta por calles** (`conRutas=true`): servicio compartido `RutaService` (el mismo de ETA) calcula, con pgRouting y
   **por distancia** (`Criterio.DISTANCIA`), la ruta más corta de los 5 más cercanos, de forma secuencial y con un plazo
   total de 25 s. `recursoMasCercanoId` es el de menor distancia por calles (a igual distancia, el de menor duración).
   La pantalla lo marca con la insignia "Más cercano por calles".
   Si un recurso no tiene ruta queda con `estadoRuta` `sin_ruta` o `error` y conserva su distancia directa.
   Cada ruta trae además las calles por las que pasa (`calles`).
4. Para incidentes lineales o poligonales el destino es el punto del incidente más cercano al recurso.
   La ruta se engancha al punto exacto de la calle más cercana y llega hasta el marcador: se informa
   `ajusteOrigenM`/`ajusteDestinoM` y hay `advertencia` si es ≥ 100 m.

## Un solo camino

Hay una sola ruta por recurso: la **más corta en metros** (el costo de cada calle es su largo), respetando los sentidos de
circulación. Cada ruta informa también su duración estimada. No hay selector de criterio ni en esta consulta ni en el botón "Trazar ruta
al recurso más cercano" del detalle de un incidente (`/eta/incidentes/{id}/recurso-mas-cercano`): ambos son por distancia. El
tiempo de llegada (`/eta/recursos/{r}/incidentes/{i}`) usa siempre el camino más rápido.

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

- No se modelan giros prohibidos ni semáforos (solo una demora fija por esquina en el cálculo por tiempo); la duración usa la velocidad máxima de la calle.
- Sin tráfico en tiempo real. La calidad depende de OpenStreetMap (sentidos, cierres, velocidades).
- Los extremos se enganchan a la calle más cercana (ver `advertencia`).

## Uso en el frontend

Consultas → "Recursos cercanos": elegir incidente y cuántos recursos. Se ven los recursos más cercanos y, con
"Calcular rutas por calles", los recorridos más cortos (verde).
La pantalla ETA muestra además la distancia directa, las advertencias y las calles del recorrido.

En la pantalla ETA (`/eta`, solo administrador) el incidente y el recurso se eligen **con un clic en el mapa** o en un
**desplegable con búsqueda** (al hacer clic en el campo se abre la lista; escribiendo se filtra, sobre todo el sistema:
`GET /consultas/buscar`). Lo elegido queda marcado en el mapa y no se agrupa. Como en las Consultas, no se cargan todos los
objetos: solo los de la parte visible (`CargaPorZona`) y, con el mapa lejos, los dibuja GeoServer.
