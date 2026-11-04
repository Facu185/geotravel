# P1: Grafo vial de Salto para pgRouting

**Estado:** grafo generado desde tabla via, tablas pobladas, pgRouting 4.0.2 instalado automáticamente en el build.

## Objetivo

Generar el grafo vial de Salto que cumpla el contrato de pgRouting (P2) para habilitar el cálculo de rutas. La infraestructura usa una imagen Docker personalizada basada en `postgis/postgis:16-3.6` con pgRouting preinstalado en el build, garantizando instalación automática al levantar el entorno.

## Origen de datos

Archivo `db/data/vias.csv.gz` (v_sig_vias de Salto):
- 3239 tramos de calle en EPSG:32721
- Cargado en tabla `via` por `infra/init/seed.sh` al levantar el proyecto
- Procesado localmente mediante `db/sql/p1_generar_grafo_via.sql`

## Infraestructura

### Imagen Docker

Imagen personalizada `infra/Dockerfile.db` que extiende `postgis/postgis:16-3.6` e instala pgRouting automáticamente durante el build:

```dockerfile
FROM postgis/postgis:16-3.6
RUN apt-get update && apt-get install -y postgresql-16-pgrouting && apt-get clean && rm -rf /var/lib/apt/lists/*
```

### docker-compose.yml

El servicio `db` usa `build: context: ../, dockerfile: infra/Dockerfile.db` para construir la imagen con pgRouting preinstalado.

### Migración V5

`db/migrations/V5__pgrouting_grafo.sql`:
- `CREATE EXTENSION IF NOT EXISTS pgrouting`
- Crea tablas `red_vial_vertice` y `red_vial_arco` (contrato P2)
- Índices GiST (geom) y B-tree (source, target)

### Generación del grafo

`db/sql/p1_generar_grafo_via.sql` (solo PostGIS; se puede volver a ejecutar: vacía el grafo y lo regenera):
- Toma las calles transitables por vehículos (deja afuera `PEATONAL` y `PROYECTADA`).
- **Parte cada calle en cada cruce** (`ST_Node`), de modo que cada arco va de esquina a esquina. Cada fila de `via` es una
  calle de OpenStreetMap entera, que atraviesa varias esquinas sin terminar en ellas: tomarla como un solo arco dejaba la
  red rota en 1.104 pedazos y casi ninguna ruta tenía solución.
- Se queda con la red conectada con el centro de Salto (`ST_ClusterDBSCAN`): descarta Concordia (Argentina), del otro
  lado del río, y los tramos sueltos.
- Vértices = las esquinas. Costo de distancia: `ST_Length(geom)` en metros.
- Costo de tiempo según el tipo de vía (los valores de `via.tipo` están en mayúsculas): `AVENIDA` 50 km/h,
  `RUTA NACIONAL` 60, `CALLE` 40, `CAMINO` 30. Así "más rápida" no es lo mismo que "más corta".
- Limitaciones: `via` no trae sentidos de circulación (todas las calles son de doble mano) y no se modelan giros
  prohibidos. Agregar el sentido único (etiqueta `oneway` de OpenStreetMap) mejoraría las rutas.

Para regenerarlo en una base que ya existe (`seed.sh` aplica el grafo una sola vez), desde `infra/`:

```bash
docker compose exec -T db psql -U geotravel -d geotravel -v ON_ERROR_STOP=1 < ../db/sql/p1_generar_grafo_via.sql
```

## Métricas validadas

- **2.316 vértices** (esquinas) y **3.627 arcos** (tramos de esquina a esquina; mediana 114 m, máximo 4,2 km).
- **Una sola componente conexa**: desde cualquier esquina se llega a cualquier otra.
- Cuatro velocidades distintas (30, 40, 50 y 60 km/h).
- Con los recursos y los incidentes puntuales de prueba de Salto (300 pares recurso–incidente al azar con
  `setseed(0.42)`, medido el 4/11): todos los pares con ambos extremos a menos de 250 m de una esquina (274) tienen
  ruta; el desvío mediano de la ruta contra la línea recta es de 1,25.
  Los otros 26 tienen un extremo a más de 250 m de cualquier esquina (ver `docs/P2_PGROUTING.md`).
- En viajes largos (más de 2,5 km) la ruta más rápida es distinta de la más corta en 4 de 66 casos (misma muestra).
- Costos coherentes: todos positivos, sin NULL, bidireccionales.

## Instalación

```powershell
cd infra
docker compose up -d --build
```

pgRouting se instala automáticamente durante el build de la imagen. 
La generación del grafo y la función de ruteo se ejecutan automáticamente al levantar el proyecto (mediante seed.sh).

## Validación

```powershell
docker exec geotravel-db-1 psql -U geotravel -d geotravel -c "SELECT COUNT(*) FROM red_vial_vertice; SELECT COUNT(*) FROM red_vial_arco; SELECT MIN(cost_m), MAX(cost_m), AVG(cost_m) FROM red_vial_arco; SELECT MIN(cost_s), MAX(cost_s), AVG(cost_s) FROM red_vial_arco; SELECT pgr_version();"
```

Resultado esperado: 2316 vértices, 3627 arcos, pgr_version 4.0.2

## Integración con P2

Grafo listo para uso con función `p2_calcular_ruta`. P2 puede probar ruteo con `db/seed/seed_salto_eta.sql`.

## Archivos

- `infra/Dockerfile.db` - Imagen personalizada con pgRouting preinstalado
- `db/migrations/V5__pgrouting_grafo.sql` - Estructura del grafo
- `db/sql/p1_generar_grafo_via.sql` - Generador desde via
- `db/sql/p2_rutas_pgrouting.sql` - Función de P2
