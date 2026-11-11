# Red vial y rutas por calles (pgRouting)

La ruta entre un recurso y un incidente (pantalla **Tiempo de llegada** y consulta 3 con "Calcular rutas por calles") la
calcula **pgRouting dentro de PostgreSQL**, sobre una red vial de **OpenStreetMap de todo Uruguay**. No hay ningún servicio
de rutas externo: no hace falta internet para calcular (sí para bajar el extracto la primera vez).

## Qué datos de calles hay y cuál se usa

Se investigaron todas las fuentes a mano. Para rutear hacen falta cuatro cosas: la geometría de cada tramo, su **sentido de
circulación**, su **velocidad** y que **estén cortados en las esquinas**.

| Fuente | Cubre | Sentido | Velocidad | Cortada en esquinas | Se usa |
|---|---|---|---|---|---|
| Tabla `via` del proyecto (OpenStreetMap, solo calles con nombre; 60.261 vías) | **todo el país** (arranca con Salto y `red-vial` la completa) | no | no | no (cada fila es una calle entera) | solo para la capa "Calles" del mapa (y su resaltado al hacer clic) |
| **OpenStreetMap completo** (extracto de Geofabrik) | **todo el país** | **sí** (`oneway`, rotondas, autopistas) | **sí** (`maxspeed`) en parte; el resto por tipo de vía | **sí** (nodos compartidos) | **sí: es la red de pgRouting** |
| `v_sig_vias` (IDE Uruguay, curso) | todo el país | no | no | no | no (solo nombre, tipo y geometría) |
| `v_camineria_nacional` (MTOP) | rutas y caminos | sí (88 tramos de mano única cerca de Salto) | no | no | no: no trae las calles de las ciudades (solo rutas, conexiones y caminería departamental) |
| Geoportal de la Intendencia de Salto, capa "Ejes de Calles" (ArcGIS, 4.811 tramos) | solo Salto | no | no | no | no: solo nombre, tipo de cubierta, tipo de camino y borde |
| Números de puerta (`acceso`) | Salto | | | | no para rutear: sirven para ubicar una dirección |

**Por qué OpenStreetMap:** es lo único con sentidos y velocidades, cubre todo el país (el tutor pidió que el sistema atienda
todo el país, aunque la defensa sea en Salto) y la tabla `via` sale de ahí. `via` descarta justo lo que hace falta
para rutear: el sentido único (976 vías en el rectángulo de Salto), la velocidad máxima, las rotondas, los puentes y las
**2.647 vías sin nombre** (calles de servicio y conexiones). Sin sentidos, una ruta puede ir en contra del tránsito.

## Cómo se arma la red

```
infra/red-vial/data/uruguay.osm.pbf   (56 MB, Geofabrik; lo baja el servicio la primera vez)
        │  infra/red-vial/red_vial_osm.py   (pyosmium + numpy)
        ▼
infra/red-vial/data/red_vial.csv.gz   (un arco por fila, de esquina a esquina)
        │  infra/red-vial/cargar.sh  +  db/sql/red_vial_generar.sql
        ▼
red_vial_vertice (150 mil esquinas)  y  red_vial_arco (216 mil arcos, 40 mil de mano única)
```

- **Servicio `red-vial`** (`infra/docker-compose.yml`): corre al levantar, tarda un par de minutos la primera vez y después no
  hace nada. Rehacerla: `docker compose run --rm -e RED_VIAL_REGENERAR=1 red-vial`.
- **Qué entra:** autopistas, rutas, avenidas, calles y calles de servicio con sus enlaces. Quedan afuera las privadas
  (`access=private|no`), los accesos a casas y playas de estacionamiento, las peatonales, las sendas y los caminos rurales sin pavimento.
- **Esquinas:** un nodo de OpenStreetMap que comparten dos o más vías es un vértice; cada arco va de un vértice al siguiente.
  Dos vías que se cruzan sin compartir nodo (un puente) **no se conectan**, como en la realidad.
- **Sentido:** una vía de mano única va de `source` a `target` y la vuelta tiene costo negativo (la convención de pgRouting
  para "prohibido"). Las rotondas y las autopistas son de mano única aunque no lo diga la etiqueta.
