# Guion del monitoreo — UrbanSafe

Duración estimada: 10–12 minutos de demo + preguntas. Lo que pidió el tutor: una app con mapa y conexión a
GeoServer, datos geográficos persistidos, explicar el código, ABM, consultas, y cómo se dibujan y guardan
líneas y polígonos. Del monitoreo anterior quedaron además tres pedidos: la **defensa es en Salto** (con datos
en otros lugares del país), el sistema tiene que **aguantar miles de objetos** (el navegador no puede cargarlos
todos) y hace falta un **login básico** que separe vistas.

## 0. Antes de empezar (5 minutos antes)

- Abrir **Docker Desktop**. En `infra/`: `docker compose up -d --build`. Esperar a que `flyway`, `seed`, `red-vial` y
  `geoserver-init` queden en `Exited (0)` (es lo esperado).
  Si la base es vieja (no tiene los datos de Salto y Montevideo, o Flyway da "checksum mismatch"):
  `docker compose down -v` y levantar de nuevo.
- En `frontend/`: `npm run dev`. Abrir:
  - App: <http://localhost:5173>
  - GeoServer: <http://localhost:8082/geoserver> (usuario y clave en `infra/.env`)
  - Postman con `docs/api/urbansafe.postman_collection.json` (correr primero la carpeta 0, que hace el login)
- Comprobar que hay **internet** (mapa de fondo Esri y respaldo de direcciones de la IDE). Las rutas del ETA se calculan en la base, sin internet; la primera vez el servicio `red-vial` baja el extracto de OpenStreetMap de Uruguay (~56 MB).
- Dejar abiertos en el editor: `ConsultaResource.java`, `IncidenteResource.java`, `ZonaResource.java`,
  `ConsultasPage.jsx`, `paneles.jsx`, `CargaPorZona.jsx`, `EditorGeometria.jsx`, `infra/init/geoserver-init.sh`,
  `geoserver/styles/incidentes_estado.sld`.

## 1. La arquitectura en 1 minuto (diagrama: `docs/diagramas/arquitectura.md`)

> "Es una aplicación en capas. El navegador (React + Leaflet) habla con dos cosas: con el **backend**
> JEE/Tomcat por REST, y con **GeoServer** por WMS/WFS. Los dos leen la misma base **PostgreSQL + PostGIS**."

- **Backend (REST + JSON):** ABM, reglas de negocio y consultas. Escribe en la base.
- **GeoServer:** publica las tablas como capas, las dibuja con estilos SLD y responde qué hay bajo un clic.
  **No escribe**: todo lo que se guarda pasa por el backend.
- **PostGIS:** guarda las geometrías y hace los cálculos espaciales.
- **La idea central desde el monitoreo anterior: carga a demanda.** El navegador nunca trae todos los objetos.
  Pide solo los de la parte visible del mapa (`?bbox=&limit=`), con un tope; lo demás lo dibuja GeoServer
  como imagen. Detalle en la sección 3.

## 2. Datos geográficos persistidos (1 minuto)

- Mostrar la base (DBeaver o `docker compose exec db psql -U geotravel -d geotravel`):
  `SELECT id, nombre, ST_AsText(geom) FROM zona_operativa LIMIT 3;`
- Decir: las geometrías están en **SRID 32721 (UTM 21S, en metros)**, así distancias y áreas salen en metros.
  Cada columna tiene un **índice GiST**. La API habla en lon/lat (4326) y el backend convierte con `ST_Transform`.
- `incidente.geom` es de tipo **Geometry**: acepta punto, línea (calle cortada) y polígono (área afectada).
  `SELECT GeometryType(geom), count(*) FROM incidente GROUP BY 1;`
- **Datos:** el seed trae zonas y recursos **reales** (seccionales policiales, municipios, hospitales, mutualistas,
  policlínicas, bomberos, comisarías) en **Salto** (18 zonas, 52 recursos, 114 incidentes) y en **Montevideo** (33 zonas, 271
  recursos, 83 incidentes). Las zonas no son rectángulos. El sistema atiende todo el país; la defensa es en Salto.
