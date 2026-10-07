# UrbanSafe

Sistema de gestión geográfica de emergencias urbanas para la empresa
UrbanSafe — Taller de Sistemas de Información Geográficos Empresariales,
Tecnólogo Informático, Facultad de Ingeniería (UdelaR).

> Este repo empezó como "GeoTravel" (recorridos turísticos, 1er semestre) y se
> reestructuró para "UrbanSafe" al cambiar la letra del proyecto. La
> arquitectura (PostGIS + GeoServer + Jersey + React/Leaflet, patrón de
> módulos, CI, validaciones) se mantuvo — lo que cambió es el dominio. El
> historial de Git conserva el trabajo de GeoTravel como referencia.

Zonas operativas, recursos de emergencia (ambulancias, bomberos, patrullas) e
incidentes urbanos sobre un mapa, con ABM para un administrador y una vista
pública filtrada para invitados. Ver `docs/diagramas/arquitectura.md` para el
diagrama completo y `docs/articulo/borrador.md` para el artículo del curso.

## Stack

- **Datos:** PostgreSQL + PostGIS
- **Mapas:** GeoServer (WMS/WFS, estilos SLD)
- **Backend:** Java EE (Jersey/JAX-RS) sobre Tomcat
- **Frontend:** React + Leaflet

## Estructura del repo

```
backend/      API REST (JEE / Jersey) — un paquete por módulo
frontend/     React + Leaflet — una carpeta por módulo bajo src/modules/
db/           esquema versionado (Flyway) + datos de prueba
geoserver/    estilos SLD de las capas
infra/        docker-compose para levantar PostGIS + GeoServer local
docs/         contrato de API (OpenAPI), diagramas, borrador del artículo
```

## Cómo levantar todo local

### 1. Datos: PostGIS + GeoServer

```bash
cd infra
cp .env.example .env          # ajustar si hace falta
docker compose up -d db geoserver
docker compose --profile tools run --rm flyway migrate   # aplica db/migrations/
docker compose cp ../db/seed/seed.sql db:/tmp/seed.sql
docker compose exec db psql -U geotravel -d geotravel -f /tmp/seed.sql
```

GeoServer queda en `http://localhost:8082/geoserver` (admin / geoserver, o lo
que hayas puesto en `.env`). Ahí:

1. Crear el workspace `geotravel` (nombre heredado del repo; no hace falta
   renombrarlo, es solo un identificador).
2. Crear el store PostGIS `geotravel` apuntando a `db` (host `localhost` desde
   tu máquina, o `db` si publicás desde otro contenedor), puerto `5432`,
   base `geotravel`.
3. Publicar las capas `zona_operativa`, `recurso` e `incidente`.
4. Cargar los estilos de `geoserver/styles/` (Estilos → Agregar nuevo → SLD;
   están a nombre de "zonas_atractivo"/"atracciones_clasificacion" por
   herencia de GeoTravel — renombrarlos y adaptar sus reglas a los campos
   nuevos, `nivel_prioridad`/`estado`/`tipo`, es tarea de P1).

Es el mismo flujo de workspace/store/capas/SLD que ya practicaron en el
Práctico 3, aplicado a este esquema.

### 2. Backend

```bash
cd backend
mvn clean package
# desplegar target/geotravel.war en Tomcat (o mvn tomcat7:run si agregan el plugin)
```

Si no tenés Maven instalado, se puede compilar con Docker (ver
`infra/docker-compose.yml`, servicio `backend-build`):

```bash
cd infra
docker compose --profile tools run --rm backend-build
docker compose cp ../backend/target/geotravel.war backend:/usr/local/tomcat/webapps/geotravel.war
```

Variables de entorno que lee (ver `backend/src/main/java/.../db/DataSourceProvider.java`):
`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` (default: `localhost`,
`5432`, `geotravel`, `geotravel`, `geotravel`).

Probar: `http://localhost:8080/geotravel/api/health` → `{"status":"ok",...}`.

### 3. Frontend

```bash
cd frontend
cp .env.example .env.local     # ajustar VITE_API_URL / VITE_GEOSERVER_WMS_URL
npm install
npm run dev
```

Abre en `http://localhost:5173`.

## Módulos y dueños

| Módulo | Carpetas | Responsable |
|---|---|---|
| Datos & GeoServer | `db/`, `geoserver/`, `infra/` | P1 |
| Backend base & reglas de negocio | `backend/.../db`, `.../health`, `web.xml` | P2 |
| Zonas Operativas + Recursos | `backend/.../zonas`, `.../recursos`, `frontend/.../zonas`, `.../recursos` | P3 |
| Incidentes | `backend/.../incidentes`, `frontend/.../incidentes` | P4 |
| Consultas, reportes, vista Invitado | `backend/.../consultas`, `frontend/.../consultas`, `.../invitado` | P5 |

Actualizá los nombres reales del equipo acá, en `CONTRIBUTING.md` y en
`.github/CODEOWNERS`.

## Contribuir

Ver [`CONTRIBUTING.md`](CONTRIBUTING.md) — ramas, Pull Requests, cómo se
versiona el esquema de datos y el contrato de API.

## Preguntas abiertas para el tutor

La letra deja algunas decisiones sin especificar; se tomó un supuesto
razonable en cada caso, documentado en el código (buscar "SUPUESTO"):

- **Diagrama de estados de un incidente** (`IncidenteResource.java`): solo se
  da un ejemplo lineal y se menciona que existen derivación y cancelación,
  sin dibujar el diagrama completo.
- **Relación incidente–recurso** (`incidente_recurso`): se modeló N a M con
  fecha de asignación; podría ser más simple (un recurso por incidente).
- **"Zonas con mayor cantidad" vs. "mayor concentración" de incidentes**: se
  implementaron como dos consultas distintas (conteo bruto vs. incidentes/km²)
  por no tener claro si la letra las considera lo mismo.
- **Escala de `nivel_prioridad`**: se asumió 1–5 (1 = máxima), igual que el
  "nivel de atractivo" de GeoTravel.

## Estado

Base reestructurada para UrbanSafe: esquema de datos, endpoints núcleo (ABM
completo de zonas y recursos, incidentes con máquina de estados por ramas y
avanzar/historial, las 8 consultas geográficas + 1 reporte), frontend con
navegación entre módulos, docker-compose para el ambiente local, y CI de
backend/frontend. Verificado de punta a punta (compilación, casos de API,
navegador) antes de subir — ver el detalle en el historial de commits.
