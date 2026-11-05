# UrbanSafe P2: reproducir ETA en Salto en otra computadora

Este escenario ya esta integrado en `main` (PR #24).
El repositorio incluye codigo backend y frontend, Docker Compose, migraciones,
configuracion y datos de prueba reproducibles. **No** se versionan los volumenes
Docker ni los IDs internos de la base local.

## Requisitos

- Git, Docker Desktop/Engine con Compose, Node.js y npm.
- Conexion a internet para instalar dependencias, descargar teselas de mapa y,
  la primera vez, bajar el extracto de OpenStreetMap de Uruguay (~56 MB) con el que
  el servicio `red-vial` arma las rutas. Despues las rutas se calculan sin internet.
- Puertos por defecto libres: 5432, 8080, 8082 y 5173.

## Primera instalacion en Windows (PowerShell)

Desde una carpeta vacia en la que quieras instalar el proyecto:

```powershell
git clone https://github.com/Facu185/geotravel.git
Set-Location geotravel/infra
Copy-Item .env.example .env
docker compose up -d --build
docker compose ps -a
docker compose logs seed --tail=30
```

Esperar que el servicio `seed` haya terminado correctamente (`Exited (0)`).
La primera carga incluye datos generales de referencia y puede llevar varios
minutos. El backend aguarda a que el seed concluya.

Probar el backend:

```powershell
curl.exe -i http://localhost:8080/geotravel/api/health
```

En **otra terminal**, desde la carpeta raiz del clon:

```powershell
Set-Location frontend
npm ci
npm run dev
```

Abrir **http://localhost:5173/eta** (o la URL mostrada por Vite).
El mapa usa Salto como region predeterminada (`frontend/src/components/region.js`;
`VITE_REGION` puede sobrescribirla).

En Linux/macOS la instalacion equivalente utiliza `cp .env.example .env`
y, desde `frontend`, `npm ci && npm run dev`.

## Datos de Salto cargados automaticamente

| Entidad | Referencia visible | Longitud | Latitud |
|---|---|---:|---:|
| Recurso | `TEST-ETA-SALTO-01` | -57.96215 | -31.39029 |
| Incidente | `TEST ETA Salto` | -57.95340 | -31.38927 |

`infra/init/seed.sh` ejecuta `db/seed/seed_salto_eta.sql` una sola vez, **tambien
si habia datos iniciales**. Comprueba las referencias existentes para evitar
duplicados y registra la ejecucion en `_seed_salto_eta_aplicado`. Si luego
eliminas los registros de prueba, no los recrea automaticamente.

**No asumas ID 5**: son numeros autogenerados, diferentes entre equipos.

## Comprobar API y ETA sin depender de IDs fijos

PowerShell, con Docker ya levantado:

```powershell
$api = "http://localhost:8080/geotravel/api"
$bbox = "-57.995,-31.405,-57.925,-31.365"
Invoke-RestMethod "$api/recursos?bbox=$bbox&limit=500"

$recursos = @(Invoke-RestMethod "$api/recursos")
$incidentes = @(Invoke-RestMethod "$api/incidentes")
$r = $recursos | Where-Object { $_.identificacion -eq "TEST-ETA-SALTO-01" } | Select-Object -First 1
$i = $incidentes | Where-Object { $_.titulo -eq "TEST ETA Salto" } | Select-Object -First 1
if (-not $r -or -not $i) { throw "Faltan los datos de demostracion ETA Salto" }
Invoke-RestMethod "$api/eta/recursos/$($r.id)/incidentes/$($i.id)" | ConvertTo-Json -Depth 15
```

La respuesta debe contener `distanciaMetros`, `duracionSegundos`,
`tiempoEstimadoMinutos` y `geometriaRuta` con `type: LineString`, coordenadas
**longitud, latitud**, EPSG:4326. En `/eta`, elegir esas referencias para ver
el recorrido vial verde y la lista de calles por las que pasa. Las cifras
dependen de la red vial de OpenStreetMap cargada (ver [RED_VIAL.md](RED_VIAL.md)):
la duracion es una estimacion sin transito, con la velocidad maxima de cada calle.

## Actualizar una instalacion que ya tenia una base Docker

Desde la raiz de tu clon:

```powershell
git pull --ff-only origin main
Set-Location infra
docker compose up -d --build
docker compose logs seed --tail=30
```

Si Compose no vuelve a ejecutar `seed` por haber completado su servicio
anteriormente, forzarlo de forma segura:

```powershell
docker compose run --rm seed
```

No hagas `docker compose down -v` con datos que quieras conservar: `-v`
elimina los volumenes de la base y GeoServer.

## Limites

- Los mapas base requieren **internet**. La ruta se calcula dentro de
  PostgreSQL (pgRouting) sobre la red vial de OpenStreetMap de todo Uruguay
  y no necesita internet ni un servicio de rutas aparte.
- Las calles (`via`) y puertas de `db/data/` son de **Salto** y sirven para el mapa
  y las direcciones; la red de rutas es de todo el pais y sale de OpenStreetMap.
- Para acceder desde un telefono u otra PC a una instancia alojada en un
  equipo distinto, configurar `VITE_API_URL`, `VITE_GEOSERVER_WMS_URL` y
  la direccion de escucha de Vite segun la red. `localhost` corresponde
  a la computadora donde se abre el navegador.
- La ruta ETA es un solo camino: el de menor tiempo por calles. Ver [RECURSOS_CERCANOS_RUTAS.md](RECURSOS_CERCANOS_RUTAS.md).
- Los cambios aqui descritos **no modifican `main`** ni crean un Pull Request.
