# Checklist de requerimientos — UrbanSafe

Fuente: *Taller de Sistemas de Información Geográficos, Proyecto 2026 — Sistema de Gestión Geográfica de Emergencias Urbanas*
(`letra_2026/Laboratorio 2026 - 2sem.pdf`), en la numeración de 44 puntos armada a partir de la letra. Estado verificado contra el código el 11/11/2026.

Leyenda: ✅ hecho · 🚫 no va (decisión tomada) · ⚠️ dudas para el tutor, al final

## Resumen

- **43 de 44 hechos.** El que no va es el 33, el control de superposición entre zonas (opcional): las zonas se pueden superponer.
- Hay tres dudas para el tutor (zonas superpuestas por escrito, estados finales, histórico por zona), al final del documento.

## ABM Zonas operativas

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 1 | Alta | ✅ | `POST /zonas` · `ZonasPage.jsx`, `EditorGeometria.jsx` |
| 2 | Baja | ✅ | `DELETE /zonas/{id}` |
| 3 | Modificación (también de la geometría) | ✅ | `PUT /zonas/{id}` con validación de polígono |
| 4 | Datos: nombre, descripción, nivel de prioridad, responsable, observaciones y geometría | ✅ | tabla `zona_operativa` |
| 5 | Visualizar las zonas directamente sobre el mapa | ✅ | capa `zona_operativa` de GeoServer |

## ABM Incidentes

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 6 | Alta | ✅ | `POST /incidentes` · `IncidentesPage.jsx` |
| 7 | Baja | ✅ | `DELETE /incidentes/{id}` |
| 8 | Modificación | ✅ | `PUT /incidentes/{id}` |
| 9 | Datos: título, descripción, tipo, prioridad, estado, fecha y hora de registro, equipo responsable y ubicación | ✅ | tabla `incidente` (`V1__init.sql`, `V4__incidente_geom.sql`) |
| 10 | Cada estado con un color distinto en el mapa | ✅ | `geoserver/styles/incidentes_estado.sld` (generado con `generar_sld_incidentes.py`) |
| 11 | Incidentes como puntos, líneas o polígonos | ✅ | `EditorGeometria.jsx`, validación en `IncidenteResource` |

## ABM Recursos

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 12 | Alta | ✅ | `POST /recursos` · `RecursosPage.jsx` |
| 13 | Baja | ✅ | `DELETE /recursos/{id}` |
| 14 | Modificación | ✅ | `PUT /recursos/{id}` |
| 15 | Datos: identificación, nombre, tipo, estado operativo, descripción y ubicación | ✅ | tabla `recurso` |
| 16 | Tipos: ambulancias, vehículos de bomberos, patrullas, centros de atención y otros | ✅ | `recurso.tipo`, un ícono por tipo (`docs/ICONOS.md`) |

## Estados, histórico y reporte

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 17 | Avanzar incidente (cambiar el estado) | ✅ | `POST /incidentes/{id}/avanzar`, tabla `TRANSICIONES` (Registrado → En atención → Resuelto, más derivación y cancelación) |
| 18 | Histórico: estado, fecha y hora y usuario responsable del cambio, de cada incidente | ✅ | tabla `historial_estado`; el usuario sale de la sesión · `GET /incidentes/{id}/historial` |
| 19 | Reporte de incidentes por zona, filtrado por zona, tipo, prioridad, estado y rango de fechas | ✅ | `GET /consultas/reportes/incidentes-por-zona` (la zona se elige con un clic en el mapa) |
| 20 | Resultados agrupados según las zonas operativas | ✅ | mismo reporte (`GROUP BY` por zona) |

## Consultas geográficas

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 21 | Consulta 1: incidentes de una zona seleccionada, en el mapa | ✅ | `incidentes-por-zona/{zonaId}` (`ST_Intersects`) |
| 22 | Consulta 2: zonas con mayor cantidad de incidentes en un período | ✅ | `zonas-mas-incidentes?desde=&hasta=` |
| 23 | Consulta 3: recursos operativos más cercanos a un incidente | ✅ | `recursos-cercanos/{id}/analisis-vial` (`<->`, cantidad a elegir, rutas por calles con pgRouting) |
| 24 | Consulta 4: incidente más cercano a una dirección o intersección | ✅ | `incidente-mas-cercano`, con `geocodificar` e `interseccion` |
| 25 | Consulta 5: zona operativa de una dirección | ✅ | `zona-por-punto` (`ST_Contains`) |
| 26 | Consulta 6: recursos dentro de una zona | ✅ | `recursos-por-zona/{zonaId}` |
| 27 | Consulta 7: incidentes atendidos o asociados a un recurso | ✅ | `incidentes-por-recurso/{recursoId}`, tabla `incidente_recurso` |

