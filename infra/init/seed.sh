#!/bin/sh
# Carga datos al levantar, sin duplicar nada:
#   1. La red vial de Salto (db/data/vias.csv.gz) y los números de puerta (db/data/accesos.csv.gz): datos
#      de referencia, cada uno solo si su tabla está vacía.
#   2. Los datos generales (db/seed/seed.sql): una sola vez.
#   3. El escenario ETA en Salto (db/seed/seed_salto_eta.sql): una sola vez, incluso
#      en bases que ya existian. Tiene marcador independiente y no duplica registros.
# No se vuelven a crear datos que alguien elimine luego de aplicar el seed.
set -e
export PGPASSWORD="$POSTGRES_PASSWORD"
PSQL="psql -h db -U $POSTGRES_USER -d $POSTGRES_DB -v ON_ERROR_STOP=1 -tA"

# --- 1. red vial
if [ ! -f /data/vias.csv.gz ]; then
  echo "vias: falta db/data/vias.csv.gz, no se cargan"
elif [ "$($PSQL -c 'SELECT count(*) FROM via')" = "0" ]; then
  # El archivo trae la geometría como WKT en lon/lat (EPSG:4326); la tabla guarda EPSG:32721.
  $PSQL -c "DROP TABLE IF EXISTS _via_carga; CREATE TABLE _via_carga (nom_calle text, tipo text, wkt text)" > /dev/null
  gunzip -c /data/vias.csv.gz | psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -c "\copy _via_carga FROM STDIN WITH (FORMAT csv, HEADER true)"
  $PSQL -c "INSERT INTO via (nom_calle, tipo, geom) SELECT nom_calle, tipo, ST_Transform(ST_SetSRID(ST_GeomFromText(wkt), 4326), 32721) FROM _via_carga; DROP TABLE _via_carga" > /dev/null
  $PSQL -c "ANALYZE via" > /dev/null
  echo "vias: $($PSQL -c 'SELECT count(*) FROM via') tramos de calle cargados"
else
  echo "vias: ya cargadas, no se repiten"
fi

# --- 1b. números de puerta
if [ ! -f /data/accesos.csv.gz ]; then
  echo "accesos: falta db/data/accesos.csv.gz, no se cargan"
elif [ "$($PSQL -c 'SELECT count(*) FROM acceso')" = "0" ]; then
  gunzip -c /data/accesos.csv.gz | psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q     -c "\copy acceso (num_puerta, letra, nom_calle, cod_nombre, x, y) FROM STDIN WITH (FORMAT csv, HEADER true)"
  $PSQL -c "ANALYZE acceso" > /dev/null
  echo "accesos: $($PSQL -c 'SELECT count(*) FROM acceso') números de puerta cargados"
else
  echo "accesos: ya cargados, no se repiten"
fi

# --- 2. datos de prueba
$PSQL -c "CREATE TABLE IF NOT EXISTS _seed_aplicado (fecha timestamptz NOT NULL DEFAULT now())"

if [ "$($PSQL -c 'SELECT count(*) FROM _seed_aplicado')" != "0" ]; then
  echo "seed: datos generales ya cargados; no se repiten"
else
  CANTIDAD=$($PSQL -c 'SELECT (SELECT count(*) FROM zona_operativa) + (SELECT count(*) FROM recurso) + (SELECT count(*) FROM incidente)')
  if [ "$CANTIDAD" != "0" ]; then
    echo "seed: la base ya tiene datos generales; no se carga el seed inicial"
  else
    psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -f /seed/seed.sql
    echo "seed: datos generales de prueba cargados"
  fi
  $PSQL -c "INSERT INTO _seed_aplicado DEFAULT VALUES" > /dev/null
fi

# --- 3. Escenario ETA Salto: se aplica UNA vez, aun sobre una base existente.
$PSQL -c "CREATE TABLE IF NOT EXISTS _seed_salto_eta_aplicado (fecha timestamptz NOT NULL DEFAULT now())" > /dev/null
if [ "$($PSQL -c 'SELECT count(*) FROM _seed_salto_eta_aplicado')" = "0" ]; then
  psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -f /seed/seed_salto_eta.sql
  $PSQL -c "INSERT INTO _seed_salto_eta_aplicado DEFAULT VALUES" > /dev/null
  echo "seed ETA Salto: escenario disponible"
else
  echo "seed ETA Salto: ya aplicado; no se repite"
fi
