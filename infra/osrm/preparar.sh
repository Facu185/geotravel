#!/bin/sh
# Igual que preparar.ps1, para Linux/macOS. Ejecutar desde la raiz del repositorio:
#   sh infra/osrm/preparar.sh
set -eu
IMAGEN="ghcr.io/project-osrm/osrm-backend:v5.27.1"
AQUI="$(cd "$(dirname "$0")" && pwd)"
DATOS="$AQUI/data"
PBF="$DATOS/uruguay.osm.pbf"

URL_PBF="https://download.geofabrik.de/south-america/uruguay-latest.osm.pbf"

docker info >/dev/null 2>&1 || { echo "Docker no esta disponible o no esta iniciado" >&2; exit 1; }
mkdir -p "$DATOS/fast" "$DATOS/shortest"
LIBRE_MB=$(df -Pm "$DATOS" | awk 'NR==2 {print $4}')
[ "$LIBRE_MB" -ge 3000 ] || { echo "Espacio libre insuficiente: ${LIBRE_MB} MB (se necesitan unos 3 GB)" >&2; exit 1; }
if [ -r /proc/meminfo ]; then
  RAM_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  [ "$RAM_MB" -ge 1500 ] || echo "Aviso: memoria libre baja (${RAM_MB} MB); Uruguay necesita ~1.5 GB" >&2
fi
if [ ! -f "$PBF" ]; then
  echo "Descargando el extracto de Uruguay (Geofabrik)..."
  curl -L --fail -o "$PBF" "$URL_PBF"
  printf 'Origen: %s\nDescargado: %s\nBytes: %s\n' "$URL_PBF" "$(date '+%Y-%m-%d %H:%M:%S')" "$(wc -c < "$PBF")" > "$DATOS/ORIGEN.txt"
elif [ ! -f "$DATOS/ORIGEN.txt" ]; then
  printf 'Origen: %s (extracto ya presente; fecha de descarga no registrada)\nBytes: %s\n' "$URL_PBF" "$(wc -c < "$PBF")" > "$DATOS/ORIGEN.txt"
fi
cat "$DATOS/ORIGEN.txt"

procesar() {
  carpeta="$1"; perfil="$2"; destino="$DATOS/$carpeta"
  if [ -f "$destino/mapa.osrm.mldgr" ]; then echo "[$carpeta] ya procesado, se omite."; return; fi
  cp "$PBF" "$destino/mapa.osm.pbf"
  run="docker run --rm -v $destino:/data -v $AQUI/profiles:/profiles:ro $IMAGEN"
  $run osrm-extract -p "$perfil" /data/mapa.osm.pbf
  $run osrm-partition /data/mapa.osrm
  $run osrm-customize /data/mapa.osrm
  rm "$destino/mapa.osm.pbf"
  echo "[$carpeta] listo."
}

procesar fast /opt/car.lua
procesar shortest /profiles/car_distancia.lua
