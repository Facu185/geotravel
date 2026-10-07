# [Título del artículo]

*Borrador colaborativo. Estructura tomada de `template-paper-2013.doc` del curso —
antes de entregar, pasar este contenido al formato/plantilla que pida la cátedra.*

Autores: [P1] · [P2] · [P3] · [P4] · [P5]

## Resumen

[2-3 oraciones: motivación, qué se construyó, resultado principal.]

**Palabras clave:** GIS, PostGIS, GeoServer, WFS, WMS, SLD, sistema de gestión de emergencias urbanas.

## Introducción

[Contexto de UrbanSafe, desafío del proyecto (desarrollo de una app geográfica
JEE + PostGIS + GeoServer), organización del resto del documento.]

## Marco conceptual

[Web services geográficos (WMS/WFS), bases de datos geográficas, SLD — apoyarse
en lo documentado en los Prácticos 2 y 3 del curso.]

## Descripción del problema

[Resumen del enunciado: entidades (zona operativa, incidente, recurso), roles
(administrador/invitado), reglas de negocio (máquina de estados de un
incidente, no-solapamiento de zonas operativas).]

## Solución planteada

[Visión general de la solución. Insertar acá el diagrama de
`docs/diagramas/arquitectura.md`.]

## Arquitectura del sistema

[Detalle de las 4 capas: datos, GeoServer, backend, frontend, y cómo se
comunican — ver `docs/diagramas/arquitectura.md`.]

## Implementación

### Productos y herramientas

| Producto | Puntos fuertes | Puntos débiles | Evaluación general |
|---|---|---|---|
| PostGIS | | | |
| GeoServer | | | |
| React + Leaflet/OpenLayers | | | |
| Jersey (JAX-RS) | | | |

### Problemas encontrados

[Qué se trabó y cómo se resolvió — cada módulo aporta lo suyo acá. Ejemplos
concretos de este proyecto que pueden ir acá:
- El cambio de letra a mitad de semestre (de GeoTravel a UrbanSafe) y cómo
  se reestructuró el repo reaprovechando la arquitectura.
- Por qué `ST_Overlaps` no alcanza para "las zonas no deben superponerse"
  (no detecta una zona idéntica ni una contenida dentro de otra) y se usó
  `ST_Intersects AND NOT ST_Touches`.
- El diseño de la máquina de estados de un incidente con ramas (no lineal),
  y cómo se validó contra la letra (o las respuestas del tutor).]

## Evaluación de la solución

[Puntos fuertes y débiles del sistema construido, con autocrítica.]

## Desarrollo del proyecto *(opcional)*

[Tiempo dedicado por tarea/módulo, desvíos respecto al cronograma inicial y
motivos -- el cambio de letra es un desvío real y vale la pena documentarlo
acá con fechas.]

## Conclusiones y trabajo a futuro

[Qué quedó pendiente, qué opcionales no se llegaron a implementar (ver la
lista en la letra: control de superposición ya resuelto, tiempo estimado de
llegada, recurso más cercano, mapa de calor), qué se recomendaría seguir.]

## Referencias

1. Taller de Sistemas de Información Geográficos Empresariales — Trabajo Obligatorio, FING UdelaR.
2. [Agregar referencias a documentación de PostGIS, GeoServer, OGC, etc.]