- **Costos:** metros = largo del arco. Segundos = largo / velocidad + 3 s por esquina. Velocidad: la `maxspeed` de OpenStreetMap
  y, si falta, un valor por tipo de vía (autopista y ruta nacional 90 km/h, avenida principal 70, secundaria 55, calle 40, calle
  de servicio 20; está en `db/sql/red_vial_generar.sql`). Los metros (`cost_m`) quedan en la tabla pero la ruta no los usa.
- **Redes conectadas:** se marcan con `pgr_connectedComponents` y solo las de 50 arcos o más (`componente_grande`) reciben
  los extremos de una ruta, para no enganchar un punto a una calle aislada a la que no llega nadie.
- **Tablas:** `red_vial_vertice`, `red_vial_arco` (migraciones `V5` y `V6`). Se publican con el contrato de pgRouting
  (`id, source, target, cost, reverse_cost`), más el nombre, el tipo de vía, la velocidad y si es de mano única.

## Cómo se calcula una ruta (`p2_calcular_ruta`, `db/sql/p2_rutas_pgrouting.sql`)

1. **Ajuste a la calle.** Cada extremo (el recurso y el punto del incidente más cercano al recurso) se engancha al **punto
   exacto** de la calle más cercana, no a la esquina más próxima: se corta virtualmente ese arco y el punto pasa a ser un vértice
   (`ST_LineLocatePoint`). La ruta sale y llega a ese punto, y hay un tramo recto corto (el "conector", hasta 500 m) entre el
   marcador y la calle, que cuenta en la distancia y el tiempo (a 20 km/h). Si un extremo queda a más de 500 m de cualquier calle,
   no hay ruta. El ajuste se informa (`ajusteOrigenM`, `ajusteDestinoM`) y, si es de 100 m o más, hay una advertencia.
2. **Sentidos.** Dijkstra dirigido (`pgr_dijkstra`): no se circula contra una mano única.
3. **Un solo camino.** Se minimiza el tiempo (`cost_s`). La distancia informada es la suma de los largos de ese camino.
4. **Escala.** Para no armar el grafo de todo el país en cada pedido, solo se usan los arcos dentro de una caja alrededor de los
   dos puntos (con índice GiST), que se agranda si no aparece camino. Con la red de Uruguay, una ruta en la ciudad tarda unos
   25 ms y Salto–Montevideo (490 km) un par de segundos.
5. **Las calles del recorrido.** La respuesta trae, en orden, el nombre de cada calle por la que pasa y cuántos metros
   (`calles`), que la pantalla muestra como "Calles del recorrido".

Respuesta de `GET /eta/recursos/{r}/incidentes/{i}` (resumen): `distanciaMetros`, `duracionSegundos`,
`tiempoEstimadoMinutos`, `geometriaRuta` (GeoJSON LineString lon/lat), `calles`, `ajusteOrigenMetros`, `ajusteDestinoMetros`,
`advertencia`, `motor` (`pgRouting (PostgreSQL)`).

## Cómo se ve en el mapa

La red es una capa de GeoServer (`red_vial_arco`, estilo `geoserver/styles/red_vial.sld`) y está en el mapa público como
**"Red de rutas"** (apagada por defecto, como "Calles"): color y grosor según el tipo de vía, **flechas en las calles de mano única**
(en el sentido permitido) y el nombre de la calle al acercar. Con un clic se ve el detalle del tramo (nombre, tipo, velocidad,
sentido). Sirve para mostrar por dónde puede ir una ruta y por qué no va contra el tránsito.

## Cruces de calles en todo el país

La misma red sirve para ubicar el cruce de dos calles (`GET /consultas/interseccion`) y para el autocompletado de nombres
(`GET /consultas/calles`), en todo Uruguay y sin internet. Un cruce es un vértice del grafo al que llegan un tramo de cada calle;
dos calles que se superponen sin compartir nodo (un puente) no se cruzan. Los nombres se normalizan (`normalizar_calle`: sin
tildes, mayúsculas ni puntuación; lo escrito además expande las abreviaturas, Av. = AVENIDA). Si la calle se repite en varias
localidades, se devuelven hasta 10 cruces ordenados por cercanía a la región, cada uno con el lugar más próximo (tabla `lugar_osm`,
que el servicio `red-vial` carga del mismo extracto: 1.353 ciudades, pueblos y barrios). La tabla `via` no interviene: es solo la capa "Calles" del mapa, que el mismo servicio carga con las 60.261 vías con nombre del país (una fila por vía entera).

