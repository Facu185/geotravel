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

### Arranque rápido (recomendado)

```bash
cd infra
cp .env.example .env          # solo la primera vez; ajustar si hace falta
docker compose up -d --build
```

Un solo comando levanta y deja configurado todo: la base (con sus migraciones, la red vial de
Montevideo de `db/data/vias.sql.gz`, los 378 mil números de puerta de `db/data/accesos.csv.gz` y los datos de prueba, una sola vez), GeoServer (workspace,
store, capas y estilos) y el backend en Tomcat con el `.war` ya adentro. La primera vez tarda unos minutos (compila el backend y GeoServer arranca
lento); cuando termina quedan en `Exited (0)` `flyway`, `seed` y `geoserver-init`, es lo esperado.
Después, solo el frontend: `cd frontend && npm install && npm run dev`.

- **Día a día:** `docker compose up -d` (los datos quedan en volúmenes de Docker).
- **Cambió código del backend:** `docker compose up -d --build`.
- **Cambió un estilo SLD** de `geoserver/styles/`: `docker compose up -d` (se vuelve a subir solo).
- **Empezar de cero** (borra la base y la config de GeoServer): `docker compose down -v` y de nuevo `up -d --build`.

Todo es repetible: el seed no duplica datos y la configuración de GeoServer deja como está lo que
ya existe. Los pasos de abajo son el mismo proceso, a mano, por si hace falta hacer uno solo.

### 1. Datos: PostGIS + GeoServer (a mano)

Cada paso es uno de los servicios que levanta `docker compose up -d`; se pueden correr de a uno
(todos son repetibles):

```bash
cd infra
cp .env.example .env          # ajustar si hace falta
docker compose up -d db geoserver
docker compose run --rm flyway          # aplica db/migrations/: V1 esquema, V2 calles, V3 puertas
docker compose run --rm seed            # carga calles, puertas y datos de prueba (una sola vez)
docker compose run --rm geoserver-init  # workspace, store, capas y estilos de GeoServer
```

GeoServer queda en `http://localhost:8082/geoserver` (admin / geoserver, o lo
que hayas puesto en `.env`). `geoserver-init` hace por la API REST lo que se haría a mano
(el mismo flujo de workspace/store/capas/SLD del Práctico 3):

1. Workspace `geotravel` (nombre heredado del repo; es solo un identificador).
2. Store PostGIS `geotravel` apuntando a la base (host `db`, puerto `5432`).
3. Capas: `zona_operativa`, `recurso`, `incidente`, `via` (calles) y `acceso` (números de puerta).
4. Estilos de `geoserver/styles/`, uno por capa: `zonas_nivel_prioridad`, `recursos_tipo`,
   `incidentes_estado`, `vias_tipo` y `accesos_puerta`.

#### Datos de referencia (calles y puertas)

Son capas de consulta, no se editan desde la aplicación:

- **Calles** (`via`, 33.325 tramos): ejes de calle del curso (`v_sig_vias`). Archivo `db/data/vias.sql.gz`.
- **Números de puerta** (`acceso`, 377.883 puertas): capa `mdg_accesos` del WFS de la Intendencia de
  Montevideo (datos abiertos), con el nombre de la calle tomado de `v_mdg_vias_montevideo`. Archivo
  `db/data/accesos.csv.gz`. Con ella `/consultas/geocodificar` ubica una dirección ("calle número").
  El archivo ya viene en el repo y no hace falta tocarlo. Si hiciera falta bajar los datos de nuevo: el
  servicio no deja pedir la capa entera de una vez, hay que pedirla por tramos con un filtro CQL sobre
  `gid_tramo_via` (por ejemplo `visible=true AND gid_tramo_via BETWEEN 6800000 AND 6899999`), unir cada puerta
  con su calle por `gid_tramo_via = gid` de `v_mdg_vias_montevideo`, y volver a armar el CSV
  (`num_puerta, letra, nom_calle, cod_nombre, x, y`, en EPSG:32721). Después, `docker compose down -v` y
  volver a levantar para que se carguen.

### 2. Backend

```bash
cd backend
mvn clean package
# desplegar target/geotravel.war en Tomcat (o mvn tomcat7:run si agregan el plugin)
```

Si no tenés Maven instalado, el servicio `backend` de Docker lo compila y lo despliega solo:

```bash
cd infra
docker compose up -d --build backend
```

(El servicio opcional `backend-build`, con `--profile tools`, solo compila para revisar errores.)

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
- **Guardado de las geografías:** se guarda por el backend (REST) y GeoServer solo publica y dibuja
  (WMS/WFS de lectura). No se usa WFS-T; falta confirmar que sea lo esperado.
- **Direcciones** (consultas 4 y 5): se buscan en la tabla de puertas `acceso` (capa de GeoServer);
  lo que no resuelve ("calle esquina calle") pasa al servicio de direcciones de la IDE (internet). El mapa
  de fondo (Esri/OpenStreetMap) también usa internet.
- **Filtro "ubicación" de recursos** en la vista Invitado: hoy se filtra por tipo y estado.
- **Líneas:** zonas son polígonos e incidentes y recursos son puntos; falta saber si la ubicación de un
  incidente puede ser una línea (por ejemplo una calle cortada).
- **Escala de `nivel_prioridad`**: se asumió 1–5 (1 = máxima), igual que el
  "nivel de atractivo" de GeoTravel.

## Estado

Base reestructurada para UrbanSafe: esquema de datos, endpoints núcleo (ABM
completo de zonas y recursos, incidentes con máquina de estados por ramas y
avanzar/historial, las 8 consultas geográficas + 1 reporte, búsqueda por dirección con números de puerta, cruce de calles y mapa público con filtros y detalle), frontend con
navegación entre módulos, docker-compose para el ambiente local, y CI de
backend/frontend. Verificado de punta a punta (compilación, casos de API,
navegador) antes de subir — ver el detalle en el historial de commits.
