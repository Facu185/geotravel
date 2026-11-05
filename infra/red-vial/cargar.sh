#!/bin/sh
# Arma la red vial de pgRouting de todo Uruguay a partir de OpenStreetMap. Corre una vez al levantar:
#   1. Si el grafo ya tiene arcos, no hace nada (para rehacerlo: docker compose run --rm -e RED_VIAL_REGENERAR=1 red-vial).
#   2. Si falta, baja el extracto de Uruguay de Geofabrik (unos 56 MB) a infra/red-vial/data/.
#   3. red_vial_osm.py lo parte en arcos de esquina a esquina (con sentido, velocidad y nombre) y deja un CSV.
#   4. Lo carga en la base y db/sql/red_vial_generar.sql arma los vértices, los arcos y sus costos.
set -e
export PGPASSWORD="$POSTGRES_PASSWORD"
PSQL="psql -h db -U $POSTGRES_USER -d $POSTGRES_DB -v ON_ERROR_STOP=1 -tA"
PBF=/data/uruguay.osm.pbf
CSV=/data/red_vial.csv.gz
LUGARES=/data/lugares.csv.gz
VIAS=/data/vias.csv.gz
URL_PBF="https://download.geofabrik.de/south-america/uruguay-latest.osm.pbf"

ARCOS=$($PSQL -c "SELECT count(*) FROM red_vial_arco WHERE osm_way_id IS NOT NULL")
SIN_NOMBRE_NORM=$($PSQL -c "SELECT count(*) FROM red_vial_arco WHERE nombre IS NOT NULL AND nombre_norm IS NULL")
LUGARES_CARGADOS=$($PSQL -c "SELECT count(*) FROM lugar_osm")
# La capa via arranca con las calles de Salto (db/data/vias.csv.gz); con la red vial pasa a tener las de todo el país.
VIAS_DEL_PAIS=$($PSQL -c "SELECT count(*) FROM via")
if [ "$ARCOS" != "0" ] && [ "$SIN_NOMBRE_NORM" = "0" ] && [ "$LUGARES_CARGADOS" != "0" ] && [ "$VIAS_DEL_PAIS" -gt 20000 ] && [ -z "$RED_VIAL_REGENERAR" ]; then
  echo "red vial: ya hay $ARCOS arcos de OpenStreetMap, $LUGARES_CARGADOS lugares y $VIAS_DEL_PAIS calles; no se repite"
  exit 0
fi

if [ ! -f "$PBF" ]; then
  echo "red vial: bajando el extracto de Uruguay (Geofabrik)..."
  if ! curl -L --fail -o "$PBF" "$URL_PBF"; then
    # Sin internet no se puede armar la red; se sigue sin ella (no se frena el resto del arranque).
    rm -f "$PBF"
    echo "red vial: NO se pudo bajar el extracto; las rutas no van a estar disponibles. Reintentar con: docker compose run --rm red-vial"
    exit 0
  fi
  printf 'Origen: %s\nDescargado: %s\nBytes: %s\n' "$URL_PBF" "$(date '+%Y-%m-%d %H:%M:%S')" "$(wc -c < "$PBF")" > /data/ORIGEN.txt
fi

if [ ! -f "$CSV" ] || [ ! -f "$LUGARES" ] || [ ! -f "$VIAS" ] || [ "$PBF" -nt "$CSV" ] || [ -n "$RED_VIAL_REGENERAR" ]; then
  python /app/red_vial_osm.py "$PBF" "$CSV" "$LUGARES" "$VIAS"
fi

$PSQL -c "DROP TABLE IF EXISTS red_vial_carga; CREATE TABLE red_vial_carga (osm_way_id bigint, origen bigint, destino bigint, nombre text, referencia text, highway text, sentido text, velocidad_kmh integer, rotonda boolean, puente boolean, tunel boolean, wkt text)" > /dev/null
gunzip -c "$CSV" | psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -c "\copy red_vial_carga FROM STDIN WITH (FORMAT csv, HEADER true)"
# Los lugares (ciudades, pueblos, barrios) de OpenStreetMap, para ubicar los cruces de calles.
$PSQL -c "TRUNCATE lugar_osm" > /dev/null
gunzip -c "$LUGARES" | psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -c "\copy lugar_osm (nombre, tipo, poblacion, lon, lat) FROM STDIN WITH (FORMAT csv, HEADER true)"
$PSQL -c "UPDATE lugar_osm SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 32721) WHERE geom IS NULL; ANALYZE lugar_osm" > /dev/null
psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -f /sql/red_vial_generar.sql
$PSQL -c "DROP TABLE red_vial_carga" > /dev/null

# La capa de referencia via: las calles con nombre de todo el país (reemplaza a las de Salto que carga el seed).
$PSQL -c "DROP TABLE IF EXISTS _via_carga; CREATE TABLE _via_carga (nom_calle text, tipo text, wkt text)" > /dev/null
gunzip -c "$VIAS" | psql -h db -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q -c "\copy _via_carga FROM STDIN WITH (FORMAT csv, HEADER true)"
$PSQL -c "TRUNCATE via RESTART IDENTITY; INSERT INTO via (nom_calle, tipo, geom) SELECT nom_calle, tipo, ST_Transform(ST_SetSRID(ST_GeomFromText(wkt), 4326), 32721) FROM _via_carga; DROP TABLE _via_carga; ANALYZE via" > /dev/null
echo "calles (via): $($PSQL -c 'SELECT count(*) FROM via') de todo el país"
echo "red vial: lista"