- Tablas: `zona_operativa`, `recurso`, `incidente`, `incidente_recurso`, `historial_estado`; de referencia:
  `via` (60.261 calles con nombre de todo el país, de OpenStreetMap) y `acceso` (31.007 números de puerta de Salto), y la red de rutas
  `red_vial_arco` / `red_vial_vertice` (OpenStreetMap de todo Uruguay, con sentidos y velocidades; ver `docs/RED_VIAL.md`).
  Las tablas las crea **Flyway** (`db/migrations`).

## 3. GeoServer y la carga a demanda (3 minutos)

- En el panel: workspace `geotravel`, store PostGIS, capas `zona_operativa`, `recurso`, `incidente`, `via`, `acceso` y `red_vial_arco` (la red de rutas: se ve en el mapa público como "Red de rutas", con flechas en las calles de mano única).
- **Layer Preview** de una capa. Mostrar el estilo SLD (`incidentes_estado.sld`): color por estado, y cada regla
  trae los tres simbolizadores (punto, línea, polígono) para dibujar cualquier forma.
- Mostrar un pedido WMS (GetMap) y uno WFS (`resultType=hits` cuenta sin descargar).
- La configuración no es manual: la hace `infra/init/geoserver-init.sh` por la API REST de GeoServer.
- **Cómo se combinan GeoServer y el front (la regla del zoom):**
  - **Lejos** (por debajo del zoom mínimo: 13 en los ABM, 11 en Consultas): el front no pide nada y GeoServer
    dibuja las capas como imágenes. Se ve todo, pero no se edita ni se elige.
  - **Cerca:** el front pide solo los objetos del rectángulo visible, hasta 500
    (`GET /zonas?bbox=oeste,sur,este,norte&limit=500` → `{items, total, truncado}`) y los dibuja él, porque
    tienen que ser clickeables. Ese tipo deja de dibujarlo GeoServer para que no se vea doble.
  - Si hay más de 500 en la vista, avisa "Mostrando 500 de N: acercá el mapa".
  - El mapa muestra el **zoom actual** y desde cuál se ven los objetos; hay botones **"Ir a Salto / Montevideo"**.
- Escala: el filtro `geom && ST_MakeEnvelope(...)` usa el índice GiST, y las zonas se simplifican 3 m al devolverlas.

## 3b. Dos vistas: invitado y administrador (1 minuto)

- Abrir la app **sin ingresar**: es la vista de invitado y muestra el **mapa público** y las **Consultas** (el menú tiene dos opciones;
  el reporte de incidentes y la edición son solo del administrador).
- Intentar abrir `/zonas`: manda a la pantalla de ingreso.
- Ingresar como administrador (`admin` / `urbansafe`, ver `infra/.env`): aparecen zonas, recursos, incidentes,
  tiempo de llegada y el reporte de incidentes.
- Explicar: `POST /auth/login` devuelve un token (8 horas, en memoria del backend) que el frontend manda en cada
  pedido; un filtro del backend (`AuthFilter`) protege toda la API por defecto y solo deja públicos unos pocos
  endpoints, todos de lectura (los de las Consultas del invitado). El mapa público dibuja con GeoServer, que no pasa por la API.

## 4. Mapa público (vista Invitado) (2 minutos)

- Encender/apagar capas y mostrar los **conteos**: son WFS contra GeoServer y son **de lo que se ve**: al mover el
  mapa, el rectángulo visible entra al filtro como `BBOX(geom, ...)`, que usa el índice espacial.
- **Filtros** de incidentes (tipo, estado, prioridad, fechas) y de recursos: se mandan como `cql_filter`;
  filtra GeoServer, no el navegador.
