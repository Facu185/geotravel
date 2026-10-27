# Prepara los datos de OSRM propio (Uruguay). Corre una sola vez y se puede repetir.
# Genera dos conjuntos de datos separados a partir del mismo extracto de OpenStreetMap:
#   data\rapida\  perfil car.lua oficial      -> minimiza el tiempo estimado
#   data\corta\   profiles\car_distancia.lua  -> minimiza la distancia por calles
# Descarga uruguay-latest.osm.pbf (unos 55 MB) de Geofabrik solo si no existe; no borra nada.
# Uso:  powershell -File infra\osrm\preparar.ps1   (desde la raiz del repositorio)
$ErrorActionPreference = "Stop"
$imagen = "ghcr.io/project-osrm/osrm-backend:v5.27.1"
$aqui = $PSScriptRoot
$datos = Join-Path $aqui "data"
$pbf = Join-Path $datos "uruguay.osm.pbf"

New-Item -ItemType Directory -Force $datos, (Join-Path $datos "rapida"), (Join-Path $datos "corta") | Out-Null

if (-not (Test-Path $pbf)) {
    Write-Host "Descargando el extracto de Uruguay (Geofabrik)..."
    curl.exe -L --fail -o $pbf "https://download.geofabrik.de/south-america/uruguay-latest.osm.pbf"
}

function Procesar($carpeta, $perfil) {
    $destino = Join-Path $datos $carpeta
    if (Test-Path (Join-Path $destino "mapa.osrm.mldgr")) {
        Write-Host "[$carpeta] ya procesado, se omite."
        return
    }
    Copy-Item $pbf (Join-Path $destino "mapa.osm.pbf") -Force
    $montajes = @("-v", "${destino}:/data", "-v", "$(Join-Path $aqui 'profiles'):/profiles:ro")
    foreach ($paso in @(
            @("osrm-extract", "-p", $perfil, "/data/mapa.osm.pbf"),
            @("osrm-partition", "/data/mapa.osrm"),
            @("osrm-customize", "/data/mapa.osrm"))) {
        docker run --rm @montajes $imagen @paso
        if ($LASTEXITCODE -ne 0) { throw "[$carpeta] fallo $($paso[0])" }
    }
    Remove-Item (Join-Path $destino "mapa.osm.pbf")
    Write-Host "[$carpeta] listo."
}

Procesar "rapida" "/opt/car.lua"
Procesar "corta" "/profiles/car_distancia.lua"
Write-Host "Listo. Levantar con: docker compose --profile osrm up -d (ver docs/RECURSOS_CERCANOS_RUTAS.md)"
