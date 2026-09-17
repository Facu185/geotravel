# Cómo contribuir

## Ramas

- `main` está protegida: nadie pushea directo, todo entra por Pull Request.
- Nombrá la rama por módulo y tarea: `feat/<modulo>-<descripcion>`, `fix/<modulo>-<descripcion>`.
  - Ejemplos: `feat/zonas-abm`, `feat/recorridos-estados`, `fix/geoserver-sld-color`.
- Módulos: `datos`, `backend`, `zonas`, `atracciones`, `recorridos`, `consultas`, `invitado`, `infra`, `docs`.

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
recorridos: endpoint para avanzar estado
docs: agrega diagrama de arquitectura
```

## Dueños por módulo (referencia)

| Carpeta | Módulo | Responsable |
|---|---|---|
| `db/`, `geoserver/` | Datos & GeoServer | P1 |
| `backend/.../health`, `backend/.../db` | Backend base & reglas | P2 |
| `backend/.../zonas`, `.../atracciones`, `frontend/.../zonas`, `.../atracciones` | Zonas + Atracciones | P3 |
| `backend/.../recorridos`, `frontend/.../recorridos` | Recorridos | P4 |
| `backend/.../consultas`, `frontend/.../consultas`, `.../invitado` | Consultas, reportes, vista invitado | P5 |

Actualizá esta tabla con los nombres/usuarios reales del equipo y reflejalos también en `.github/CODEOWNERS`.
