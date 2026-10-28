# Prepara los datos de OSRM propio (Uruguay). Corre una sola vez y se puede repetir.
# Genera dos conjuntos de datos separados a partir del mismo extracto de OpenStreetMap:
#   data\fast\  perfil car.lua oficial      -> minimiza el tiempo estimado
#   data\shortest\   profiles\car_distancia.lua  -> minimiza la distancia por calles
# Descarga uruguay-latest.osm.pbf (unos 55 MB) de Geofabrik solo si no existe; no borra nada.
# Uso:  powershell -File infra\osrm\preparar.ps1   (desde la raiz del repositorio)
$ErrorActionPreference = "Stop"
$imagen = "ghcr.io/project-osrm/osrm-backend:v5.27.1"
$urlPbf = "https://download.geofabrik.de/south-america/uruguay-latest.osm.pbf"
$aqui = $PSScriptRoot
$datos = Join-Path $aqui "data"
$pbf = Join-Path $datos "uruguay.osm.pbf"

# Comprobaciones previas: Docker disponible, disco y memoria suficientes.
docker info *> $null
if ($LASTEXITCODE -ne 0) { throw "Docker no esta disponible o no esta iniciado" }
New-Item -ItemType Directory -Force $datos, (Join-Path $datos "fast"), (Join-Path $datos "shortest") | Out-Null
$libreGb = (Get-PSDrive -Name ((Resolve-Path $datos).Path.Substring(0, 1))).Free / 1GB
if ($libreGb -lt 3) { throw ("Espacio libre insuficiente: {0:N1} GB (se necesitan unos 3 GB)" -f $libreGb) }
$ramGb = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB
if ($ramGb -lt 1.5) { Write-Warning ("Memoria libre baja: {0:N1} GB; el procesamiento de Uruguay necesita ~1.5 GB" -f $ramGb) }
Write-Host ("Espacio libre: {0:N1} GB, memoria libre: {1:N1} GB" -f $libreGb, $ramGb)

if (-not (Test-Path $pbf)) {
    Write-Host "Descargando el extracto de Uruguay (Geofabrik)..."
    curl.exe -L --fail -o $pbf $urlPbf
    if ($LASTEXITCODE -ne 0) { throw "No se pudo descargar $urlPbf" }
    @("Origen: $urlPbf", "Descargado: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))", "Bytes: $((Get-Item $pbf).Length)") |
        Set-Content (Join-Path $datos "ORIGEN.txt")
} elseif (-not (Test-Path (Join-Path $datos "ORIGEN.txt"))) {
    @("Origen: $urlPbf (extracto ya presente; fecha de descarga no registrada)", "Bytes: $((Get-Item $pbf).Length)") |
        Set-Content (Join-Path $datos "ORIGEN.txt")
}
Get-Content (Join-Path $datos "ORIGEN.txt")

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

Procesar "fast" "/opt/car.lua"
Procesar "shortest" "/profiles/car_distancia.lua"
Write-Host "Listo. Levantar con: docker compose --profile osrm up -d (ver docs/RECURSOS_CERCANOS_RUTAS.md)"
