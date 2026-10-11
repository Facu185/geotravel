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

for tabla in zona_operativa recurso incidente via acceso; do
  if existe "$G/workspaces/$WS/datastores/$WS/featuretypes/$tabla.json"; then
    echo "capa $tabla: ya existe"
  else
    curl -sf $A -X POST -H "$JSON" "$G/workspaces/$WS/datastores/$WS/featuretypes?recalculate=nativebbox,latlonbbox" \
      -d "{\"featureType\":{\"name\":\"$tabla\",\"nativeName\":\"$tabla\",\"title\":\"$tabla\",\"enabled\":true}}" > /dev/null
    echo "capa $tabla: publicada"
  fi
done

# estilo:capa -- cada capa usa por defecto el estilo que la colorea por su dato.
for par in incidentes_estado:incidente recursos_tipo:recurso zonas_nivel_prioridad:zona_operativa vias_tipo:via accesos_puerta:acceso; do
  estilo="${par%%:*}"
  capa="${par##*:}"
  existe "$G/workspaces/$WS/styles/$estilo.json" || \
    curl -sf $A -X POST -H "$JSON" -d "{\"style\":{\"name\":\"$estilo\",\"filename\":\"$estilo.sld\"}}" "$G/workspaces/$WS/styles" > /dev/null
  curl -sf $A -X PUT -H "Content-Type: application/vnd.ogc.sld+xml" --data-binary "@/styles/$estilo.sld" "$G/workspaces/$WS/styles/$estilo" > /dev/null
  curl -sf $A -X PUT -H "$JSON" -d "{\"layer\":{\"defaultStyle\":{\"name\":\"$estilo\",\"workspace\":\"$WS\"}}}" "$G/layers/$WS:$capa" > /dev/null
  echo "estilo $estilo: aplicado a $capa"
done

echo "geoserver-init: listo"
