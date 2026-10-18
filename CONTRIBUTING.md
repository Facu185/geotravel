# Cómo contribuir

## Ramas

- `main` está protegida: nadie pushea directo, todo entra por Pull Request.
- Nombrá la rama por módulo y tarea: `feat/<modulo>-<descripcion>`, `fix/<modulo>-<descripcion>`.
  - Ejemplos: `feat/zonas-abm`, `feat/incidentes-estados`, `fix/geoserver-sld-color`.
- Módulos: `datos`, `backend`, `zonas`, `recursos`, `incidentes`, `consultas`, `invitado`, `infra`, `docs`.

## Pull Requests

- Como mínimo **1 revisión** de otro compañero antes de mergear (no hace falta que sea del mismo módulo — así todos van conociendo el resto del sistema).
- El PR se abre con la plantilla (`.github/PULL_REQUEST_TEMPLATE.md`) completa.
- El CI (`backend-ci` / `frontend-ci`) tiene que pasar en verde.
- Si el cambio toca el esquema de datos, va como una migración nueva en `db/migrations/` (nunca editando una migración ya mergeada a `main`).
- Si el cambio agrega o modifica un endpoint, actualizá `docs/api/openapi.yaml` en el mismo PR.

## Cómo levantar el ambiente local

1. `cd infra && docker compose up -d` — levanta PostgreSQL/PostGIS y GeoServer.
2. Backend: `cd backend && mvn clean package && ` desplegar el `.war` generado en Tomcat (o `mvn tomcat7:run` si agregan el plugin).
3. Frontend: `cd frontend && npm install && npm run dev`.
4. Ver `README.md` para las URLs y credenciales por defecto.

## Convención de commits

No es obligatorio un formato estricto, pero ayuda mucho para el artículo final (sección "desarrollo del proyecto") que el mensaje diga **qué** y **para qué módulo**:

```
zonas: agrega validación de solapamiento al guardar
incidentes: endpoint para avanzar estado
docs: agrega diagrama de arquitectura
```

## Dueños por módulo (referencia)

| Carpeta | Módulo | Responsable |
|---|---|---|
| `db/`, `geoserver/` | Datos & GeoServer | P1 · Nahuel |
| `backend/.../health`, `backend/.../db` | Backend base & reglas | P2 · Nicolas |
| `backend/.../zonas`, `.../recursos`, `frontend/.../zonas`, `.../recursos` | Zonas Operativas + Recursos | P3 · Facundo |
| `backend/.../incidentes`, `frontend/.../incidentes` | Incidentes | P4 · Bruno |
| `backend/.../consultas`, `frontend/.../consultas`, `.../invitado` | Consultas, reportes, vista invitado | P5 · Gonzalo |

Falta reflejar los usuarios de GitHub de cada uno en `.github/CODEOWNERS`.
