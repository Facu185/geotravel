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
- `incidente.svg` (triángulo de advertencia), para quien lo quiera usar en los incidentes

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

Un incidente **puntual** se dibuja con `incidente.svg` (el triángulo de advertencia) sobre un círculo del **color
del estado** (`COLOR_ESTADO_INCIDENTE`): `iconoIncidente(estado)` para el mapa e `IconoIncidente` para listas, en
`frontend/src/components/iconos.jsx`. Lo usan la pantalla Incidentes y las Consultas. Los incidentes de **línea**
(calle cortada) y **polígono** (área afectada) se siguen dibujando con su forma y el color del estado.

Pendiente en GeoServer (P1): que `incidentes_estado.sld` dibuje los puntos con este mismo ícono (un
`PointSymbolizer` con `ExternalGraphic` sobre un círculo del color del estado), y que la leyenda del mapa público
(`modules/invitado/capas.js`) se actualice cuando el SLD cambie. Si se quiere un ícono por tipo de incidente,
agregar los SVG a la misma carpeta con el nombre `incidente-<tipo>.svg`.