## Qué hace el backend

`MotorPgRouting` llama a la función por JDBC (con plazo de 10 s) y `RutaService` la comparte entre el ETA y la consulta 3.
`GET /eta/disponible` informa si se pueden calcular rutas: pgRouting instalado, función presente y red vial cargada
(se cachea 5 s). Si falta algo, la pantalla lo avisa y deshabilita el botón; no hay otro motor de respaldo.

## El recurso más cercano a un incidente, por las calles

Desde el detalle de un incidente (pantalla **Incidentes**), el botón **"Trazar ruta al recurso más cercano"** busca el recurso más
cercano por las calles y dibuja su recorrido en el mapa. Se elige qué significa "más cercano": **más corto** (menos metros, por
defecto) o **más rápido** (menos minutos). Lo resuelve `GET /eta/incidentes/{id}/recurso-mas-cercano` (`RecursoMasCercano.java`):

1. **PostGIS** toma los N recursos más cercanos **en línea recta** (por defecto 5, solo los disponibles; operador `<->`, que usa el
   índice espacial). El incidente puede ser un punto, una línea o un polígono: la distancia es a su geometría y el destino de cada ruta
   es el punto del incidente más próximo al recurso.
2. **pgRouting** calcula la ruta de cada uno (`p2_calcular_ruta`, la misma función que el tiempo de llegada) minimizando el
   **criterio** pedido (`criterio=distancia`, por defecto, o `criterio=tiempo`) y gana el mejor. Con `distancia`, Dijkstra minimiza los
   metros (`cost_m`) y gana el de menor distancia por calles; con `tiempo`, minimiza los segundos (`cost_s`) y gana el que llega
   antes. En un empate decide el otro dato.

Las dos cosas pueden dar recursos y caminos distintos: una avenida más larga puede tardar menos, y una mano única obliga a dar
vueltas. En una prueba con 40 pares recurso-incidente de Salto, el camino más corto y el más rápido fueron distintos en 24; el más
corto ahorró 64 m en promedio y el más rápido, 18 s. Con cualquiera de los dos criterios se informan la distancia y el tiempo del
camino elegido.
Hace falta el segundo paso porque el más cercano en línea recta no siempre es el que llega antes: un recurso a 300 m al otro lado de
una avenida sin cruce, un arroyo o una mano única puede tardar más que otro a 800 m. La respuesta incluye también los otros recursos
evaluados con su tiempo (o el motivo por el que no tienen ruta) y las calles del recorrido. Las rutas se piden de a una y con un plazo
total de 25 s; si el motor no responde, no se insiste con las demás. Con `soloDisponibles=false` se consideran todos los recursos.

## Límites (para decirlos antes de que los encuentren)

- **No hay giros prohibidos ni semáforos** (solo una demora fija por esquina) ni tránsito en vivo: los tiempos son estimaciones
  sin tráfico y algo optimistas.
- **La calidad es la de OpenStreetMap:** sentidos únicos, cierres y velocidades dependen de lo que esté cargado. Donde no hay
  `maxspeed` se usa un valor por tipo de vía.
- Es una red para **autos**: no hay prioridad para vehículos de emergencia ni se usan los carriles.
- Los extremos que quedan a más de 500 m de una calle no tienen ruta (por ejemplo, un punto en el río).
- Cobertura: todo lo que traiga el extracto de Uruguay. Para otro país habría que cambiar el extracto.

## Pruebas

`backend/src/test/java/.../eta/PgRoutingIntegrationTest.java` (12 pruebas): la ruta sale y llega a los puntos pedidos, informa
las calles, funciona en Montevideo y entre ciudades, un par en el mar no tiene
ruta y el plazo agotado se traduce. Se activan con `URBANSAFE_PGROUTING_TESTS=true` y la base apuntada por `DB_HOST`/`DB_PORT`
(con la red vial ya cargada). Medido sobre 400 pares recurso–incidente (300 de Salto y 100 de otras zonas, `setseed(0.42)`): 99 % con
ruta; los 4 que no la tienen son dos incidentes del seed escritos a mano en Termas del Arapey y San Antonio, a más de 500 m de una calle.

© Colaboradores de OpenStreetMap, licencia ODbL.
