# Carga a demanda (zona visible + zoom)

Para soportar miles de zonas, recursos e incidentes, el navegador nunca carga todos los
objetos. Hay dos capas por entidad:

| Capa | Qué muestra | Quién la dibuja |
|---|---|---|
| Fondo (solo ver) | Todos los objetos | GeoServer (WMS): el navegador recibe imágenes |
| Edición | Solo los del rectángulo visible, hasta un límite | El front, con `?bbox=&limit=` |

Por debajo del zoom mínimo (`VITE_ZOOM_MINIMO_EDICION`, 13 por defecto) no se pide nada
editable: se muestra la capa WMS y el aviso "Acercá el mapa para ver y editar …".

## Contrato del backend

```
GET /zonas?bbox=oeste,sur,este,norte&limit=500
→ 200 { "items": [ ... ], "total": 3000, "truncado": true }
```

- `bbox` en lon/lat (EPSG:4326), el formato de `map.getBounds().toBBoxString()` de Leaflet.
  Se recorta a la extensión de Uruguay antes de pasar a EPSG:32721.
- `limit` por defecto 500, máximo 2000.
- `total` es la cantidad real en el rectángulo (`COUNT(*) OVER ()`, calculado antes del `LIMIT`).
- Sin `bbox` la respuesta sigue siendo el arreglo de siempre (compatibilidad con Consultas).
- Filtro: `geom && ST_Transform(ST_MakeEnvelope(?, ?, ?, ?, 4326), 32721)` usa el índice GiST
  (verificado con `EXPLAIN`: `Index Scan using idx_recurso_geom`).
- Implementado en `/zonas` y `/recursos` con `backend/.../mapa/Bbox.java`, reusable para
  `/incidentes` y las consultas.

## Cómo usarlo en otra pantalla (incidentes, consultas)

```jsx
import CargaPorZona, { AvisoCarga, SIN_CARGAR } from "../../components/CargaPorZona.jsx";

const [carga, setCarga] = useState(SIN_CARGAR);
const [recarga, setRecarga] = useState(0);          // sumar 1 después de guardar o borrar
const lejos = carga.estado === "lejos";

// dentro del mapa (hijosMapa):
<CargaPorZona ruta="/incidentes" recarga={recarga} alCambiar={setCarga} />
// carga.items son los objetos visibles

// en PaginaMapa:
mapaProps={{ layers: lejos ? ["geotravel:incidente"] : [], wmsExtra: { actualizado: recarga } }}
aviso={<AvisoCarga carga={carga} nombre="incidentes" />}
```

El componente espera 300 ms a que el mapa deje de moverse, cancela el pedido anterior y
reemplaza los objetos (no acumula lo que salió de la vista).

## Incidentes (P4): punto, línea y polígono

`/incidentes` ya usa la carga a demanda (`?bbox=&limit=`, mismo contrato) y la pantalla Incidentes
(`modules/incidentes/IncidentesPage.jsx`) la consume con `CargaPorZona`; alejado se ve la capa WMS
`geotravel:incidente`.

La ubicación de un incidente es un **punto** (un lugar), una **línea** (un tramo: una calle cortada) o un **polígono**
(un área afectada). Se elige la forma en el formulario y se dibuja en el mapa, o se usa la barra de dibujo del mapa
directamente. El backend (`IncidenteResource`) rechaza con 400 lo que no sea una de esas formas o no sea válida
(`ST_IsValid`: un polígono que se cruza a sí mismo, una línea de un solo punto).

El dibujo está en un componente compartido, `components/EditorGeometria.jsx`, pensado para reusar en Zonas y Recursos:

```jsx
const grupoRef = useRef(null);
const dibujando = useRef(false); // true mientras se dibuja: un clic sobre otro objeto no lo selecciona
// dentro del mapa (hijosMapa):
<EditorGeometria grupoRef={grupoRef} pedido={pedido} dibujando={dibujando}
                 alCrear={(geometria) => ...} alEditar={(geometria) => ...} alBorrar={() => ...} />
// cargarGeometria(grupoRef.current, geojson) pone la forma de un objeto para editarla;
// geometriaDelGrupo(grupoRef.current) lee la forma que hay al guardar.
```

Ojo con `react-leaflet-draw`: si `EditControl` recibe un objeto `draw` distinto en cada render, rehace la barra y cancela
el trazo en curso. `EditorGeometria` lo evita (opciones en `useMemo`); si se usa `EditControl` directo, hacer lo mismo.

