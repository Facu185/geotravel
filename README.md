# GeoTravel

Aplicación de gestión de recorridos turísticos para la empresa GeoTravel —
Taller de Sistemas de Información Geográficos Empresariales, Tecnólogo
Informático, Facultad de Ingeniería (UdelaR).

Zonas turísticas, atracciones puntuales y recorridos estacionales sobre un
mapa, con ABM para un administrador y una vista pública filtrada para
invitados. Ver `docs/diagramas/arquitectura.md` para el diagrama completo y
`docs/articulo/borrador.md` para el artículo del curso.

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
docker compose up -d
docker compose --profile tools run --rm flyway migrate   # aplica db/migrations/
docker compose exec -T db psql -U geotravel -d geotravel < ../db/seed/seed.sql
```

GeoServer queda en `http://localhost:8082/geoserver` (admin / geoserver, o lo
que hayas puesto en `.env`). Ahí:

1. Crear el workspace `geotravel`.
2. Crear el store PostGIS `geotravel` apuntando a `db` (host `localhost` desde
   tu máquina, o `db` si publicás desde otro contenedor), puerto `5432`,
   base `geotravel`.
3. Publicar las capas `zona_turistica`, `atraccion` y la vista
   `v_recorrido_geom` (ver `db/migrations/V2__vista_recorrido_geom.sql`).
4. Cargar los 3 estilos de `geoserver/styles/` (Estilos → Agregar nuevo → SLD)
   y asignarlos como estilo por defecto de cada capa.

Es el mismo flujo de workspace/store/capas/SLD que ya practicaron en el
Práctico 3, aplicado a este esquema.

### 2. Backend

```bash
cd backend
mvn clean package
# desplegar target/geotravel.war en Tomcat (o mvn tomcat7:run si agregan el plugin)
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
| Zonas + Atracciones | `backend/.../zonas`, `.../atracciones`, `frontend/.../zonas`, `.../atracciones` | P3 |
| Recorridos | `backend/.../recorridos`, `frontend/.../recorridos` | P4 |
| Consultas, reportes, vista Invitado | `backend/.../consultas`, `frontend/.../consultas`, `.../invitado` | P5 |

Actualizá los nombres reales del equipo acá, en `CONTRIBUTING.md` y en
`.github/CODEOWNERS`.

## Contribuir

Ver [`CONTRIBUTING.md`](CONTRIBUTING.md) — ramas, Pull Requests, cómo se
versiona el esquema de datos y el contrato de API.

## Estado

Base inicial: esquema de datos, endpoints núcleo (listado de zonas /
atracciones / recorridos, avanzar estado, 4 de las 5 consultas geográficas),
scaffold de frontend con navegación entre módulos, docker-compose para el
ambiente local, y CI de backend/frontend. El resto de cada módulo (ABM
completo, opcionales) queda por construir — ver `docs/api/openapi.yaml` para
lo que falta (marcado `TODO`).