- **Clic** sobre un incidente o un recurso: detalle por WMS `GetFeatureInfo`. Si hay una zona debajo, no se lista: la zona se consulta haciendo clic donde no hay puntos.
- Activar **Calles** y hacer clic en una calle de Salto (por ejemplo, Uruguay): se resalta entera
  (el clic trae un tramo y se piden todos los de ese nombre por WFS).
- **Alejar el mapa:** los incidentes y recursos que quedan juntos se **agrupan con un número** (como en Airbnb); al acercar
  (zoom 13) se ven los íconos. Cuenta también las líneas y polígonos de incidentes. Lo agrupa GeoServer
  (`vec:PointStacker` en el SLD); en las pantallas donde dibuja el navegador, `leaflet.markercluster` (ver `docs/ICONOS.md`).
- Usar "Ir a Montevideo" para mostrar que hay datos allá también.

## 5. ABM y cómo se dibuja y guarda (3 minutos)

- En **Zonas**: dibujar un polígono (barra de dibujo de Leaflet-draw), completar los datos y guardar.
- Explicar el recorrido: dibujar → Leaflet genera un **GeoJSON** → `POST /zonas` → el backend valida
  (`ST_IsValid` y que sea un polígono) →
  `ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)` → INSERT. Código: `ZonaResource.java`.
- Las zonas **pueden superponerse** (lo definió el tutor): dibujar una que se superponga con una seccional de Salto y mostrar que
  se guarda. Consecuencia: un punto, un recurso o un incidente puede estar en más de una zona (hay zonas superpuestas
  en el seed: "Salto (localidad)" y "Termas del Daymán (localidad)" con las seccionales, y los municipios de Montevideo).
- **Incidentes con línea y polígono:** "Registrar incidente", elegir **Línea** y dibujar una calle cortada (un clic
  por vértice; el último, otra vez para terminar). Guardar, abrirlo, "Editar datos y ubicación", cambiarlo a
  **Polígono** y guardar; eliminar uno. Es el mismo `POST /incidentes` con otro tipo de GeoJSON: la columna es
  `Geometry`. El backend rechaza lo que no sea punto, línea o polígono, o no sea válido (`ST_IsValid`).
- **Avanzar estado**: Registrado → En atención → Resuelto, con historial. El historial guarda el **usuario de la sesión** (el que ingresó),
  no un texto que se escriba: no se puede falsear.
- **Recurso más cercano (opcional de la letra):** en el detalle de un incidente, "Trazar ruta al recurso más cercano". PostGIS toma los
  recursos más cercanos en línea recta (`<->`, por defecto 5 y solo los disponibles) y pgRouting calcula la ruta por calles de cada uno.
  "Más cercano" es el de **menos metros** por calles: gana ese y se dibuja su recorrido. (Medir por minutos daría otro resultado:
  en la prueba, 24 de 40 caminos eran distintos; por eso se eligió metros.)
  Límite a decir: solo se comparan los primeros N en línea recta.
  Código: `RecursoMasCercano.java`, `RutaRecursoCercano.jsx`. La consulta 3 hace algo parecido: los N más cercanos, con el camino más corto.
- Recursos (tipo, estado operativo): el punto se ubica con un clic.
- Mostrar el aviso **"Acercá el mapa"** y el indicador de zoom al alejarse: ahí aparece GeoServer.
- **Tiempo de llegada** (P2): se elige el incidente y el recurso con un **clic en el mapa** o en un **desplegable con búsqueda** (clic en el
  campo y escribir); lo elegido queda marcado. Carga a demanda como las Consultas. Calcula la ruta por calles con pgRouting (red vial de OpenStreetMap de todo Uruguay, con sentidos y velocidades) y la dibuja en verde, con distancia, minutos y las calles por las que pasa.
- Después de guardar, el objeto aparece en el mapa público: GeoServer lee la misma tabla.

## 6. Consultas geográficas (3 minutos) — pantalla "Consultas"