## Región

`VITE_REGION=salto | montevideo` en `frontend/.env.local` (por defecto `salto`). Para otro
departamento o localidad se agrega una entrada en `frontend/src/components/region.js`.

## Ojo: extensión de las capas en GeoServer (P1)

GeoServer guarda la extensión de cada capa cuando se publica. Si se publicó con los datos de
Montevideo, **no dibuja nada en Salto** aunque los datos estén en la base. Después de cargar
datos nuevos hay que recalcularla (por capa):

```bash
curl -u admin:geoserver -X PUT -H "Content-Type: application/json" \
  -d '{"featureType":{"name":"recurso","enabled":true}}' \
  "http://localhost:8082/geoserver/rest/workspaces/geotravel/datastores/geotravel/featuretypes/recurso?recalculate=nativebbox,latlonbbox"
```

La solución definitiva es que `infra/init/geoserver-init.sh` declare para todas las capas una
extensión fija que cubra Uruguay, así no depende de los datos que haya al publicar.

## Consultas (P5)

La pantalla Consultas tampoco carga todos los objetos al abrirse. En el mapa hay tres clases de cosas:

- **Fondo:** GeoServer (WMS) dibuja de fondo solo el tipo de objeto con el que trabaja la consulta (zonas, incidentes o recursos), no todo lo que existe. El navegador recibe imágenes.
- **Objetos para elegir (consultas 1, 2, 3, 6 y 7):** las zonas, incidentes o recursos de la parte visible del mapa,
  hasta un límite (`CargaPorZona`, desde el zoom 11; en los ABM se pide desde el 13). El front los dibuja, los lista en el
  panel y se elige uno con un clic en el mapa o en la lista. Mientras están dibujados así, GeoServer no dibuja ese mismo
  tipo (para que no se vea doble). Elegir otro es un clic más.
- **Resultado:** cada consulta de `/consultas/...` devuelve ya la geometría de lo que encontró (`geom`) y, las que
  pueden dar muchas filas (C1, C2, C6, C7 y el reporte), `?limit=` y `{items, total, truncado}`. Las geometrías
  de las zonas se simplifican (3 m) para pesar menos.

Qué hace cada consulta:

| Consulta | Se ven en el mapa | Al elegir |
|---|---|---|
| 1. Incidentes por zona | Las zonas de la vista | Sus incidentes, dibujados y listados |
| 2. Zonas con más incidentes | Las zonas de la vista, más oscuras cuantos más incidentes (`?bbox=` en `/consultas/zonas-mas-incidentes`) | Una zona: sus incidentes |
| 3. Recursos cercanos | Los incidentes de la vista | Los recursos Disponibles dentro de un radio: buffer del incidente (`ST_Buffer`, `ST_DWithin`), línea recta y, a pedido, el camino por calles |
| 4. Incidente más cercano a un punto | De fondo, los incidentes (GeoServer, imagen); se busca con un clic, una dirección o un cruce | El incidente encontrado y la línea hasta el punto. No se cargan los de la vista porque el más cercano puede quedar afuera |
| 5. Zona de un punto | De fondo, las zonas (GeoServer, imagen) | Todas las zonas que contienen al punto (se pueden superponer) |
| 6. Recursos por zona | Las zonas de la vista | Sus recursos |
| 7. Incidentes por recurso | Los recursos de la vista | Sus incidentes, con una línea desde el recurso |

Se sacaron los dos extras (incidentes por km² y dibujar una línea o un polígono para buscar alrededor).

Las consultas 1 a 7 las ve también el **invitado** (sin ingresar); el reporte sigue siendo solo del administrador. Por eso
`AuthFilter` deja públicas, únicamente de lectura, `GET /consultas/...` (menos `reportes`), el listado de `GET /zonas`,
`/incidentes` y `/recursos` y `GET /eta/disponible`. Al pie del panel, "¿Qué significa cada ícono?" muestra la misma
leyenda del mapa público (`LeyendaCapa.jsx`).

## Tiempo de llegada (P2)

La pantalla `/eta` sigue el mismo patrón: el incidente y el recurso se eligen con un clic en el mapa, o en un desplegable
con búsqueda (`SelectorBuscable`, sobre `GET /consultas/buscar`, que busca en todo el sistema y no solo en la vista).
Dibujan lo visible `CargaPorZona` y el componente compartido `CapaElegibles` (el mismo de las Consultas); lo elegido
queda marcado aunque se mueva el mapa.

## Agrupar con un número al alejar el mapa

