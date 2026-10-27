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
| `mas_corta` | distancia vial por calles permitidas | OSRM propio, perfil `infra/osrm/profiles/car_distancia.lua` | `OSRM_SHORTEST_URL` + datos preparados |

OSRM aplica el perfil al **procesar** el mapa, por eso hay dos datasets y dos servicios (`osrm-fast`, `osrm-shortest`).
El perfil de distancia es el `car.lua` oficial con `weight_name = 'distance'`: respeta sentidos únicos, giros
prohibidos y accesos, pero el peso de cada tramo es su longitud. La ruta más corta puede tardar más (en las pruebas,
hasta 50 % más de tiempo por unos pocos metros menos). Sin `OSRM_SHORTEST_URL` el criterio `mas_corta` responde 503
con un mensaje claro y `mas_rapida` sigue funcionando. No se usa `alternatives=true`: no garantiza el mínimo global.

### Preparar y levantar el OSRM propio

```powershell
infra\osrm\preparar.ps1      # (o preparar.sh) descarga uruguay-latest.osm.pbf (~56 MB) y procesa los 2 datasets
# en infra/.env:
#   OSRM_FAST_URL=http://osrm-fast:5000
#   OSRM_SHORTEST_URL=http://osrm-shortest:5000
docker compose --profile osrm up -d --build
```

Los datos van a `infra/osrm/data/` (no se versionan; `fast/`, `shortest/`, `uruguay.osm.pbf` y `ORIGEN.txt` con la URL,
fecha y tamaño del extracto). `preparar.ps1`/`.sh` comprueban antes que Docker funcione, que haya ≥ 3 GB de disco libre
y avisan si la memoria libre es < 1,5 GB. Si el `.pbf` o un dataset ya existen no se descarga ni reprocesa nada.
En Windows: `powershell -ExecutionPolicy Bypass -File infra\osrm\preparar.ps1` si la política de scripts lo bloquea.
Extracto probado: Geofabrik `uruguay-latest.osm.pbf`, 56 192 625 bytes (la fecha exacta no se registró en la primera
descarga; las nuevas descargas la guardan en `ORIGEN.txt`).

Variables: `OSRM_FAST_URL` (alias `OSRM_URL`; vacía = OSRM público) y `OSRM_SHORTEST_URL` (alias antiguo
`OSRM_URL_CORTA`). Puertos publicados: `OSRM_FAST_PORT` (5001) y `OSRM_SHORTEST_PORT` (5002).

### Algoritmo y restricciones de circulación

OSRM v5.27.1 con algoritmo MLD: cada perfil se aplica en `osrm-extract`, y luego `osrm-partition` y `osrm-customize`.
El perfil corto reutiliza `car.lua` (sentidos únicos, giros prohibidos, accesos y tipos de vía transitables para autos)
y solo cambia el costo de cada arista a su longitud (`weight_name=distance`; verificado: `weight` == `distance` en las rutas).
El criterio de la ruta rápida es la duración estimada con las velocidades del perfil car.

### Errores, tiempo máximo y disponibilidad

- Cada pedido a OSRM tiene un límite estricto (10 s, o el tiempo restante de los 25 s de la consulta); al vencer se
  cancela. Los recursos cuya ruta no alcanzó a calcularse quedan con `estadoRuta: "plazo_agotado"`; el resto se devuelve.
- Un recurso sin ruta (`sin_ruta`) o con error (`error`) no interrumpe a los demás; si el motor está caído no se insiste.
- `GET /eta/criterios` informa qué criterios están disponibles (`{"mas_rapida":true,"mas_corta":bool}`); el frontend
  deshabilita "Más corta" cuando no está configurada. Sin el motor corto, el endpoint con `criterio=mas_corta` responde 503.

### Pruebas

Unitarias (sin servicios): `mvn -f backend/pom.xml test`. Opt-in con servicios levantados:
`URBANSAFE_INTEGRATION_TESTS=true` (PostGIS; usar una base de pruebas) y `URBANSAFE_OSRM_TESTS=true` con `OSRM_FAST_URL`
y `OSRM_SHORTEST_URL` (pesos del perfil, "más corta pero más lenta", GeoJSON).

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

`OSRM_URL` (rápida; por defecto el OSRM público, con límites de uso y sin garantías) y `OSRM_SHORTEST_URL`
(más corta; sin valor = desactivada). Ver `infra/.env.example`.

## Uso en el frontend

Consultas → "Recursos cercanos": elegir incidente, radio y cantidad. Se ve el buffer (azul),
las líneas directas (gris punteado) y, con "Calcular rutas por calles", los recorridos (verde).
La pantalla ETA muestra además la distancia directa, el criterio y las advertencias.