Cómo se usan: se ven en el mapa y en la lista los objetos de la **parte visible** (zonas, incidentes o recursos
según la consulta), se **elige uno con un clic** (en el mapa o en la lista) y se dibuja y lista el resultado.
Cada consulta pide a GeoServer de fondo solo el tipo de objeto con el que trabaja.
Las ve también el **invitado** (sin ingresar). Al pie del panel, "¿Qué significa cada ícono?" muestra la misma leyenda del mapa público.

| N.º | Qué mostrar | Cómo se elige | PostGIS |
|---|---|---|---|
| 1 | Incidentes de una zona | Zonas de la vista | `ST_Intersects` (cuenta líneas y polígonos que tocan la zona) |
| 2 | Zonas con mayor cantidad de incidentes | Ranking de las zonas visibles; elegir una muestra sus incidentes | `ST_Intersects` + `COUNT` con `LEFT JOIN` |
| 3 | Recursos operativos (Disponible) cercanos a un incidente | Incidentes de la vista | operador `<->` (vecino más cercano), `ST_Distance`, pgRouting |
| 4 | Incidente más cercano a un punto | Clic, dirección o cruce | `<->` |
| 5 | Zonas de un punto (pueden ser varias) | Clic, dirección o cruce | `ST_Contains` |
| 6 | Recursos por zona | Zonas de la vista | `ST_Contains` |
| 7 | Incidentes por recurso | Recursos de la vista | tabla `incidente_recurso` |

- **Consulta 3 (P2 y P5):** "localizar los recursos más cercanos": elegido el incidente, se elige **cuántos recursos** (1 a 10) y
  se muestran los más cercanos, cada uno con su **distancia directa** (`<->` ordena por cercanía con el índice espacial; no hay
  radio ni buffer). Con "Calcular rutas por calles" se pide el **recorrido** de los más cercanos (verde) con pgRouting: el
  **camino más corto** por calles, con distancia y minutos, y la insignia "Más cercano por calles" en el de menor distancia.
  Elegir un recurso lo resalta en el mapa. Por defecto solo cuentan los **Disponibles** (operativos).
- **Consulta 5:** devuelve **todas** las zonas que contienen el punto (las zonas se superponen); probar `Uruguay 1000`.
- Íconos (`docs/ICONOS.md`): en los recursos la forma dice el tipo y el color, el estado (sobre un círculo); en los
  incidentes puntuales también (sobre un rombo): auto, llama, rayo, olas, paso prohibido o exclamación según el tipo.
  Al registrar un incidente, el tipo se elige entre esos íconos. Los mismos SVG los usa GeoServer.
- En 4 y 5 **no se cargan** los objetos de la vista a propósito: el incidente más cercano puede quedar afuera de lo
  que se ve, y mostrar solo los visibles daría una respuesta engañosa. Se muestra solo el resultado.
- En 4 y 5 mostrar las **tres formas de elegir el punto**: clic, **dirección** (`Uruguay 1000`,
  `Gral Fructuoso Rivera 500`) y **cruce de calles** (`Uruguay` y `Yatay`).
- Explicar la dirección: en Salto la busca en la tabla `acceso` (números de puerta, publicada también como capa
  de GeoServer), normalizando el texto (`Av.` = AVENIDA) y tolerando errores de tipeo (`pg_trgm`). Si no la
  resuelve, si es una esquina o si es de otro departamento, usa el servicio de direcciones de la **IDE**.
  El buscador arranca en **Todo el país**: si la calle no está en Salto, la IDE la busca en los 19 departamentos y se ubica la mejor
  coincidencia (probar `Minas 2091`, que está en Montevideo; las otras "Minas" salen como alternativas).
- Reporte por zona con filtros (zona, tipo, prioridad, estado, fechas). La zona se elige con un clic en el mapa, como en la consulta 1, o escribiendo su nombre.
- Usar "Ir a Montevideo" y repetir una consulta: funciona igual con datos de otro lugar.

