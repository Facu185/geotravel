#!/bin/sh
# Configura GeoServer por su API REST: workspace, store PostGIS, capas y estilos SLD.
# Es idempotente: lo que ya existe se deja como está; los estilos se vuelven a subir siempre,
# así un cambio en geoserver/styles/*.sld se aplica con solo volver a levantar.
set -eu

G="http://geoserver:8080/geoserver/rest"
A="-u ${GEOSERVER_ADMIN_USER}:${GEOSERVER_ADMIN_PASSWORD}"
WS=geotravel
JSON="Content-Type: application/json"

existe() { [ "$(curl -s -o /dev/null -w '%{http_code}' $A "$1")" = "200" ]; }

echo "geoserver-init: esperando a GeoServer..."
n=0
until existe "$G/about/version.json"; do
  n=$((n + 1))
  [ "$n" -gt 90 ] && { echo "geoserver-init: GeoServer no respondió a tiempo"; exit 1; }
  sleep 5
done

# Copiar SLDs y SVGs desde custom_styles al directorio de estilos
echo "geoserver-init: copiando SLDs y SVGs..."
mkdir -p /opt/geoserver/data_dir/styles
cp -f /custom_styles/*.sld /opt/geoserver/data_dir/styles/
cp -f /custom_styles/*.svg /opt/geoserver/data_dir/styles/
echo "geoserver-init: SLDs y SVGs copiados"

# Las consultas de existencia piden siempre la versión .json: sin extensión, GeoServer puede
# responder 500 para un estilo que sí existe (intenta devolver el archivo SLD).
if existe "$G/workspaces/$WS.json"; then
  echo "workspace $WS: ya existe"
else
  curl -sf $A -X POST -H "$JSON" -d "{\"workspace\":{\"name\":\"$WS\"}}" "$G/workspaces" > /dev/null
  echo "workspace $WS: creado"
fi

if existe "$G/workspaces/$WS/datastores/$WS.json"; then
  echo "store $WS: ya existe"
else
  curl -sf $A -X POST -H "$JSON" "$G/workspaces/$WS/datastores" -d "{\"dataStore\":{\"name\":\"$WS\",\"connectionParameters\":{\"entry\":[
    {\"@key\":\"host\",\"\$\":\"db\"},{\"@key\":\"port\",\"\$\":\"5432\"},{\"@key\":\"database\",\"\$\":\"$POSTGRES_DB\"},
    {\"@key\":\"schema\",\"\$\":\"public\"},{\"@key\":\"user\",\"\$\":\"$POSTGRES_USER\"},{\"@key\":\"passwd\",\"\$\":\"$POSTGRES_PASSWORD\"},
    {\"@key\":\"dbtype\",\"\$\":\"postgis\"},{\"@key\":\"Expose primary keys\",\"\$\":\"true\"}]}}}" > /dev/null
  echo "store $WS: creado"
fi

for tabla in zona_operativa recurso incidente via acceso red_vial_arco lugar_osm; do
  if existe "$G/workspaces/$WS/datastores/$WS/featuretypes/$tabla.json"; then
    echo "capa $tabla: ya existe"
  else
    curl -sf $A -X POST -H "$JSON" "$G/workspaces/$WS/datastores/$WS/featuretypes?recalculate=nativebbox,latlonbbox" \
      -d "{\"featureType\":{\"name\":\"$tabla\",\"nativeName\":\"$tabla\",\"title\":\"$tabla\",\"enabled\":true}}" > /dev/null
    echo "capa $tabla: publicada"
  fi
done

# La extension de via y de red_vial_arco cambia cuando el servicio red-vial las carga (de Salto a todo el pais): se recalcula siempre.
for tabla in via red_vial_arco; do
  curl -sf $A -X PUT -H "$JSON" "$G/workspaces/$WS/datastores/$WS/featuretypes/$tabla?recalculate=nativebbox,latlonbbox" \
    -d "{\"featureType\":{\"name\":\"$tabla\"}}" > /dev/null && echo "capa $tabla: extension recalculada"
done

# estilo:capa -- cada capa usa por defecto el estilo que la colorea por su dato.
for par in incidentes_estado:incidente recursos_tipo:recurso zonas_nivel_prioridad:zona_operativa vias_tipo:via accesos_puerta:acceso red_vial:red_vial_arco lugares_referencia:lugar_osm; do
  estilo="${par%%:*}"
  capa="${par##*:}"
  existe "$G/workspaces/$WS/styles/$estilo.json" || \
    curl -sf $A -X POST -H "$JSON" -d "{\"style\":{\"name\":\"$estilo\",\"filename\":\"$estilo.sld\"}}" "$G/workspaces/$WS/styles" > /dev/null
  curl -sf $A -X PUT -H "Content-Type: application/vnd.ogc.sld+xml" --data-binary "@/opt/geoserver/data_dir/styles/$estilo.sld" "$G/workspaces/$WS/styles/$estilo" > /dev/null
  curl -sf $A -X PUT -H "$JSON" -d "{\"layer\":{\"defaultStyle\":{\"name\":\"$estilo\",\"workspace\":\"$WS\"}}}" "$G/layers/$WS:$capa" > /dev/null
  echo "estilo $estilo: aplicado a $capa"
done

# Estilo extra de la red de rutas: las calles de referencia en gris, por jerarquía, que el mapa de gestión dibuja debajo de todo
# (se pide con styles=calles_referencia; el estilo por defecto de red_vial_arco sigue siendo red_vial).
existe "$G/workspaces/$WS/styles/calles_referencia.json" ||   curl -sf $A -X POST -H "$JSON" -d "{\"style\":{\"name\":\"calles_referencia\",\"filename\":\"calles_referencia.sld\"}}" "$G/workspaces/$WS/styles" > /dev/null
curl -sf $A -X PUT -H "Content-Type: application/vnd.ogc.sld+xml" --data-binary "@/opt/geoserver/data_dir/styles/calles_referencia.sld" "$G/workspaces/$WS/styles/calles_referencia" > /dev/null
echo "estilo calles_referencia: disponible para red_vial_arco"

# Estilo extra de los incidentes: el mapa de calor (vec:Heatmap), que el mapa público pide con styles=incidentes_calor.
# La capa sigue dibujando los íconos por defecto (incidentes_estado).
existe "$G/workspaces/$WS/styles/incidentes_calor.json" ||   curl -sf $A -X POST -H "$JSON" -d "{\"style\":{\"name\":\"incidentes_calor\",\"filename\":\"incidentes_calor.sld\"}}" "$G/workspaces/$WS/styles" > /dev/null
curl -sf $A -X PUT -H "Content-Type: application/vnd.ogc.sld+xml" --data-binary "@/opt/geoserver/data_dir/styles/incidentes_calor.sld" "$G/workspaces/$WS/styles/incidentes_calor" > /dev/null
echo "estilo incidentes_calor: disponible para incidente (mapa de calor)"

# Referencia en caché: las calles y los barrios de fondo del mapa no cambian, así que el frontend los pide por GeoWebCache
# (/geoserver/gwc/service/wms) en vez de dibujarlos de nuevo en cada pedido. GeoWebCache cachea capas o grupos de capas, no
# combinaciones de capas con estilos: por eso se publican dos grupos, uno por cada fondo que usa el mapa.
#   referencia_todo     calles por jerarquía (calles_referencia) + ciudades, pueblos y barrios (lugares_referencia)
#   referencia_barrios  solo los nombres de lugares (mapa público: tiene su propio botón de Calles)
grupo() {
  nombre="$1"; capas="$2"; estilos="$3"
  existe "$G/workspaces/$WS/layergroups/$nombre.json" && { echo "grupo $nombre: ya existe"; return; }
  curl -sf $A -X POST -H "$JSON" "$G/workspaces/$WS/layergroups" -d "{\"layerGroup\":{\"name\":\"$nombre\",\"mode\":\"SINGLE\",\"title\":\"$nombre\",
    \"workspace\":{\"name\":\"$WS\"},\"publishables\":{\"published\":[$capas]},\"styles\":{\"style\":[$estilos]},
    \"bounds\":{\"minx\":-58.6,\"maxx\":-52.9,\"miny\":-35.1,\"maxy\":-30.0,\"crs\":\"EPSG:4326\"}}}" > /dev/null
  echo "grupo $nombre: creado"
}
CALLES="{\"@type\":\"layer\",\"name\":\"$WS:red_vial_arco\"}"
LUGARES="{\"@type\":\"layer\",\"name\":\"$WS:lugar_osm\"}"
grupo referencia_todo "$CALLES,$LUGARES" "{\"name\":\"$WS:calles_referencia\"},{\"name\":\"$WS:lugares_referencia\"}"
grupo referencia_barrios "$LUGARES" "{\"name\":\"$WS:lugares_referencia\"}"

# Los estilos se vuelven a subir en cada corrida: se vacía el caché de los dos grupos para que un cambio en un .sld se vea.
# Los navegadores guardan cada tesela 1 hora (expireClients); si cambió un estilo, Ctrl+F5.
W="http://geoserver:8080/geoserver/gwc/rest"
for g in referencia_todo referencia_barrios; do
  curl -sf $A "$W/layers/$WS:$g.xml" | sed 's|<expireClients>0</expireClients>|<expireClients>3600</expireClients>|' > /tmp/gwc_$g.xml
  curl -sf $A -X PUT -H "Content-Type: text/xml" --data-binary "@/tmp/gwc_$g.xml" "$W/layers/$WS:$g.xml" > /dev/null
  curl -sf $A -X POST -H "Content-Type: text/xml" -d "<truncateLayer><layerName>$WS:$g</layerName></truncateLayer>" "$W/masstruncate" > /dev/null
  echo "caché $g: configurado y vaciado"
done

echo "geoserver-init: listo"
