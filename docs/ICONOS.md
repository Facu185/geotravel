# Íconos y colores de recursos e incidentes

Una sola convención para todos los mapas (administración, mapa público, consultas y GeoServer),
para que un recurso se vea igual en cualquier pantalla.

## Recursos

| | Qué dice | Valores |
|---|---|---|
| **Forma** del ícono | el **tipo** | ambulancia (cruz), bomberos (llama), patrulla (escudo con estrella), centro de atención (H), otro (punto) |
| **Color** del círculo | el **estado operativo** | Disponible `#1f7a5c` · En servicio `#9a5a12` · Fuera de servicio `#a8392b` |

Los colores están en `frontend/src/components/colores.js` (`COLOR_ESTADO_RECURSO`).

## Los dibujos

Archivos SVG blancos, sin fondo, en `frontend/public/iconos/`:

- `recurso-ambulancia.svg`, `recurso-bomberos.svg`, `recurso-patrulla.svg`,
  `recurso-centro_atencion.svg`, `recurso-otro.svg`
- `incidente-<tipo>.svg` (auto, llama, rayo, olas, paso prohibido y signo de exclamación), ver "Incidentes" más abajo

El frontend los dibuja sobre un círculo del color del estado con
`frontend/src/components/iconos.jsx`:

```jsx
import { Marker } from "react-leaflet";
import { IconoRecurso, iconoRecurso } from "../../components/iconos.jsx";

<Marker position={[lat, lng]} icon={iconoRecurso(r.tipo, r.estadoOperativo)} />   // en el mapa
<IconoRecurso tipo={r.tipo} estado={r.estadoOperativo} chico />                     // en una lista
```

## Para GeoServer (P1)

`geoserver/styles/recursos_tipo.sld` hoy dibuja cuadrados de colores por tipo. Para que coincida con
el resto: un `PointSymbolizer` con `ExternalGraphic` (el SVG del tipo) sobre un círculo con el color del
estado. GeoServer solo ve las capas WMS cuando el mapa está alejado (ver `docs/CARGA_POR_ZONA.md`),
así que si no coinciden se nota al hacer zoom.

Pasos sugeridos: subir los SVG a GeoServer (por REST, en `geoserver-init.sh`, o copiándolos al
directorio de estilos) y referenciarlos con `<OnlineResource xlink:href="recurso-ambulancia.svg"/>`.
Con un `ogc:Filter` por `tipo` y otro por `estado_operativo` se arman las combinaciones.

## Incidentes

Misma idea que los recursos: la **forma** del dibujo es el **tipo** y el **color** es el **estado**, pero sobre un
**rombo** (los recursos van sobre un círculo, así no se confunden).

| Tipo (valor guardado) | Dibujo | Archivo |
|---|---|---|
| `accidente_transito` | auto | `incidente-accidente_transito.svg` |
| `incendio` | llama | `incidente-incendio.svg` |
| `corte_servicio` | rayo | `incidente-corte_servicio.svg` |
| `inundacion` | olas | `incidente-inundacion.svg` |
| `calle_cortada` | señal de paso prohibido | `incidente-calle_cortada.svg` |
| `otro` (y cualquier tipo que no esté en la lista) | signo de exclamación | `incidente-otro.svg` |

Colores por estado (`COLOR_ESTADO_INCIDENTE`): Registrado `#2b6b9e` · En atención `#9a5a12` · Derivado `#7a3b8f` ·
Resuelto `#1f7a5c` · Cancelado `#a8392b`.

- Frontend: `iconoIncidente(tipo, estado)` para el mapa e `IconoIncidente` para listas y leyendas
  (`frontend/src/components/iconos.jsx`); los tipos y sus nombres están en `colores.js` (`TIPOS_INCIDENTE`). En el
  formulario de Incidentes el tipo se elige entre estos (cada uno con su ícono): elegir el tipo es elegir el ícono.
- Las **líneas** (calle cortada) y los **polígonos** (áreas afectadas) se dibujan con su forma y el color del estado.
- GeoServer: `geoserver/styles/incidentes_estado.sld` **se genera** con `python geoserver/generar_sld_incidentes.py`
  (hay una regla por estado, por tipo y por forma). Para agregar un tipo: sumarlo a `TIPOS` en el script y a
  `TIPOS_INCIDENTE` en `colores.js`, crear su SVG en las dos carpetas (`frontend/public/iconos/` y `geoserver/styles/`),
  generar el SLD y volver a correr `docker compose run --rm geoserver-init`.

## Agrupar con un número (mapa alejado)

Con el mapa alejado (zoom 14 o menos) los incidentes y recursos que quedan juntos se agrupan en un **círculo con la
cantidad**, como en Airbnb: oscuro para incidentes, verde azulado para recursos. Del zoom 15 en adelante se ven los íconos.
Las líneas y los polígonos de incidentes cuentan en el grupo por su centro (y su forma se dibuja igual).

- **Lo que dibuja GeoServer** (mapa público, y el fondo de las demás pantallas cuando está lejos): una transformación de
  renderizado `vec:PointStacker` agrupa en celdas de 64 px (un cuarto de la tesela de 256 px, así un círculo no cruza el
  borde entre teselas). Está en un segundo `FeatureTypeStyle` del SLD; lo genera `geoserver/agrupamiento_sld.py` (para
  incidentes lo usa `generar_sld_incidentes.py`; para recursos reescribe el bloque marcado en `recursos_tipo.sld`).
  Un objeto solo se ve como un punto neutro: GeoServer no conserva su tipo ni su estado al agrupar.
- **Lo que dibuja el navegador** (Consultas, Tiempo de llegada y los ABM de Incidentes y Recursos): `CapaAgrupada.jsx`
  (con `leaflet.markercluster`), con el mismo radio y el mismo corte de zoom, y ahí cada objeto suelto conserva su ícono.
  El que se está eligiendo nunca se agrupa. Un clic en un grupo acerca el mapa.
- Si se cambia el zoom de corte, cambiarlo en los dos lados: `ZOOM_ICONOS` en `CapaAgrupada.jsx` y `ESCALA_ICONOS` en
  `agrupamiento_sld.py` (zoom 15 ≈ escala 1:17000).

## Ojo con los SVG en GeoServer

Los SVG tienen que llevar `width="24" height="24"` además del `viewBox`. Sin eso, GeoServer dibuja corridos (o
directamente no se ven) los dibujos que no ocupan todo el cuadro, como el punto de `recurso-otro.svg` o el signo de
`incidente-otro.svg`. Además, GeoServer guarda en memoria los gráficos que ya cargó: al cambiar un SVG hay que reiniciar
el contenedor (`docker compose restart geoserver`) para verlo.