## 6b. pgRouting: qué es y cómo lo hicimos (5 minutos)

> "Para el **tiempo de llegada**, el **recurso más cercano** y la **consulta 3** necesitamos saber por dónde se llega de verdad:
> un recurso a 300 m en línea recta puede estar al otro lado de un río, o contra una mano única. Eso lo resuelve **pgRouting**,
> una extensión de PostgreSQL/PostGIS que trae algoritmos de grafos, entre ellos **Dijkstra** (el camino de menor costo).
> Corre **dentro de la base**, sobre las calles de OpenStreetMap de **todo Uruguay**."

La idea en una línea: **las calles son un grafo**. Cada esquina es un **vértice**, cada tramo de calle entre dos esquinas es un **arco**
con un **costo** (metros o segundos), y Dijkstra busca el camino de menor costo entre dos vértices.

### Cómo se hizo, en 5 etapas

**1. De dónde salen las calles (OpenStreetMap, una sola vez).** El servicio `red-vial` (`infra/red-vial/`) baja el extracto de Uruguay de
Geofabrik (`uruguay.osm.pbf`, ~56 MB) y `red_vial_osm.py` lo procesa:
- se queda con las vías por las que se puede circular (`highway`: autopista, ruta, avenida, calle secundaria, calle, servicio) y descarta
  las peatonales, las sendas, los caminos sin pavimento y las privadas;
- **corta cada vía en las esquinas** (un nodo que comparten dos o más vías) para tener un tramo por esquina;
- anota de cada tramo el nombre, el tipo, la velocidad máxima (`maxspeed`), el número de ruta (`ref`) y el **sentido** (doble mano, mano única,
  o al revés).
Deja todo en un CSV y `cargar.sh` lo carga en la base. Si el grafo ya está armado, no hace nada: no repite ni necesita internet.

**2. Se arma el grafo (`db/sql/red_vial_generar.sql`).** Tablas `red_vial_vertice` (150 mil esquinas) y `red_vial_arco` (216 mil tramos, 40 mil de
mano única), con índice espacial. Cada arco guarda dos costos:
- **metros** = el largo del tramo;
- **segundos** = largo / velocidad + 3 s por esquina. La velocidad es la `maxspeed` de OSM si la tiene y, si no, un valor por tipo de vía
  (autopista y ruta 90 km/h, avenida principal 70, secundaria 55, calle 40, servicio 20).
- **Mano única:** el sentido prohibido lleva costo **−1**, que es la convención de pgRouting para "no se puede pasar por acá". Así Dijkstra
  respeta los sentidos sin código extra.
- Se marcan los arcos que forman una red conectada de 50 arcos o más, para no engancharse a una calle aislada a la que no llega nadie.

**3. La función `p2_calcular_ruta` (`db/sql/p2_rutas_pgrouting.sql`).** Recibe origen, destino y un criterio, y devuelve distancia, duración,
la geometría (GeoJSON) y las calles del recorrido. Por dentro, en 5 pasos:
1. **Ajuste a la calle:** cada punto se proyecta sobre la calle más cercana (hasta 500 m; más lejos, "sin ruta") y se **corta ese arco con un
   vértice virtual** (−1 y −2). La ruta sale y llega al punto exacto de la calle, no a la esquina más próxima, y se suma el tramo recto
   corto entre el recurso o el incidente y la calle.
2. **Dijkstra dirigido** (`pgr_dijkstra`) entre los dos vértices virtuales, minimizando **metros** (`distancia`) o **segundos** (`tiempo`).
3. **Escala:** no arma el grafo del país en cada pedido. Usa solo los arcos de una caja alrededor de los dos puntos (3 km, después 20 km,
   después sin límite), con índice espacial.
4. **Resultado:** el camino ordenado por `seq`, su geometría y las calles por las que pasa, con los metros de cada una.
5. **Errores claros:** sin camino → "sin ruta"; si se pasa del plazo → "plazo agotado". No se cuelga.

