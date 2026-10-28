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
incidente; las zonas operativas pueden superponerse, por lo que un punto puede
pertenecer a más de una zona).]

## Solución planteada

[Visión general de la solución. Insertar acá el diagrama de
`docs/diagramas/arquitectura.md`.]

## Arquitectura del sistema

[Detalle de las 4 capas: datos, GeoServer, backend, frontend, y cómo se
comunican — ver `docs/diagramas/arquitectura.md`.]

## Implementación

### Zonas operativas y recursos de emergencia (P3)

Este módulo permite al administrador crear, editar y eliminar las **zonas operativas** (polígonos con un nivel de
prioridad de 1 a 5) y los **recursos de emergencia** (puntos con un tipo y un estado operativo). El servicio REST está
en `ZonaResource` y `RecursoResource` (Jersey, JDBC y PostGIS) y la interfaz en React con Leaflet.

**Sistemas de coordenadas.** La base guarda las geometrías en EPSG:32721 (UTM 21S, en metros), que cubre Salto y casi
todo el país y permite medir distancias en metros; Leaflet y GeoJSON trabajan en EPSG:4326 (grados). La conversión se hace
siempre dentro de la consulta SQL, con las capacidades de la base: al guardar,
`ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326), 32721)`; al leer, `ST_AsGeoJSON(ST_Transform(geom, 4326))`. Un
detalle que da errores sutiles es el orden de las coordenadas: GeoJSON usa `[lon, lat]` y Leaflet `[lat, lon]`, por lo que
en el módulo de recursos la conversión está aislada en dos funciones.

**Validaciones.** El backend rechaza con `400` una zona sin nombre, con prioridad fuera de 1 a 5 o con una geometría que no
sea un polígono válido (`ST_IsValid` y `GeometryType = 'POLYGON'`, lo que descarta también polígonos que se cruzan a sí
mismos y GeoJSON mal formado). Un recurso solo se acepta si su tipo está en una lista cerrada (ambulancia, bomberos,
patrulla, centro de atención u otro, normalizado a minúsculas), si su estado operativo es válido y si su ubicación es un
punto. Las zonas **pueden superponerse** (definición del tutor), por lo que un punto, un recurso o un incidente puede
pertenecer a más de una zona y las consultas por punto devuelven todas.

**Dibujo y edición en el mapa.** Las zonas se dibujan y se modifican arrastrando sus vértices (`leaflet-draw`); al guardar
se lee la forma directamente de la capa del mapa, para que valga lo que el usuario está viendo aunque no haya confirmado el
cambio en la barra de dibujo. Los recursos se ubican con un clic. Cada tipo de recurso tiene su propio ícono (la **forma** es
el tipo y el **color** es el estado operativo) y son los mismos archivos SVG que usa GeoServer, para que todos los mapas se
vean igual (ver `docs/ICONOS.md`).

**Carga a demanda.** Con miles de zonas y recursos no es viable que el navegador reciba todos los objetos. Los listados
aceptan `?bbox=oeste,sur,este,norte&limit=N` y devuelven `{items, total, truncado}`: la consulta filtra con
`geom && ST_Transform(ST_MakeEnvelope(...), 32721)`, que usa el índice espacial GiST, calcula el total real con
`COUNT(*) OVER ()` antes de aplicar el límite (500 por defecto, 2000 como máximo) y recorta el rectángulo a la extensión de
Uruguay antes de transformarlo. En el frontend, un componente compartido pide solo lo visible, espera 300 ms tras mover el
mapa, cancela el pedido anterior y reemplaza la capa en lugar de acumularla; con el mapa alejado no pide nada y deja que
GeoServer dibuje todos los objetos como imagen (WMS). Si hay más objetos que el límite, la pantalla avisa ("Mostrando 500
de 3000"). Se probó con una carga masiva de 700 zonas y 3000 recursos en Salto (`db/pruebas/carga-masiva.sql`).

**Pruebas.** Hay pruebas unitarias del rectángulo y del límite (`BboxTest`) y pruebas de integración contra PostGIS
(`ZonasRecursosIntegrationTest`, se ejecutan con `URBANSAFE_INTEGRATION_TESTS=true`): comprueban que una zona idéntica a otra
se acepta, que se rechazan los polígonos inválidos, la prioridad fuera de rango y los tipos de recurso no permitidos, y que lo
creado aparece en el listado de su rectángulo y no en uno lejano.

**Limitaciones.** Al eliminar un recurso se quita de las asignaciones de incidentes (borrado en cascada); la pantalla avisa
cuántas son antes de confirmar, pero no se conserva ese historial. Las listas no se pueden filtrar por tipo, estado o
prioridad, y los polígonos no se simplifican según el zoom.

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
- Zonas operativas: primero se implementó la regla "no deben superponerse" (con
  `ST_Intersects AND NOT ST_Touches`, porque `ST_Overlaps` no detecta una zona
  idéntica ni una contenida en otra). Después el tutor definió que las zonas SÍ
  pueden superponerse y se retiró la validación. Consecuencia: una consulta como
  "zona de un punto" ya no devuelve una sola zona sino todas las que lo contienen.
- El diseño de la máquina de estados de un incidente con ramas (no lineal),
  y cómo se validó contra la letra (o las respuestas del tutor).
- **Escala:** al principio las pantallas cargaban todos los objetos por REST y los dibujaba el navegador; con miles
  de objetos no escala. Se pasó a **carga a demanda**: el navegador pide solo los de la parte visible
  (`?bbox=&limit=`, índice GiST) y, con el mapa alejado, los dibuja GeoServer como imagen (WMS). Ver
  `docs/CARGA_POR_ZONA.md`.
- **Líneas y polígonos como ubicación de un incidente:** la columna pasó a `Geometry` (migración V4), las consultas
  usan `ST_Intersects` en vez de `ST_Contains` (una calle cortada que cruza el borde de una zona no está completamente
  adentro), y el backend valida la forma (`ST_IsValid`).
- **Direcciones:** los datos de calles del curso no traen numeración. Se usaron números de puerta propios (tabla
  `acceso`) con tolerancia a errores de tipeo (`pg_trgm`), y la IDE de Uruguay como respaldo para esquinas y otros
  departamentos. Las calles (OpenStreetMap) y las puertas son de fuentes distintas y sus nombres no coinciden del todo.
- **Una migración ya aplicada se editó** (V2/V3 al pasar los datos a Salto) y Flyway dejó de arrancar con
  "checksum mismatch": desde entonces, los cambios de esquema van en una migración nueva.
- **Una librería rehacía la barra de dibujo en cada render** (`react-leaflet-draw`) y cancelaba el trazo en curso:
  se resolvió con un componente propio (`EditorGeometria`) que mantiene estables las opciones.]

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
