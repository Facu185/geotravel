#!/bin/sh
# Igual que preparar.ps1, para Linux/macOS. Ejecutar desde la raiz del repositorio:
#   sh infra/osrm/preparar.sh
set -eu
IMAGEN="ghcr.io/project-osrm/osrm-backend:v5.27.1"
AQUI="$(cd "$(dirname "$0")" && pwd)"
DATOS="$AQUI/data"
PBF="$DATOS/uruguay.osm.pbf"

mkdir -p "$DATOS/rapida" "$DATOS/corta"
if [ ! -f "$PBF" ]; then
  echo "Descargando el extracto de Uruguay (Geofabrik)..."
  curl -L --fail -o "$PBF" "https://download.geofabrik.de/south-america/uruguay-latest.osm.pbf"
fi

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

procesar rapida /opt/car.lua
procesar corta /profiles/car_distancia.lua
