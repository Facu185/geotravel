# Guion de la defensa — UrbanSafe (4 personas, 20 minutos)

Pautas del curso: máximo 20 minutos, ppt breve (con objetivo y conclusiones) más demo del producto, y después preguntas a **todos** los integrantes.
El guion sigue el ppt `UrbanSafe_defensa_editada.pptx` (11 diapositivas). Está dividido en cuatro partes y la demo es la última.

## Las cuatro partes

Cuatro partes, en este orden. **La demo es la última y la da una sola persona.** Quién da cada parte lo deciden ustedes: el guion está escrito por partes, no por nombres.

| Parte | Qué | Diapositivas | Tiempo |
|---|---|---|---|
| **1** | Apertura: portada, índice, objetivo y qué hace | 1 a 4 | 3 min |
| **2** | Arquitectura, datos y escala | 5 a 7 | 3,5 min |
| **3** | Rutas con pgRouting | 8 y 9 | 3 min |
| **4** | Demo en vivo (una sola persona) y conclusiones | 10 y 11 | 10 min |

Total: unos **19 min 30 s**, con margen para ajustar. Después, preguntas a todos.

Sugerencia de reparto, por módulo: la parte 1, quien hizo los ABM; la 2, quien hizo datos y GeoServer; la 3, quien hizo las rutas; y la 4 (la demo), quien conozca mejor el mapa público, las consultas y las direcciones, que son la mayor parte de lo que se muestra.

| Min | Diap. | Parte | Qué |
|---|---|---|---|
| 0:00 | 1 | 1 | Portada (20 s) |
| 0:20 | 2 | 1 | Qué vamos a explicar (30 s) |
| 0:50 | 3 | 1 | Objetivo (1 min) |
| 1:50 | 4 | 1 | Qué hace el sistema (1 min) |
| 2:50 | 5 | 2 | Arquitectura (1,5 min) |
| 4:20 | 6 | 2 | Datos de Salto y Montevideo (1 min) |
| 5:20 | 7 | 2 | Cómo aguanta miles de objetos (1 min) |
| 6:20 | 8 | 3 | Rutas por calles con pgRouting (1,5 min) |
| 7:50 | 9 | 3 | Dónde usamos las rutas (1,5 min) |
| 9:20 | 10 | 4 | Demo en vivo (9 min) |
| 18:20 | 11 | 4 | Conclusiones (1 min) |

## Qué dice cada uno

### Parte 1 · Apertura (diapositivas 1 a 4)

**1. Portada.** "Somos Nahuel, Carlos, Facundo y Gonzalo. Presentamos UrbanSafe, un sistema web para gestionar emergencias urbanas sobre un mapa. En la imagen están las zonas, los recursos y los incidentes de Salto dibujados por GeoServer; los números son grupos que se separan al acercar."

**2. Qué vamos a explicar.** La diapositiva es un índice de cuatro puntos. "Vamos a ir en este orden: primero el objetivo y qué hace el sistema; después la arquitectura, los datos y cómo aguanta miles de objetos; después las rutas con pgRouting; y por último la demo en vivo y las conclusiones." Leer solo los cuatro títulos.

**3. Objetivo.** "El objetivo es el de la letra: ver sobre un mapa dónde ocurren los incidentes, qué recursos hay cerca y cuánto tardan en llegar. En el monitoreo nos pidieron tres cosas que marcaron el diseño: que atienda todo el país aunque la defensa sea en Salto, que aguante miles de objetos, y que haya dos vistas, una de administrador y una de invitado que solo consulta."

**4. Qué hace.** Recorrer las cinco filas sin detenerse: gestión, consultas (siete más el reporte), mapa público, direcciones y rutas por calles. "Todo esto lo mostramos en la demo."

### Parte 2 · Arquitectura, datos y escala (diapositivas 5 a 7)

**5. Arquitectura.** "Es una aplicación en capas. El cliente React con Leaflet habla con el backend por REST y con GeoServer por WMS y WFS. El backend, hecho con Jersey sobre Tomcat, aplica las reglas de negocio y es el único que escribe en la base. GeoServer lee la misma base y dibuja las capas. La base es PostgreSQL con PostGIS y pgRouting: ahí se hace el cálculo espacial. Todo se levanta con un solo comando de Docker. Lo único que usa internet es el mapa de fondo de Esri y las direcciones de la IDE fuera de Salto."

**6. Datos.** "Cargamos datos reales en dos departamentos: Salto y Montevideo. Son 51 zonas, 324 recursos y 198 incidentes. Las zonas y los servicios son reales: seccionales de UNASEV, servicios de salud de la Intendencia y OpenStreetMap. Los incidentes y los 77 móviles son de prueba, pero sobre calles reales. Un límite: OpenStreetMap trae pocos servicios de Salto, por eso hay 21 recursos reales ahí."

