<#
  Publica en GeoServer (por su API REST) todo lo que necesita el mapa de UrbanSafe:
  workspace, almacén PostGIS, las 3 capas y sus estilos SLD. Se puede correr las veces que
  haga falta: si algo ya existe, lo actualiza en vez de fallar.

  Requisitos: docker compose levantado (db + geoserver) y la base con el esquema y el seed cargados.

  Uso (desde la carpeta geoserver):
      powershell -ExecutionPolicy Bypass -File .\publicar-capas.ps1

  Los defaults sirven para el docker-compose del repo. Para otra instalación:
      .\publicar-capas.ps1 -GeoServerUrl http://localhost:8080/geoserver -DbHost localhost
#>
param(
    [string]$GeoServerUrl = "http://localhost:8082/geoserver",
    [string]$User         = "admin",
    [string]$Password     = "geoserver",
    [string]$Workspace    = "geotravel",
    # Datos de conexión que usa GeoServer PARA LLEGAR a la base. Dentro de docker compose el
    # servicio se llama "db"; si GeoServer corre fuera de Docker, usar "localhost".
    [string]$DbHost       = "db",
    [string]$DbPort       = "5432",
    [string]$DbName       = "geotravel",
    [string]$DbUser       = "geotravel",
    [string]$DbPassword   = "geotravel"
)

$ErrorActionPreference = "Stop"
$Rest = "$GeoServerUrl/rest"
$Auth = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${User}:${Password}")) }

# capa de la base -> título -> estilo SLD (archivo en .\styles\<estilo>.sld)
$Capas = @(
    @{ Nombre = "zona_operativa"; Titulo = "Zonas operativas"; Estilo = "zonas_nivel_prioridad" },
    @{ Nombre = "recurso";        Titulo = "Recursos";         Estilo = "recursos_tipo" },
    @{ Nombre = "incidente";      Titulo = "Incidentes";       Estilo = "incidentes_estado" }
)

function Invoke-GS {
    param([string]$Method, [string]$Path, [string]$Body, [string]$ContentType = "application/json")
    $p = @{ Uri = "$Rest$Path"; Method = $Method; Headers = $Auth; UseBasicParsing = $true }
    if ($Body) { $p.Body = [Text.Encoding]::UTF8.GetBytes($Body); $p.ContentType = $ContentType }
    try { return Invoke-WebRequest @p }
    catch {
        $detalle = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        throw "GeoServer rechazó $Method $Path -> $detalle"
    }
}

function Test-GS([string]$Path) {
    try { Invoke-WebRequest -Uri "$Rest$Path" -Headers $Auth -UseBasicParsing | Out-Null; return $true }
    catch { return $false }
}

function Json($o) { $o | ConvertTo-Json -Depth 8 -Compress }

# ---------------------------------------------------------------- 0. ¿responde GeoServer?
Write-Host "0. Conectando con GeoServer en $GeoServerUrl ..."
if (-not (Test-GS "/about/version.json")) {
    throw "GeoServer no responde (o usuario/clave incorrectos). ¿Está levantado? Probá: docker compose up -d geoserver (tarda 1-2 min en arrancar)."
}

# ---------------------------------------------------------------- 1. workspace
Write-Host "1. Workspace '$Workspace'"
if (Test-GS "/workspaces/$Workspace.json") { Write-Host "   ya existe" }
else { Invoke-GS POST "/workspaces" (Json @{ workspace = @{ name = $Workspace } }) | Out-Null; Write-Host "   creado" }

# ---------------------------------------------------------------- 2. almacén PostGIS
Write-Host "2. Almacén PostGIS '$Workspace' -> ${DbHost}:${DbPort}/${DbName}"
$entradas = @(
    @{ "@key" = "dbtype";   "$" = "postgis" },
    @{ "@key" = "host";     "$" = $DbHost },
    @{ "@key" = "port";     "$" = $DbPort },
    @{ "@key" = "database"; "$" = $DbName },
    @{ "@key" = "schema";   "$" = "public" },
    @{ "@key" = "user";     "$" = $DbUser },
    @{ "@key" = "passwd";   "$" = $DbPassword },
    @{ "@key" = "Expose primary keys"; "$" = "true" }
)
$almacen = Json @{ dataStore = @{ name = $Workspace; connectionParameters = @{ entry = $entradas } } }
if (Test-GS "/workspaces/$Workspace/datastores/$Workspace.json") {
    Invoke-GS PUT "/workspaces/$Workspace/datastores/$Workspace" $almacen | Out-Null; Write-Host "   actualizado"
} else {
    Invoke-GS POST "/workspaces/$Workspace/datastores" $almacen | Out-Null; Write-Host "   creado"
}

# ---------------------------------------------------------------- 3. estilos SLD
Write-Host "3. Estilos SLD"
foreach ($c in $Capas) {
    $archivo = Join-Path $PSScriptRoot "styles\$($c.Estilo).sld"
    if (-not (Test-Path $archivo)) { throw "Falta el archivo de estilo: $archivo" }
    $sld = [IO.File]::ReadAllText($archivo, [Text.Encoding]::UTF8)
    $tipo = "application/vnd.ogc.sld+xml"
    if (Test-GS "/workspaces/$Workspace/styles/$($c.Estilo).json") {
        Invoke-GS PUT "/workspaces/$Workspace/styles/$($c.Estilo)" $sld $tipo | Out-Null; Write-Host "   $($c.Estilo): actualizado"
    } else {
        Invoke-GS POST "/workspaces/$Workspace/styles?name=$($c.Estilo)" $sld $tipo | Out-Null; Write-Host "   $($c.Estilo): creado"
    }
}

# ---------------------------------------------------------------- 4. capas + estilo por defecto
Write-Host "4. Capas"
foreach ($c in $Capas) {
    $ft = "/workspaces/$Workspace/datastores/$Workspace/featuretypes"
    if (Test-GS "$ft/$($c.Nombre).json") { Write-Host "   $($c.Nombre): ya publicada" }
    else {
        $cuerpo = Json @{ featureType = @{ name = $c.Nombre; nativeName = $c.Nombre; title = $c.Titulo; srs = "EPSG:32721"; enabled = $true } }
        Invoke-GS POST $ft $cuerpo | Out-Null
        Write-Host "   $($c.Nombre): publicada"
    }
    $estilo = Json @{ layer = @{ defaultStyle = @{ name = $c.Estilo; workspace = $Workspace } } }
    Invoke-GS PUT "/layers/${Workspace}:$($c.Nombre)" $estilo | Out-Null
    Write-Host "   $($c.Nombre): estilo por defecto = $($c.Estilo)"
}

Write-Host ""
Write-Host "Listo. Capas publicadas en el workspace '$Workspace':"
foreach ($c in $Capas) { Write-Host "  - ${Workspace}:$($c.Nombre)" }
Write-Host "Previsualizar: $GeoServerUrl/web/ (Previsualización de capas -> OpenLayers)"