Con el mapa alejado (zoom 14 o menos) los incidentes y recursos que quedan juntos se agrupan en un círculo con la
cantidad; del zoom 15 en adelante se ven los íconos. Hay dos mecanismos con la misma regla (celda de 64 px, mismo corte):

- **GeoServer** (mapa público y el fondo cuando se está lejos): `vec:PointStacker` en el SLD, ver `docs/ICONOS.md`.
- **El navegador** (Consultas, Tiempo de llegada y los ABM de Incidentes y Recursos): `CapaAgrupada.jsx`, con
  `leaflet.markercluster`. Las líneas y los polígonos de incidentes cuentan en el grupo por su centro.

Probado con `db/pruebas/carga-masiva.sql` (700 zonas, 3.000 recursos): las consultas responden en 10 a 30 ms.

## Mapa público (P5)

El mapa público ya dibujaba todo con GeoServer (imágenes), así que escala. Lo que faltaba eran los números:

- **Conteos de lo que se ve:** al terminar de mover o hacer zoom (con una espera de 400 ms), el mapa lee el rectángulo
  visible y lo suma al filtro de cada capa como `BBOX(geom, oeste, sur, este, norte, 'EPSG:4326')`. GeoServer cuenta con
  `resultType=hits` usando el índice espacial, sin descargar objetos. Los filtros de incidentes y recursos se combinan
  con ese rectángulo.
- **Detalle al tocar:** `GetFeatureInfo` trae como máximo 10 objetos.
- **Región:** el mapa abre centrado en Salto (`region.js`). El seed trae datos reales en el departamento de Salto (18 zonas, 30
  recursos y 44 incidentes, en la ciudad y en el interior) y también en Montevideo (33 zonas, 225 recursos y 25 incidentes),
  para comprobar que el sistema atiende todo el país: al mover el mapa a otra región (botones "Ir a") los conteos y las
  capas cambian.

## Direcciones por región (P5)

Las consultas 4 y 5 aceptan una dirección y una esquina. Según la región (`REGION.ide` en `region.js`):

| | Salto (`callesPropias: true`, con puertas propias) | Resto del país (por ejemplo Montevideo) |
|---|---|---|
| Calle y número | Tabla propia `acceso` (números de puerta de Salto) | Servicio de direcciones de la IDE (`?departamento=montevideo&localidad=montevideo`) |
| Esquina | Cruce calculado con PostGIS sobre la red vial de OpenStreetMap **de todo el país** (con autocompletado de calles, sin internet): ver "Cruces de calles en todo el país" | Igual: la red es la misma en todo el país (la IDE queda de respaldo si las calles no se cruzan en la red) |

**Dirección en todo el país.** El campo "Dónde buscar" del buscador de direcciones arranca en **Todo el país**
(`departamento=todo`): primero se busca en las puertas propias de Salto y, si la calle no está, en la IDE **sin fijar
departamento**. La IDE devuelve las calles con ese nombre de todo Uruguay; se ubica la mejor (la de portal exacto, y en
Salto si empata) y las demás se ofrecen como alternativas ("Hay otras coincidencias en el país"). Se puede limitar la búsqueda
a uno de los 19 departamentos. Ejemplo: `Minas 2091` no está en Salto; existe con portal exacto en Montevideo y es lo que se
ubica, y la lista muestra las otras "Minas" (Young, Belén, Toledo, Mariscala, Villa Sara). Los cruces de calles siguen
usando la región configurada.

**Cruces de calles en todo el país.** `/consultas/interseccion` busca, en la red vial de OpenStreetMap (`red_vial_arco`, la misma
de las rutas), las esquinas a las que llegan un tramo de cada calle; no usa internet. Los nombres se comparan sin tildes, mayúsculas
ni abreviaturas (`normalizar_calle`, migración V7). Como una calle se repite en muchas localidades ("Colonia" son 60 vías en el país),
devuelve hasta 10 cruces, del más cercano a la región, cada uno con el lugar más próximo (`lugar_osm`: ciudades, pueblos y barrios del
mismo extracto de OpenStreetMap). Ejemplo: "Colonia" y "Convención" dan un cruce en Montevideo y otro en Pinares de Solymar.

Para sumar otro departamento alcanza con agregar una entrada en `region.js`. En Salto, la dirección y el cruce
funcionan sin internet; la IDE queda de respaldo si la calle no está en la base. Probado con "Uruguay 1000" y la
esquina "Uruguay y Artigas".
