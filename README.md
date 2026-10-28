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
Salto de `db/data/vias.csv.gz`, los números de puerta de `db/data/accesos.csv.gz` y los datos de prueba, una sola vez), GeoServer (workspace,
store, capas y estilos) y el backend en Tomcat con el `.war` ya adentro. La primera vez tarda unos minutos (compila el backend y GeoServer arranca
lento); cuando termina quedan en `Exited (0)` `flyway`, `seed` y `geoserver-init`, es lo esperado.
Después, solo el frontend: `cd frontend && npm install && npm run dev`.

- **Día a día:** `docker compose up -d` (los datos quedan en volúmenes de Docker).
- **Cambió código del backend:** `docker compose up -d --build`.
- **Cambió un estilo SLD** de `geoserver/styles/`: `docker compose up -d` (se vuelve a subir solo).
- **Empezar de cero** (borra la base y la config de GeoServer): `docker compose down -v` y de nuevo `up -d --build`.
- **Flyway falla con "Migration checksum mismatch"** (la base se creó con migraciones que después se modificaron, por ejemplo V2 y V3 al pasar a Salto):
  `docker compose down -v` y de nuevo `up -d --build`. Una migración ya aplicada no se edita: los cambios van en una migración nueva (`V5__...sql`).

Todo es repetible: el seed no duplica datos y la configuración de GeoServer deja como está lo que
ya existe. Los pasos de abajo son el mismo proceso, a mano, por si hace falta hacer uno solo.

### Demostracion P2: ETA en Salto

En `feat/backend-p2`, Docker prepara automaticamente un recurso y un incidente
para **Salto, Uruguay** (`db/seed/seed_salto_eta.sql`). Funciona tanto en una
instalacion nueva como en una base Docker que ya tenga datos; nunca se asignan
IDs fijos. La pantalla `/eta` muestra distancia, duracion y la ruta vial
GeoJSON sobre Leaflet. El calculo de rutas utiliza un servicio OSRM con acceso
a internet.

**Ruta más corta (opcional):** el criterio `mas_corta` (minimiza distancia) usa un OSRM propio. Preparar los datos
con `infra/osrm/preparar.ps1` (o `.sh`), definir `OSRM_URL`/`OSRM_SHORTEST_URL` en `infra/.env` y levantar con
`docker compose --profile osrm up -d --build`. Detalles en [docs/RECURSOS_CERCANOS_RUTAS.md](docs/RECURSOS_CERCANOS_RUTAS.md).

**Guia de instalacion en otra computadora y verificaciones:**
[docs/ETA_SALTO_DEMO.md](docs/ETA_SALTO_DEMO.md).

#### Configuracion de localidad del backend

`VITE_REGION` solo controla el encuadre del mapa en React. El backend configura por separado
el servicio de direcciones IDE mediante `IDE_DEPARTAMENTO` e `IDE_LOCALIDAD` en `infra/.env`;
ambos usan `salto` por defecto y pueden fijarse en otro lugar (por ejemplo `montevideo`).
La tabla local `acceso` (números de puerta) y la red vial `via` disponibles en `db/data/` son de Salto.
Por eso con Salto `/consultas/geocodificar` busca primero en `acceso` y recién después en la IDE (que se usa
siempre para las esquinas pedidas con `esquina` y para cualquier otro departamento o localidad), y
`/consultas/calles` y `/consultas/interseccion` trabajan sobre las calles de Salto.

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

- **Calles** (`via`, 3.239 tramos de Salto): ejes de calle de OpenStreetMap (© colaboradores de OpenStreetMap,
  licencia ODbL), bajados con Overpass API (`way["highway"]["name"]` en el rectángulo de Salto, recortados a él).
  El tipo de vía (`tipo`) se deriva de la etiqueta `highway` para que lo reconozca el estilo `vias_tipo.sld`.
  Archivo `db/data/vias.csv.gz` (nombre, tipo y geometría en WKT lon/lat; `seed.sh` la pasa a EPSG:32721).
  Si la base ya tenía calles de otra ciudad, `seed.sh` no las pisa: ver "Cambiar las calles" más abajo.
- **Números de puerta** (`acceso`, 31.007 puertas de Salto): archivo `db/data/accesos.csv.gz`
  (`num_puerta, letra, nom_calle, cod_nombre, x, y`, en EPSG:32721). Con ella `/consultas/geocodificar` ubica
  una dirección ("calle número"), comparando el nombre de la calle sin tildes y con las palabras completas
  (`Av.` = AVENIDA, `Gral` = GENERAL, `Dr` = DOCTOR). El archivo ya viene en el repo y no hace falta tocarlo;
  para cambiarlo, `docker compose down -v` y volver a levantar.

