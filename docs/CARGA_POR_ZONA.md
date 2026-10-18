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
