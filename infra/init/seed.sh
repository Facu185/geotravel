#!/bin/sh
# Carga datos al levantar, sin duplicar nada:
#   1. La red vial (db/data/vias.sql.gz) y los números de puerta (db/data/accesos.csv.gz): datos
#      de referencia, cada uno solo si su tabla está vacía.
#   2. Los datos de prueba (db/seed/seed.sql): UNA sola vez; no hace nada si la base ya tiene
#      datos o si el seed ya se cargó antes (la tabla _seed_aplicado lo recuerda), para no
#      duplicar ni resucitar datos que alguien borró a propósito.
set -e
export PGPASSWORD="$POSTGRES_PASSWORD"
PSQL="psql -h db -U $POSTGRES_USER -d $POSTGRES_DB -v ON_ERROR_STOP=1 -tA"

# --- 1. red vial
if [ "$($PSQL -c 'SELECT count(*) FROM via')" = "0" ]; then
  gunzip -c /data/vias.sql.gz | psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -f - > /dev/null
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
  echo "seed: ya se cargó antes, no se repite"
  exit 0
fi

CANTIDAD=$($PSQL -c 'SELECT (SELECT count(*) FROM zona_operativa) + (SELECT count(*) FROM recurso) + (SELECT count(*) FROM incidente)')
if [ "$CANTIDAD" != "0" ]; then
  echo "seed: la base ya tiene datos, no se carga"
else
  psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -f /seed/seed.sql
  echo "seed: datos de prueba cargados"
fi
$PSQL -c "INSERT INTO _seed_aplicado DEFAULT VALUES" > /dev/null