**4. Cómo la usa el backend.** `MotorPgRouting` llama a la función y `RutaService` le pone un plazo y traduce los errores. La usan tres cosas:
- **Tiempo de llegada** (`/eta`): criterio **tiempo**.
- **Recurso más cercano** (opcional de la letra): PostGIS toma los 5 más cercanos en línea recta (`<->`) y pgRouting calcula la ruta de cada uno;
  gana el de **menos metros** por calles (criterio **distancia**).
- **Consulta 3:** los N más cercanos (`<->`), con el camino más corto por calles de hasta 5 y la insignia "Más cercano por calles".

**5. Decisiones y un problema que resolvimos.**
- **OSRM → pgRouting.** OSRM era un servicio aparte, preprocesado por región (solo Salto) y sin respetar los sentidos. pgRouting vive en la base,
  se combina con las zonas, los recursos y los incidentes, y cubre todo el país.
- **Metros y no minutos para "más cercano".** En la prueba, 24 de 40 caminos eran distintos según el criterio; "más cercano" se entiende como el
  de menos metros, y el tiempo de llegada sigue por minutos.
- **El bug de las "vueltas de más".** Algunas rutas dibujaban un zigzag. La causa: en pgRouting 4 el primer tramo repite `path_seq`, y el
  camino se ordenaba por esa columna. Se corrigió ordenando por `seq` y quedó una prueba de regresión.

### Qué mostrar en vivo

1. **En la app:** Incidentes → un incidente → "Trazar ruta al recurso más cercano": se ve el recorrido, los minutos, los metros por calles y los metros
   en línea recta, "Los otros recursos evaluados" y "Calles del recorrido".
2. **En la base (DBeaver o `docker compose exec db psql -U geotravel -d geotravel`):** la misma ruta con los dos criterios. Con el recurso
   `CEN-S001` y el incidente 60 dio, en la prueba de hoy:

   | Criterio | Metros | Minutos |
   |---|---|---|
   | `distancia` | 5.968 | 11,0 |
   | `tiempo` | 6.089 | 10,1 |

   El camino más corto no es el más rápido: el otro va por calles más largas pero más veloces.
3. **La red:** `SELECT highway, count(*) FROM red_vial_arco GROUP BY 1 ORDER BY 2 DESC;` y, en el mapa público, la capa "Red de rutas" (colores por
   tipo de vía y flechas en las calles de mano única).
4. **Una mano única:** la ruta de ida y la de vuelta entre los mismos puntos son distintas.

### Cómo diferenciamos ruta, avenida y calle

No hay una capa para eso: lo trae OpenStreetMap en el campo `highway`. De ahí salen la **velocidad** (90 km/h `trunk`, 70 `primary`, 55 `secondary`,
45 `tertiary`, 40 `residential`, 20 `service`), el **color** de la red en el mapa y el nombre que se ve al tocar un tramo. La **Ruta 5** y la
**Ruta 3** son ~1.200 y ~850 tramos `trunk` con `ref` 5 y 3. El número de ruta se guarda pero **no se usa para elegir el camino**: el camino sale
del costo. Con el criterio de tiempo las rutas ganan solas porque a 90 km/h tardan menos que las calles a 40.

### Cómo lo probamos

- **13 pruebas de integración de PgRouting** (`PgRoutingIntegrationTest`), entre ellas la de las vueltas de más, y las del recurso más cercano y la
  consulta 3. La suite completa del backend tiene 108 pruebas.
- **396 de 396 rutas** entre recursos e incidentes dieron resultado.
- Una ruta de ~6 km tarda décimas de segundo (en la prueba de hoy, dos rutas en 0,5 s en total).

### Límites (decirlos nosotros)