**7. Miles de objetos.** "El tutor observó que el front cargaba todos los objetos. Lo resolvimos en tres partes. Una: el navegador pide solo los de la parte visible del mapa, con un límite (500 por defecto, 2.000 como máximo), y avisa si quedaron afuera. Dos: con el mapa alejado, GeoServer dibuja las capas como imagen y agrupa los puntos con un número. Tres: todas las geometrías tienen índice espacial GiST. Lo probamos con 100.000 incidentes, 30.000 recursos y 5.000 zonas: los listados responden en menos de 100 ms y GeoServer dibuja en menos de 130 ms."

### Parte 3 · Rutas con pgRouting (diapositivas 8 y 9)

**8. pgRouting.** "pgRouting es una extensión de PostgreSQL que corre dentro de la misma base. Las calles son un grafo: cada esquina es un vértice y cada tramo un arco. Bajamos el mapa de OpenStreetMap de Uruguay una sola vez y lo guardamos en dos tablas, con 216.179 arcos. Cada arco tiene un costo en metros y en segundos, y las manos únicas tienen costo −1 en el sentido prohibido, así que Dijkstra las respeta. Una función SQL ajusta el recurso y el incidente al punto exacto de la calle y busca el camino. Una ruta en Salto tarda unos 50 ms y de Salto a Montevideo, 1,1 s. Una vez cargada la red, no necesita internet."

**9. Dónde usamos las rutas.** "La misma función sirve para tres cosas. El tiempo de llegada: el camino más rápido, en minutos. El recurso más cercano a un incidente: PostGIS toma los cinco más cercanos en línea recta y pgRouting calcula la ruta real de cada uno; gana el de menos metros por calles. Y la consulta 3: los N recursos más cercanos, con las rutas si se piden. Los límites que decimos nosotros: no hay semáforos ni tránsito, así que el tiempo es una estimación, y solo se comparan cinco candidatos en línea recta."

### Parte 4 · Demo en vivo (diapositiva 10, 9 min)

Orden (la da una sola persona): se arranca **sin ingresar** (vista de invitado) y, antes del segundo bloque, se ingresa como administrador (`admin` / `urbansafe`, ver `infra/.env`).

1. **Mapa público (2 min).** Encender y apagar capas; mover el mapa y mostrar que los conteos cambian; filtrar incidentes por tipo y estado; clic en un incidente para ver el detalle; activar el mapa de calor; achicar la ventana para mostrar que se adapta al celular. *Req. 28 a 32, 36 y 37.*
2. **Gestión (3 min).** Dibujar una zona y guardarla; dar de alta un recurso; registrar un incidente como línea (calle cortada) o polígono; avanzar su estado y abrir el histórico; borrar uno. Decir de paso que la zona se puede superponer con otra. *Req. 1 a 18.*
3. **Rutas (1,5 min).** En el detalle de un incidente, "Trazar ruta al recurso más cercano"; mostrar el camino, los minutos y las calles; abrir la pantalla de tiempo de llegada y elegir un recurso y un incidente con el clic. *Req. 34 y 35.*
4. **Consultas (2,5 min).** Consultas 1 y 2 (incidentes por zona y zonas con más incidentes), 3 (recursos cercanos), 4 y 5 por dirección (`Uruguay 1000`) y por cruce de calles (`Uruguay` y `Yatay`), 6 y 7; y el reporte por zona con filtros. *Req. 19 a 27.*

Antes de empezar: navegador en Salto, base recién levantada y **hacer una ruta larga** (con la base en frío la primera puede pasar el plazo de 10 s). Llevar capturas o un video por si falla Docker o internet.

### Parte 4 · Cierre (diapositiva 11, 1 min)

**Conclusiones.** La diapositiva tiene tres columnas.
- **Lo logrado:** "Integramos PostGIS, GeoServer y un cliente web. Hicimos las siete consultas con operaciones espaciales, rutas por calles con pgRouting y OpenStreetMap, y trabajamos con datos reales y miles de objetos con carga a demanda. El único punto de la letra que no hicimos, el control de superposición de zonas (opcional), no corresponde porque el tutor definió que las zonas pueden superponerse."
- **Límites:** "El tiempo de llegada es una estimación, sin tránsito ni semáforos. Solo se comparan 5 recursos en línea recta. Una calle cortada no se saca de la red de rutas. Tenemos puertas propias solo en Salto y la autenticación es básica, con un solo usuario."
- **A futuro:** "Sumar tránsito y giros prohibidos a las rutas; evitar calles cortadas y dar prioridad a emergencias; calcular cobertura, hasta dónde llega cada recurso en N minutos; actualizar la red vial de OpenStreetMap; y cargar puertas de más departamentos." Cerrar: "Quedamos para las preguntas."

