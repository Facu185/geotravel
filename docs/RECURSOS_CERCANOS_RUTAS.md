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

**Solo más rápida.** OSRM `driving` optimiza la duración, no la distancia, por lo que el recorrido
puede no ser el de menor distancia vial. La API lo declara (`criterioRuta = "mas_rapida"`) y la UI también.
Los tiempos no incluyen tráfico en tiempo real.

Para cumplir estrictamente "menor distancia vial" haría falta:
- un OSRM propio con un perfil que optimice distancia (requiere descargar y procesar el OSM de Uruguay, cientos de MB), o
- pgRouting, que exige construir una red con topología (la tabla `via` solo tiene LineStrings, sin sentidos).

## Configuración

`OSRM_URL` (ver `infra/.env.example`). Por defecto se usa el OSRM público, con límites de uso
y sin garantías de disponibilidad.

## Uso en el frontend

Consultas → "Recursos cercanos": elegir incidente, radio y cantidad. Se ve el buffer (azul),
las líneas directas (gris punteado) y, con "Calcular rutas por calles", los recorridos (verde).
La pantalla ETA muestra además la distancia directa, el criterio y las advertencias.
