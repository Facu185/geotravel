# P2 - Cálculo opcional de tiempo estimado de llegada (OSRM)

## Qué implementamos

`GET /geotravel/api/eta/recursos/{recursoId}/incidentes/{incidenteId}`

1. El backend busca en **PostgreSQL/PostGIS** las geometrías del recurso y el incidente, almacenadas en **EPSG:32721**.
2. PostGIS obtiene la posición del recurso y, para incidentes de tipo línea/polígono, un punto del incidente cercano al recurso usando `ST_ClosestPoint`.
3. `ST_Transform` transforma ambas posiciones a **EPSG:4326**, que usa OSRM, en orden longitud, latitud.
4. Java 11 `HttpClient` consulta el perfil `driving` de **OSRM** y recibe longitud del recorrido (metros) y duración (segundos).
5. El endpoint devuelve los minutos estimados redondeados hacia arriba. No utiliza tráfico en tiempo real.

## Para ejecutar en Windows (PowerShell)

Desde la raíz del repositorio:

```powershell
mvn -f backend/pom.xml clean package
Set-Location infra
docker compose up -d --build
curl.exe -i http://localhost:8080/geotravel/api/eta/recursos/1/incidentes/1
```

La ruta usa los datos de prueba solo si existen recurso 1 e incidente 1. La respuesta HTTP 200 tiene el siguiente formato, con cifras que cambian según OSRM:

```json
{
  "recursoId": 1,
  "incidenteId": 1,
  "distanciaMetros": 1800,
  "duracionSegundos": 260,
  "tiempoEstimadoMinutos": 5,
  "motor": "OSRM driving",
  "aclaracion": "Estimacion de recorrido vial sin trafico en tiempo real"
}
```

**Los números son únicamente un ejemplo de formato, no tiempos medidos.** El servicio público `https://router.project-osrm.org` es de demostración: puede limitarse, fallar o no estar disponible en la defensa. Para un uso estable se necesita desplegar OSRM con datos OSM del área y establecer `OSRM_URL` en `infra/.env`, seguido de `docker compose up -d --build backend`. No afirmar que es un cálculo en tiempo real: es una estimación de tiempo de viaje vial basada en el perfil OSRM.

## Respuestas y errores

- `200`: ruta disponible, con distancia y duración.
- `400`: identificadores no positivos.
- `404`: recurso o incidente ausente de la base.
- `422`: OSRM indica `NoRoute`.
- `503`: error de conexión/servicio OSRM, incluido timeout.

## Pruebas

`OsrmClientTest` incluye tres pruebas unitarias sin llamadas externas: ruta correcta, ruta inexistente y respuesta incompleta. Para comprobar toda la integración es necesaria una conexión OSRM funcional. El frontend aún no tiene un botón para mostrar esta respuesta; se demuestra por el endpoint REST.
