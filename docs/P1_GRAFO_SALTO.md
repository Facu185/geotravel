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

`db/sql/p1_generar_grafo_via.sql`:
- Extrae vértices de puntos de inicio/fin de tramos `via`
- Asigna source/target
- Calcula costos de distancia: `ST_Length(geom)` en metros
- Calcula costos de tiempo según tipo de calle (avenida: 50km/h, calle: 40km/h, otros: 30km/h)
- Inserta en `red_vial_vertice` y `red_vial_arco`

## Métricas validadas

- **4197 vértices** (intersecciones/nodos)
- **3239 arcos** (tramos de calle)
- Distancia promedio: 356.7m (rango: 3.95m - 6474.53m)
- Tiempo promedio: 42.8s (rango: 0.47s - 776.94s)
- Costos coherentes: todos positivos, sin NULL, bidireccionales

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

Resultado esperado: 4197 vértices, 3239 arcos, pgr_version 4.0.2

## Integración con P2

Grafo listo para uso con función `p2_calcular_ruta`. P2 puede probar ruteo con `db/seed/seed_salto_eta.sql`.

## Archivos

- `infra/Dockerfile.db` - Imagen personalizada con pgRouting preinstalado
- `db/migrations/V5__pgrouting_grafo.sql` - Estructura del grafo
- `db/sql/p1_generar_grafo_via.sql` - Generador desde via
- `db/sql/p2_rutas_pgrouting.sql` - Función de P2