## Usuario invitado (solo lectura)

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 28 | Visualizar información geográfica sin modificar; incidentes, recursos y zonas en el mapa con filtros | ✅ | `InvitadoPage.jsx`, `capas.js`, `filtros.js`; el backend deniega por defecto sin sesión (`AuthFilter.java`) |
| 29 | Incidentes: filtrar por tipo, estado, prioridad y fecha | ✅ | `filtros.js` (`desde` y `hasta`) |
| 30 | Seleccionar un incidente y ver su información detallada | ✅ | `detalle.jsx` (clic en el mapa, `GetFeatureInfo`) |
| 31 | Recursos: ver tipo, estado operativo y ubicación | ✅ | `detalle.jsx`, filtros por tipo y estado |
| 32 | Zonas: ver las zonas y su información básica | ✅ | `detalle.jsx` |

## Opcionales

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 33 | Control de superposición entre zonas operativas | 🚫 | no va: las zonas se pueden superponer (ver duda 1) |
| 34 | Tiempo estimado de llegada de un recurso | ✅ | `EtaResource.java`, `p2_calcular_ruta` (pgRouting) |
| 35 | Recurso operativo más cercano a un incidente | ✅ | `GET /eta/incidentes/{id}/recurso-mas-cercano` (`RecursoMasCercano.java`): el de menos metros por calles, trazando el camino; botón en el detalle del incidente |
| 36 | Mapa de calor de concentración de incidentes | ✅ | `CapaCalor.jsx` + `incidentes_calor.sld` (`vec:Heatmap`), en el mapa público |

## No funcionales

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 37 | Responsive (computadoras, tablets y móviles) | ✅ | `@media (max-width: 799px)` en `styles.css`, panel que se pliega en móvil |
| 38 | Interfaz con mapa para interactuar con la información geográfica | ✅ | React + Leaflet |
| 39 | Operaciones espaciales con las capacidades geográficas de la base | ✅ | todas son SQL de PostGIS (`ST_Intersects`, `ST_Contains`, `<->`, `ST_Distance`, pgRouting) |

## Tecnologías

| # | Requerimiento | Estado | Dónde |
|---|---|---|---|
| 40 | Backend: JEE con Tomcat | ✅ | Jersey sobre Tomcat 9 |
| 41 | Servidor de mapas: GeoServer | ✅ | WMS/WFS, estilos SLD, GeoWebCache |
| 42 | Base de datos: PostgreSQL + PostGIS | ✅ | imagen `postgis/postgis` con pgRouting |
| 43 | Frontend: React con Leaflet | ✅ | `frontend/` |
| 44 | Interfaz de usuario | ✅ | React, de libre elección según la letra |

## Para llevar al tutor

1. **Zonas superpuestas (punto 33).** La letra dice que las zonas "no deben superponerse" y deja el control como opcional. El tutor dijo que
   **sí pueden superponerse** y así está hecho: el guardado solo valida que el polígono sea válido, y la consulta 5 devuelve todas las zonas que
   contienen un punto. Conviene tenerlo por escrito, porque contra la letra figura como incumplimiento. Si pide lo contrario, el control está
   pensado (trigger comentado en `V1__init.sql`, `ST_Overlaps` más una comprobación de zona idéntica o contenida).
2. **Estados finales (punto 17).** Resuelto y Cancelado no tienen salida: es un supuesto nuestro (`IncidenteResource.java`). Un apunte de otra
   reunión dice «cambios de estados en cualquier sentido»; si es así, hay que abrir las salidas.
3. **Histórico por zona (punto 18).** La letra pide el historial de cada incidente y está hecho. Unos apuntes hablan de verlo filtrado por estado y fechas
   y agrupado por zona; eso no existe. Confirmar si se espera.
