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

La pantalla Consultas tampoco carga todos los objetos al abrirse:

- **Fondo:** todo lo que existe lo dibuja GeoServer (WMS), como en el mapa público.
- **Resultado:** cada consulta de `/consultas/...` devuelve ya la geometría de lo que encontró (`geom`) y, las que
  pueden dar muchas filas (C1, C2, C6, C7 y el reporte), `?limit=` y `{items, total, truncado}`. Las geometrías
  de las zonas se simplifican (3 m) para pesar menos. El ranking de zonas devuelve las 50 primeras.
- **Elegir un objeto:** en vez de un desplegable con todas las zonas, incidentes o recursos, un buscador por texto
  (`GET /consultas/buscar?tipo=zona|incidente|recurso&q=`) que devuelve pocas opciones.
- **Vista:** al terminar la consulta el mapa se encuadra solo en el resultado (puede estar en cualquier parte del país).

Probado con `db/pruebas/carga-masiva.sql` (700 zonas, 3.000 recursos): las consultas responden en 10 a 30 ms.

## Mapa público (P5)

El mapa público ya dibujaba todo con GeoServer (imágenes), así que escala. Lo que faltaba eran los números:

- **Conteos de lo que se ve:** al terminar de mover o hacer zoom (con una espera de 400 ms), el mapa lee el rectángulo
  visible y lo suma al filtro de cada capa como `BBOX(geom, oeste, sur, este, norte, 'EPSG:4326')`. GeoServer cuenta con
  `resultType=hits` usando el índice espacial, sin descargar objetos. Los filtros de incidentes y recursos se combinan
  con ese rectángulo.
- **Detalle al tocar:** `GetFeatureInfo` trae como máximo 10 objetos.
- **Región:** el mapa abre centrado en Salto (`region.js`); los datos de prueba están en Montevideo, así que en Salto
  los conteos dan 0 hasta cargar datos de esa zona.

## Direcciones por región (P5)

Las consultas 4 y 5 aceptan una dirección y una esquina. Según la región (`REGION.ide` en `region.js`):

| | Montevideo | Resto del país (Salto) |
|---|---|---|
| Calle y número | Tabla propia `acceso` (números de puerta de la Intendencia) | Servicio de direcciones de la IDE (`?departamento=salto&localidad=salto`) |
| Esquina | Cruce calculado con PostGIS sobre `via` (con autocompletado de calles) | IDE, con el parámetro `esquina` (sin autocompletado: no hay calles propias) |

Para sumar otro departamento alcanza con agregar una entrada en `region.js`. Probado con "Uruguay 1000" y la esquina
"Uruguay y Artigas" de Salto.