**Cambiar las calles en una base que ya existe** (por ejemplo, la que tenía las de Montevideo), sin perder
zonas, recursos ni incidentes. Desde `infra/`:

```bash
docker compose exec db psql -U geotravel -d geotravel -c "TRUNCATE via RESTART IDENTITY"
docker compose run --rm seed
# GeoServer guarda la extensión de cada capa al publicarla: se recalcula para que dibuje Salto
curl -u admin:geoserver -X PUT -H "Content-Type: application/json" \
  -d '{"featureType":{"name":"via","enabled":true}}' \
  "http://localhost:8082/geoserver/rest/workspaces/geotravel/datastores/geotravel/featuretypes/via?recalculate=nativebbox,latlonbbox"
```

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

## Ingreso y vistas

Hay dos vistas, separadas por un login básico:

| Vista | Cómo se entra | Qué ve |
|---|---|---|
| **Invitado** | Sin ingresar: es la pantalla inicial | El mapa público, con filtros, conteos y detalle |
| **Administrador** | `/login` (botón "Ingresar") | Todo lo anterior, más zonas, recursos, incidentes y consultas |

- **Usuario de prueba:** `admin` / `urbansafe`. Se cambian con `ADMIN_USUARIO` y `ADMIN_CLAVE` en `infra/.env`
  (ver `infra/.env.example`). Hay un único usuario; no hay ABM de usuarios.
- **Cómo funciona:** `POST /auth/login` devuelve un token (vale 8 horas, vive en la memoria del backend: si se
  reinicia hay que ingresar de nuevo) que el frontend manda en `Authorization: Bearer ...`. Un filtro del backend
  (`auth/AuthFilter.java`) **protege toda la API por defecto**: solo son públicos `/health`, `/auth/login`,
  `/auth/logout`, `GET /fotos/...` y la lectura de las Consultas del invitado (`GET /consultas/...` salvo el reporte,
  el listado `GET /zonas|/incidentes|/recursos` y `GET /eta/criterios`). Escribir siempre exige sesión. El mapa público dibuja con GeoServer.
- **En el frontend:** `frontend/src/auth/` (sesión, pantalla de ingreso y `RutaAdmin`, que manda al ingreso si no
  hay sesión). En Postman, correr primero la carpeta 0, que guarda el token.

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

## Preguntas para el tutor

La letra deja algunas decisiones sin especificar; se tomó un supuesto razonable en cada caso,
documentado en el código (buscar "SUPUESTO").

**Aclaradas por el tutor:**

- **Consultas 2 y 8:** era la misma consulta (error de la letra, ya corregida). Queda la consulta 2 por
  cantidad de incidentes (el extra por incidentes/km² se quitó).
- **Ubicación de los recursos:** es la ubicación geográfica del recurso, que se elige en el mapa al
  registrarlo y se ve en el mapa en las consultas del invitado.
- **Líneas:** la ubicación de un incidente puede ser un punto, una línea (por ejemplo una calle cortada) o un polígono (la letra dice "zona": un área, no una zona operativa).
- **Histórico:** historial de estados de cada incidente, con estado, fecha, hora y usuario.

**Siguen abiertas:**

- **Guardado de las geografías:** se guarda por el backend (REST) y GeoServer solo publica y dibuja
  (WMS/WFS de lectura). No se usa WFS-T; falta confirmar que sea lo esperado.
- **Direcciones** (consultas 4 y 5): en Salto se buscan en la tabla de puertas `acceso` (capa de GeoServer);
  en el resto del país, por departamento y localidad de la región configurada, y las esquinas, las resuelve el
  servicio de direcciones de la IDE (internet). El mapa de fondo (Esri/OpenStreetMap) también usa internet.
- **Diagrama de estados de un incidente** (`IncidenteResource.java`): solo se da un ejemplo lineal y se
  menciona que existen derivación y cancelación, sin dibujar el diagrama completo.
- **Relación incidente–recurso** (`incidente_recurso`): se modeló N a M con fecha de asignación; podría ser
  más simple (un recurso por incidente).
- **Escala de `nivel_prioridad`**: se asumió 1–5 (1 = máxima).

## Estado

Base reestructurada para UrbanSafe: esquema de datos, endpoints núcleo (ABM
completo de zonas y recursos, incidentes con máquina de estados por ramas y
avanzar/historial, las 7 consultas geográficas + 1 reporte, búsqueda por dirección con números de puerta, cruce de calles y mapa público con filtros y detalle), carga a demanda (solo lo visible, con tope; el resto lo dibuja GeoServer), incidentes como punto, línea o polígono, datos de prueba en Salto y Montevideo, frontend con
navegación entre módulos, docker-compose para el ambiente local, y CI de
backend/frontend. Verificado de punta a punta (compilación, casos de API,
navegador) antes de subir — ver el detalle en el historial de commits.