Si hay tiempo o preguntan por ello, dos puntos para confirmar con el tutor: los estados finales (Resuelto y Cancelado no tienen salida: es un supuesto nuestro) y si esperan ver el histórico agrupado por zona (hoy es por incidente).

## Preguntas: qué debe saber cada uno

Después de la presentación preguntan a todos. Cada uno tiene que poder explicar su parte y, además, lo básico del resto.

**Lo que todos deben saber:** la arquitectura (diapositiva 5), que el guardado pasa por el backend y no por GeoServer, y que el sistema atiende todo el país.

**Nahuel (datos y GeoServer)**
- *¿Qué hace GeoServer y qué hace el REST?* GeoServer dibuja miles de objetos rápido como imágenes y responde qué hay bajo un clic, pero no se editan. El REST trae los objetos reales para elegirlos, editarlos y calcular.
- *¿Por qué el guardado no va por WFS-T?* Porque las reglas de negocio (validar geometrías, máquina de estados) viven en el backend.
- *¿En qué sistema de coordenadas se guardan?* En UTM 21S (SRID 32721, en metros); la API habla en lon/lat y el backend convierte con `ST_Transform`.
- *¿Cómo se configura GeoServer?* Solo: `infra/init/geoserver-init.sh` crea capas y estilos por su API REST.
- *¿Qué mapa de fondo usan y qué pasa sin internet?* Esri Light Gray, no OpenStreetMap. Sin internet el fondo queda gris; las capas, las consultas, el ABM y las rutas siguen andando.

**Facundo (ABM y carga a demanda)**
- *¿Cómo se guarda un polígono?* Leaflet-draw lo dibuja → GeoJSON → `POST /zonas` → el backend valida (`ST_IsValid` y que sea polígono) → `ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(...), 4326), 32721)` → INSERT.
- *¿Cómo se guarda una línea o un polígono de un incidente?* En la misma columna `incidente.geom` (tipo `Geometry`); las consultas sirven para cualquier forma.
- *¿Se pueden superponer las zonas?* Sí, lo definió el tutor; por eso la consulta 5 devuelve todas las zonas del punto.
- *¿Cómo escala?* El navegador nunca carga todo: pide el rectángulo visible con un tope y usa el índice GiST; lejos, dibuja GeoServer.
- *¿Quién queda en el histórico?* El usuario de la sesión, no un texto que se escriba.

**Carlos (pgRouting)**
- *¿Por qué pgRouting y no OSRM?* OSRM es un servicio aparte y preprocesado por región (solo habíamos hecho Salto). pgRouting vive en la base, se combina con zonas, recursos e incidentes y cubre todo el país.
- *¿De dónde salen las calles?* Del extracto de OpenStreetMap de Uruguay que distribuye Geofabrik; el servicio `red-vial` lo procesa una vez y lo guarda en `red_vial_arco` y `red_vial_vertice`.
- *¿Cómo respeta las manos únicas?* El sentido prohibido tiene costo −1, la convención de pgRouting.
- *¿Por qué "más cercano" se mide en metros y no en minutos?* En una prueba con 40 pares, el camino más corto y el más rápido fueron distintos en 24; "más cercano" se entiende como el de menos metros, y el tiempo de llegada sigue en minutos.
- *¿Qué límites tiene?* Sin giros prohibidos, semáforos ni tránsito; solo se comparan 5 candidatos en línea recta; un incidente de "calle cortada" no se saca de la red.
- *¿Hay otra forma de armar la red?* Sí, `osm2pgrouting`, la herramienta estándar; acá la carga se hizo a medida para controlar sentidos, velocidades y redes aisladas.

**Gonzalo (consultas, mapa público y direcciones)**
- *¿Qué operador usa cada consulta?* 1 y 2: `ST_Intersects`. 3 y 4: `<->` (vecino más cercano con índice espacial) y `ST_Distance`. 5 y 6: `ST_Contains`. 7: una tabla de relación (`incidente_recurso`), no es espacial.
- *¿Cómo funciona la dirección?* En Salto usa la tabla `acceso` (números de puerta propios) y tolera errores de tipeo; si no la resuelve o es de otro departamento, usa el servicio de la IDE. El cruce de calles sale de la red vial de OpenStreetMap, sin internet.
- *¿Cómo es el login?* `POST /auth/login` devuelve un token; un filtro del backend protege toda la API por defecto y deja públicas solo unas lecturas (las del invitado).
- *¿Cómo hace el mapa de calor?* GeoServer, con `vec:Heatmap` en un estilo SLD; no trae los incidentes al navegador.