- Sin **giros prohibidos**, **semáforos** ni **tránsito en vivo**: solo una demora fija de 3 s por esquina. El tiempo es una **estimación**.
- La calidad es la de OpenStreetMap: velocidades y sentidos dependen de lo que esté cargado; donde falta `maxspeed` se usa el valor por tipo.
- **Un incidente de tipo "calle cortada" no se saca de la red:** la ruta podría pasar por esa calle. Es una mejora posible.
- Solo se comparan los primeros N recursos en línea recta; el más cercano por calles podría quedar afuera si hay muchos "falsos cercanos".
- La primera vez, `red-vial` baja el extracto de OSM (~56 MB); después **las rutas no necesitan internet**.

## 7. Mostrar el código (si lo piden)

- `db/sql/p2_rutas_pgrouting.sql` (la función de rutas) y `db/sql/red_vial_generar.sql` (el grafo); `RutaService.java`, `MotorPgRouting.java` y
  `RecursoMasCercano.java` (el backend); `infra/red-vial/red_vial_osm.py` (de OpenStreetMap a arcos).
- `ConsultaResource.java`: una consulta completa (por ejemplo `recursos-cercanos/{id}/analisis-vial`: vecino más cercano con `<->` y rutas por distancia, en `AnalisisVial.java`).
- `ConsultasPage.jsx` y `paneles.jsx`: cada consulta es un panel que elige un objeto de la vista y pide al backend.
- `CargaPorZona.jsx`: la carga a demanda (espera, cancela el pedido anterior, reemplaza lo de la vista).
- `EditorGeometria.jsx` e `IncidenteResource.java`: dibujo de punto, línea y polígono, y su validación.
- `ZonaResource.java`: guardado de polígonos y su validación (válido y de tipo polígono; se pueden superponer).
- `geoserver-init.sh` y un SLD: configuración de GeoServer.

## Preguntas que pueden hacer

**¿Por qué el guardado no va por GeoServer (WFS-T)?**
Porque las reglas de negocio (validación de geometrías, máquina de estados de incidentes) viven en el backend,
en la capa de negocio. GeoServer publica y dibuja lo guardado. El teórico presenta las dos formas: modificar
por WFS Transaccional o por SQL contra la geo-base. Si prefieren WFS-T, el cambio es del lado del cliente.

**¿Qué hace cada componente?**
PostGIS guarda y calcula; el backend aplica reglas y expone REST; GeoServer publica capas (WMS, WFS) y las estiliza;
el front dibuja y consulta.

**¿Por qué usan GeoServer y también REST?**
Cada uno hace lo que mejor sabe. GeoServer dibuja miles de objetos rápido como imágenes, pero no son
clickeables ni editables. El REST trae los objetos reales para elegirlos, editarlos y calcular sobre ellos.
Se combinan según el zoom: lejos, imágenes; cerca, objetos.

**¿Cómo escala con muchos puntos?**
El navegador nunca carga todos: pide solo los del rectángulo visible, con un tope (500 por defecto, 2.000
máximo) y avisa si quedaron afuera (`truncado`). El filtro usa el índice GiST. Lejos, los dibuja GeoServer.
Antes las pantallas traían todo por REST: eso era lo que no escalaba. Se midió con 100.000 incidentes, 30.000 recursos y
5.000 zonas: los listados por rectángulo responden en menos de 100 ms y GeoServer dibuja en menos de 130 ms. Los listados sin
rectángulo también tienen tope, las calles y los barrios de fondo salen del caché de GeoServer y cada consulta tiene un plazo
de 15 s. Lo que sigue siendo lento: dirección fuera de Salto (servicio externo de la IDE, 0,4 a 0,9 s) y las consultas que
cruzan todas las zonas con todos los incidentes (~250 ms con 5 mil por 100 mil). Detalle en `docs/CARGA_POR_ZONA.md`.

**¿Y si el front "guarda" todo?**
No guarda nada de forma permanente. Todo vive en PostGIS y se guarda a través del backend. El navegador
solo tiene en memoria lo que está mostrando (hasta 500 objetos) y el resultado de la consulta.

