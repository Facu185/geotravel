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

### Implementación del backend y servicios REST (P2)

El backend de UrbanSafe está desarrollado en Java y se ejecuta sobre Apache Tomcat 9. Para publicar los servicios HTTP se utiliza Jersey 2.41, una implementación de la especificación JAX-RS. La aplicación se distribuye como un archivo WAR generado mediante Maven.

La configuración principal se encuentra en `web.xml`, donde se registra el servlet de Jersey, se establece la ruta `/api/*` y se configura el descubrimiento de recursos REST dentro del paquete `uy.edu.fing.geotravel`. Los recursos exponen operaciones para los distintos módulos del sistema, mientras que la configuración común del backend proporciona acceso a los servicios y a la base de datos.

**Conexión con la base de datos**

La comunicación con PostgreSQL/PostGIS se realiza mediante JDBC y el controlador de PostgreSQL. Para administrar las conexiones se utiliza HikariCP, configurado mediante la clase `DataSourceProvider`.

Esta clase centraliza la creación de un pool de conexiones, establece un máximo de diez conexiones y obtiene los parámetros de acceso mediante variables de entorno. De esta manera, los distintos módulos pueden reutilizar conexiones administradas sin implementar su propia configuración de acceso a la base de datos.

**Comunicación con el frontend**

La aplicación React consume los servicios REST expuestos por el backend. Para permitir las solicitudes desde el servidor de desarrollo se implementó `CorsFilter`, que incorpora las cabeceras HTTP necesarias para la comunicación entre distintos orígenes.

En el entorno de desarrollo se utiliza `Access-Control-Allow-Origin: *`. En un despliegue de producción sería conveniente restringir los orígenes autorizados según la configuración y los requisitos de seguridad del sistema.

**Pruebas y verificación**

Se incorporó una prueba automatizada con JUnit 4 para `HealthResource`, verificando que el método `health()` devuelva los valores esperados en los campos `status` y `service`. La prueba se ejecutó correctamente mediante Maven, sin fallos ni errores.

También se verificó la compilación y el empaquetado del backend mediante `mvn clean package`, obteniendo el archivo `geotravel.war`.

Como comprobación inicial de integración, se realizaron solicitudes HTTP a los endpoints de zonas operativas y recursos sobre el despliegue local anterior a la última actualización del repositorio. Ambas devolvieron código HTTP 200 y datos geográficos en formato JSON, lo que permitió comprobar el acceso a información almacenada en PostgreSQL/PostGIS. Asimismo, se verificó la presencia de las cabeceras CORS en la respuesta del endpoint de salud.

Estas comprobaciones no sustituyen una batería completa de pruebas funcionales. Queda pendiente validar el despliegue actualizado y ampliar la cobertura de las reglas de negocio y los escenarios de error.

### Backend y servicios REST (P2)

El backend de UrbanSafe fue desarrollado en Java y se ejecuta sobre Apache Tomcat 9. Para la exposición de servicios REST se utiliza Jersey 2.41, una implementación de JAX-RS. Maven se emplea para administrar las dependencias, compilar el código y generar el archivo WAR utilizado para desplegar la aplicación.

La configuración principal se encuentra en WEB-INF/web.xml, donde se registra el servlet de Jersey, se define la ruta /api/* y se configura el descubrimiento de recursos REST dentro del paquete uy.edu.fing.geotravel.

**Acceso a la base de datos**

La comunicación con PostgreSQL/PostGIS se realiza mediante JDBC y el controlador de PostgreSQL. Para gestionar las conexiones se utiliza HikariCP, centralizado en la clase DataSourceProvider.

Esta clase configura un pool de hasta diez conexiones y obtiene los parámetros de conexión mediante variables de entorno. Esto permite que los distintos módulos del backend compartan un mecanismo de acceso a la base de datos sin duplicar configuraciones.

**Comunicación con el frontend**

La aplicación React consume los servicios REST publicados por el backend, mientras que GeoServer proporciona servicios geoespaciales para visualizar las capas del mapa.

Se implementó CorsFilter para incorporar las cabeceras CORS necesarias para la comunicación entre el frontend y el backend. Durante el desarrollo se permite cualquier origen mediante Access-Control-Allow-Origin: *. Para un despliegue de producción sería conveniente restringir los orígenes autorizados.

**Pruebas y verificación**

Se incorporó una prueba unitaria automatizada utilizando JUnit 4 para HealthResource. La prueba comprueba los valores de los campos status y service devueltos por el método health().

La ejecución de Maven finalizó correctamente, con una prueba ejecutada y sin errores. También se comprobó la generación del archivo geotravel.war mediante el comando mvn clean package.

Como verificación inicial de integración, se realizaron peticiones HTTP a los endpoints de zonas operativas y recursos, obteniendo respuestas HTTP 200 con información geográfica en formato JSON. Se verificó además la presencia de las cabeceras CORS en el endpoint de salud.

Estas peticiones se realizaron sobre un despliegue local anterior a las últimas actualizaciones de main. Por tanto, queda pendiente verificar nuevamente la versión actualizada y ampliar las pruebas sobre las reglas de negocio y los escenarios de error.
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
