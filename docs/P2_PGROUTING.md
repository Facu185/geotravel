# P2: preparación de rutas con pgRouting

**Estado:** adaptador Java y función SQL preparados, **aún sin integrar ni validar contra el grafo de P1**. El motor predeterminado continúa siendo OSRM. Esta contribución no modifica `main` y no elimina las dos rutas OSRM existentes.

## Comparación para el artículo (P2 + P1)

| Criterio | OSRM (actual) | pgRouting (propuesto) |
| --- | --- | --- |
| Ejecución | Servicio independiente | Función SQL en PostgreSQL |
| Rutas corta y rápida | Dos perfiles con datos preprocesados | Mismo grafo con costos de longitud y tiempo |
| Calles transitables | Perfil de conducción OSM | Depende de los sentidos y accesos cargados por P1 |
| Giros prohibidos | Considerados según datos/perfil | **No contemplados** por esta versión de Dijkstra |
| Estado | Implementado y probado | Pendiente del grafo real de Salto y pruebas |

**pgRouting y PostGIS son dos extensiones diferentes de PostgreSQL.** PostGIS aporta las geometrías y las consultas espaciales; pgRouting calcula los caminos en el grafo.

## Contrato que P1 debe entregar

P1 prepara los datos de OpenStreetMap de Salto, instala pgRouting y publica las siguientes tablas o vistas equivalentes en `public`:

```sql
CREATE TABLE public.red_vial_vertice (
  id bigint PRIMARY KEY,
  geom geometry(Point,32721) NOT NULL
);
CREATE TABLE public.red_vial_arco (
  id bigint PRIMARY KEY,
  source bigint NOT NULL REFERENCES public.red_vial_vertice(id),
  target bigint NOT NULL REFERENCES public.red_vial_vertice(id),
  geom geometry(LineString,32721) NOT NULL,
  cost_m double precision NOT NULL,
  reverse_cost_m double precision NOT NULL,
  cost_s double precision NOT NULL,
  reverse_cost_s double precision NOT NULL
);
```

- El trazado de cada arco va de `source` a `target`. Los costos directos son para ese sentido, los `reverse_cost_*` para el contrario.
- **Sentido prohibido**: costo negativo. **Sentido permitido**: distancia positiva (metros) y duración positiva (segundos). Para un grafo correcto, costos de distancia y tiempo de cada dirección deben reflejar las mismas restricciones.
- Los arcos deben cortarse en esquinas **conectadas**; no unir puentes y vías a distinto nivel sin acceso.
- Índices GiST para geometrías y B-tree para `source` y `target`.
- La tabla `via` existente no cumple este contrato; no usarla directamente. P1 gestiona sus propias migraciones nuevas sin reescribir las anteriores.

## Función SQL de P2

Archivo: `db/sql/p2_rutas_pgrouting.sql` (no se instaló automáticamente como migración para no hacer fallar Flyway antes de que P1 termine el grafo).

Después de que P1 haya entregado el grafo, desde la raíz del proyecto:

```bash
psql -h localhost -U geotravel -d geotravel -v ON_ERROR_STOP=1 -f db/sql/p2_rutas_pgrouting.sql
```

Función: `public.p2_calcular_ruta(lon_origen,lat_origen,lon_destino,lat_destino,criterio)`.

- Coordenadas de entrada: **EPSG:4326** (longitud y latitud).
- Cálculo espacial: **EPSG:32721** (metros).
- `criterio = 'mas_corta'`: `pgr_dijkstra` sobre el costo `cost_m` / `reverse_cost_m`.
- `criterio = 'mas_rapida'`: `pgr_dijkstra` sobre el costo `cost_s` / `reverse_cost_s`.
- La duración entregada siempre es la suma de tiempos de **la ruta que se seleccionó**, incluso cuando se minimizan metros.
- Se devuelve un `LineString` GeoJSON en EPSG:4326, distancia en metros, duración en segundos y ajuste a los nodos.
- Cuando no existe camino o un extremo queda a más de **250 m del nodo más cercano**, la función no devuelve filas.

**Limitaciones:** se ajusta a vértices, no al punto más cercano dentro de un arco; la línea no incluye el tramo entre la ubicación original y el vértice ajustado. Tampoco se modelan giros prohibidos. Por eso hay que validar la conectividad y restricciones reales con P1. No afirmar que cumple perfectamente el tránsito vial hasta ejecutar esas verificaciones.

## Integración Java de P2

El backend obtiene los extremos de los recursos e incidentes como antes y conserva los endpoints de ETA y la consulta 3, con los mismos parámetros `criterio=mas_rapida|mas_corta` y el mismo contrato JSON. `MotorPgRouting` ejecuta la función SQL mediante JDBC y entrega geometría, distancia, tiempo y advertencias a `RutaService`.

Configuración del servicio backend en Docker:

```env
RUTAS_MOTOR=osrm
# Solo cuando P1 haya instalado la extensión, el grafo y el SQL de P2:
RUTAS_MOTOR=pgrouting
```

Sin cambiar esa variable, OSRM continúa funcionando como hasta ahora. En modo pgRouting **no se cambia a OSRM silenciosamente** si el motor SQL falla. `GET /eta/criterios` informa la falta de función o grafo; la UI ya sabe deshabilitar criterios que no estén disponibles. El frontend existente no requiere reescritura porque los contratos no cambian.

## Pendiente antes del cierre de esta tarea

1. P1: publicar migración nueva e importar un grafo válido de Salto con sentidos y velocidades.
2. P2: acordar nombres y tipos reales de tablas; instalar SQL P2; ejecutar pruebas de Dijkstra y contraste con OSRM en base aislada.
3. P2: probar ETA y consulta 3 por HTTP con ambos criterios e incidentes Point, LineString y Polygon.
4. P5: comprobar frontend y GeoServer (solo visualización de calles, no cálculo de rutas).
5. Equipo: decidir si OSRM queda como respaldo configurable o se retira una vez verificado pgRouting. **No eliminar todavía OSRM.**

**No se ejecutaron pruebas reales de pgRouting en esta preparación.** La red y la extensión aún no están instaladas en la rama revisada. No usar `docker compose down -v` ni `flyway repair` sobre datos existentes.