**¿Cómo se guarda una línea o un polígono de un incidente?**
En la misma columna `incidente.geom` (`Geometry`). Las consultas funcionan igual porque `ST_Intersects`,
`ST_Distance` y `<->` sirven para cualquier forma.

**¿Por qué pgRouting y no OSRM?** OSRM es más rápido, pero es un servicio aparte y necesita un preprocesamiento por región (solo
habíamos hecho Salto). pgRouting vive en la base, se combina con el resto de PostGIS (zonas, recursos, incidentes) y cubre todo el
país sin trabajo extra. Para nuestro volumen la velocidad alcanza. La comparación está en el artículo.

**¿Cómo funciona la dirección?** Ver sección 6. Los datos de calles del curso no traen numeración; por eso se
usan números de puerta propios de Salto. Montevideo y otros departamentos usan la IDE.

**¿Por qué hay datos en Montevideo si la defensa es en Salto?**
El sistema atiende todo el país; tiene que haber datos en otro lugar. No hay puertas propias de
Montevideo (sus direcciones las resuelve la IDE); las calles, los incidentes y las rutas sí usan la red de todo el país.
Las zonas y los recursos de ahí son reales (seccionales, municipios, hospitales, mutualistas, policlínicas).

**¿Qué mapa de fondo usan?**
Esri Light Gray (gratis, sin clave), no OpenStreetMap; necesita internet. Las capas de zonas, recursos,
incidentes, calles y puertas salen de nuestro GeoServer. Las calles de la base sí vienen de OpenStreetMap.

**¿Qué pasa sin internet?** El mapa de fondo queda gris y no anda el respaldo de la IDE (direcciones fuera de Salto).
Las capas de GeoServer, las consultas, el ABM, las **rutas** (se calculan en la base), las direcciones con número de Salto y el cruce de calles
siguen funcionando.

**¿Cómo se levanta todo?** `docker compose up -d --build`. Flyway crea las tablas, `seed` carga calles, puertas y
datos de prueba (Salto y Montevideo), y `geoserver-init` crea capas y estilos.

## Qué no afirmar

- No decir que el guardado es por GeoServer: es por el backend.
- No decir que el **control de superposición de zonas** está hecho: no va, las zonas se pueden superponer (lo definió el tutor).
  Los otros tres opcionales sí están: el **tiempo estimado de llegada** (pantalla `/eta`) y el **recurso más cercano** usan pgRouting sobre la
  red de OpenStreetMap de todo Uruguay, pero sin giros prohibidos, semáforos ni tránsito en vivo (ver `docs/RED_VIAL.md`); y el **mapa de
  calor** está en el mapa público.
- No decir que la dirección sale 100 % de capas propias: el respaldo de la IDE y el mapa de fondo usan internet.
- No decir que hay puertas de Montevideo: la tabla `acceso` es solo de Salto (allá la dirección sale de la IDE). Las calles, los cruces y las rutas sí son de todo el país.
- No decir que los nombres de calle de `via` y `acceso` están unificados (son dos fuentes; el 78 % de las puertas
  tiene su calle en `via`).

## Plan B

- Sin internet: seguir con la demo; cambia el fondo del mapa (gris) y las direcciones de fuera de Salto. Las rutas siguen andando.
- GeoServer no responde: las consultas y los ABM siguen andando (el front dibuja lo visible); solo faltan el fondo
  de imágenes y el mapa público. Mostrar también la API en Postman.
- El backend no responde: `docker compose up -d --build backend` y esperar unos 30 segundos. Después hay que volver
  a ingresar (las sesiones viven en memoria).
- Base vacía o vieja: `docker compose down -v` y volver a levantar (recarga calles, puertas y datos de prueba de
  Salto y Montevideo). **Esto borra todo lo que se hubiera cargado a mano.**
