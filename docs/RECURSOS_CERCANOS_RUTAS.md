# Consulta 3: recursos cercanos con buffer y rutas por calles

Endpoint: `GET /consultas/recursos-cercanos/{incidenteId}/analisis-vial`
(el endpoint anterior `/consultas/recursos-cercanos/{id}` no cambió).

## Parámetros

| Parámetro | Defecto | Rango |
|---|---|---|
| `radioMetros` | 2000 | 1..10000 (fuera de rango: 400) |
| `limite` | 5 | 1..10 |
| `soloDisponibles` | true | |
| `conRutas` | false | si es true consulta OSRM |

## Cómo funciona

1. **Buffer**: `ST_Buffer(incidente.geom, radio)` en EPSG:32721 (metros), devuelto en 4326 como `bufferGeom`.
2. **Selección**: `ST_DWithin(recurso.geom, incidente.geom, radio)` ordenado por `ST_Distance`.
   Funciona con incidentes Point, LineString y Polygon.
3. **Distancia directa**: `ST_Distance` y línea `ST_ShortestLine` (`lineaDirecta`).
4. **Ruta por calles** (`conRutas=true`): servicio compartido `RutaService` (el mismo de ETA)
   consulta OSRM solo para los 5 más cercanos, de forma secuencial y con un plazo total de 25 s.
   Si un recurso no tiene ruta queda con `estadoRuta` `sin_ruta` o `error` y conserva su distancia directa.
   Si OSRM no responde, no se insiste con el resto.
5. Para incidentes lineales o poligonales el destino es el punto del incidente más cercano al recurso.
   OSRM lo ajusta a la calle: se informa `ajusteOrigenM`/`ajusteDestinoM` y hay `advertencia` si es ≥ 100 m.

## ¿Ruta más corta o más rápida?

Son dos criterios distintos y la API/UI los distinguen (`criterio=mas_rapida|mas_corta`, campo `criterioRuta`):

| Criterio | Qué minimiza | Motor | Requisito |
|---|---|---|---|
| `mas_rapida` (defecto) | duración estimada | OSRM `driving` (público o propio) | ninguno |
| `mas_corta` | distancia vial por calles permitidas | OSRM propio, perfil `infra/osrm/profiles/car_distancia.lua` | `OSRM_URL_CORTA` + datos preparados |

OSRM aplica el perfil al **procesar** el mapa, por eso hay dos datasets y dos servicios (`osrm-rapida`, `osrm-corta`).
El perfil de distancia es el `car.lua` oficial con `weight_name = 'distance'`: respeta sentidos únicos, giros
prohibidos y accesos, pero el peso de cada tramo es su longitud. La ruta más corta puede tardar más (en las pruebas,
hasta 50 % más de tiempo por unos pocos metros menos). Sin `OSRM_URL_CORTA` el criterio `mas_corta` responde 503
con un mensaje claro y `mas_rapida` sigue funcionando. No se usa `alternatives=true`: no garantiza el mínimo global.

### Preparar y levantar el OSRM propio

```powershell
infra\osrm\preparar.ps1      # (o preparar.sh) descarga uruguay-latest.osm.pbf (~56 MB) y procesa los 2 datasets
# en infra/.env:
#   OSRM_URL=http://osrm-rapida:5000
#   OSRM_URL_CORTA=http://osrm-corta:5000
docker compose --profile osrm up -d --build
```

Los datos van a `infra/osrm/data/` (no se versionan). Procesar Uruguay requiere ~250 MB de RAM y deja ~400 MB
en disco (dos datasets). El `.pbf` solo se descarga si falta.

### Resultados verificados (OSRM propio, datos de prueba de Montevideo y Salto)

En 25 pares recurso-incidente (consulta 3, 5 incidentes) la distancia de `mas_corta` fue ≤ la de `mas_rapida` en todos;
en 12 fue menor (p. ej. 987 m → 931 m, pero 96 s → 127 s) y en el resto coincidió la misma ruta. En una prueba
directa contra OSRM, ahorrar 146 m (3932 → 3786 m) costó 185 s más (408 → 593 s).

### Limitaciones

- El peso de distancia no penaliza giros ni cruces; la duración mostrada sigue estimándose con velocidades del perfil car.
- Sin tráfico en tiempo real. La calidad depende de OpenStreetMap (sentidos, cierres, cobertura).
- Los extremos se ajustan a la calle más cercana (ver `advertencia`).
- La tabla `via` del proyecto no sirve como grafo (solo Montevideo, sin sentidos ni topología), por eso se usa OSM.

## Configuración

`OSRM_URL` (rápida; por defecto el OSRM público, con límites de uso y sin garantías) y `OSRM_URL_CORTA`
(más corta; sin valor = desactivada). Ver `infra/.env.example`.

## Uso en el frontend

Consultas → "Recursos cercanos": elegir incidente, radio y cantidad. Se ve el buffer (azul),
las líneas directas (gris punteado) y, con "Calcular rutas por calles", los recorridos (verde).
La pantalla ETA muestra además la distancia directa, el criterio y las advertencias.
