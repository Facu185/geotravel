@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

where docker >nul 2>nul
if errorlevel 1 (
  echo Docker Desktop y Docker Compose deben estar instalados.
  exit /b 1
)

where npm.cmd >nul 2>nul
if errorlevel 1 (
  echo Node.js y npm deben estar instalados.
  exit /b 1
)

if not exist "infra\.env" if exist "infra\.env.example" (
  copy "infra\.env.example" "infra\.env" >nul
  echo Se creo infra\.env desde infra\.env.example.
)

if not exist "frontend\node_modules" (
  echo Instalando dependencias del frontend...
  pushd frontend
  call npm.cmd install
  if errorlevel 1 (
    set "INSTALL_EXIT=!ERRORLEVEL!"
    popd
    exit /b !INSTALL_EXIT!
  )
  popd
)

echo Aplicacion web: http://localhost:5173
echo Backend:  http://localhost:8080/geotravel/api/health
echo GeoServer: http://localhost:8082/geoserver
echo Detene Docker Compose con Ctrl+C; luego cierra la ventana del frontend.
netstat -ano | findstr /R /C:":5173 .*LISTENING" >nul
if errorlevel 1 (
  start "UrbanSafe Frontend" /D "%CD%\frontend" cmd.exe /k npm.cmd run dev -- --host 0.0.0.0
) else (
  echo Ya hay un servicio escuchando en el puerto 5173; se reutiliza.
)
start "" "http://localhost:5173"

docker compose --project-directory "%CD%\infra" -f "%CD%\infra\docker-compose.yml" up --build --watch
exit /b %ERRORLEVEL%