#!/usr/bin/env python3
"""
Genera geoserver/styles/incidentes_estado.sld (el estilo de la capa geotravel:incidente).

Por qué un script: el estilo tiene una regla por estado, por tipo de incidente y por forma (punto, línea o polígono),
y escribirlas a mano da más de 30 reglas casi iguales. Con el script, agregar un tipo o cambiar un color es tocar
la tabla de abajo y volver a generar:

    python geoserver/generar_sld_incidentes.py

Convención (docs/ICONOS.md, la misma que frontend/src/components/iconos.jsx):
  - un incidente PUNTUAL se dibuja como un rombo del color de su ESTADO con el dibujo de su TIPO adentro
    (geoserver/styles/incidente-<tipo>.svg, los mismos archivos que usa el frontend). Ojo: esos SVG llevan
    width="24" height="24" a propósito: sin eso, GeoServer dibuja corridos o invisibles los dibujos que no ocupan
    todo el cuadro (el signo de "otro", por ejemplo).
  - una LÍNEA (calle cortada) y un POLÍGONO (área afectada) se dibujan con su forma y el color del estado.
Un tipo que no esté en la lista se dibuja como "otro".
"""
import os

# estado: (color del relleno, color del borde de los polígonos)
ESTADOS = {
    "Registrado": ("#2b6b9e", "#1f4d73"),
    "En atención": ("#9a5a12", "#73430d"),
    "Derivado": ("#7a3b8f", "#5c2c6b"),
    "Resuelto": ("#1f7a5c", "#15543f"),
    "Cancelado": ("#a8392b", "#7d2a20"),
}
TIPOS = ["accidente_transito", "incendio", "corte_servicio", "inundacion", "calle_cortada", "otro"]  # y "otro" también para cualquier tipo que no esté acá
ESCALA_MAXIMA = 200000
CARPETA_ESTILOS = "file:///opt/geoserver/data_dir/styles"
TAMANO_ROMBO = 21  # el cuadrado rotado 45 grados mide unos 30 px de punta a punta, como los círculos de los recursos
TAMANO_DIBUJO = 13

CABECERA = """<?xml version="1.0" encoding="UTF-8"?>
<!-- Generado por geoserver/generar_sld_incidentes.py: no editar a mano. -->
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:incidente</Name>
    <UserStyle>
      <Name>incidentes_estado</Name>
      <Title>Incidentes por estado y tipo</Title>
      <FeatureTypeStyle>
"""
PIE = """      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
"""


def igual(propiedad, valor):
    return f"""<ogc:PropertyIsEqualTo>
                <ogc:PropertyName>{propiedad}</ogc:PropertyName>
                <ogc:Literal>{valor}</ogc:Literal>
              </ogc:PropertyIsEqualTo>"""


def dimension(n):
    return f"""<ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>{n}</ogc:Literal>
              </ogc:PropertyIsEqualTo>"""


def regla(nombre, titulo, condiciones, simbolizadores):
    cond = "\n              ".join(condiciones)
    return f"""        <Rule>
          <Name>{nombre}</Name>
          <Title>{titulo}</Title>
          <MaxScaleDenominator>{ESCALA_MAXIMA}</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              {cond}
            </ogc:And>
          </ogc:Filter>
{simbolizadores}
        </Rule>
"""


def punto(color, tipo):
    return f"""          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">{color}</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>{TAMANO_ROMBO}</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="{CARPETA_ESTILOS}/incidente-{tipo}.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>{TAMANO_DIBUJO}</Size>
            </Graphic>
          </PointSymbolizer>"""


def linea(color):
    return f"""          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">{color}</CssParameter>
              <CssParameter name="stroke-width">3</CssParameter>
            </Stroke>
          </LineSymbolizer>"""


def poligono(color, borde):
    return f"""          <PolygonSymbolizer>
            <Fill>
              <CssParameter name="fill">{color}</CssParameter>
              <CssParameter name="fill-opacity">0.4</CssParameter>
            </Fill>
            <Stroke>
              <CssParameter name="stroke">{borde}</CssParameter>
              <CssParameter name="stroke-width">1.5</CssParameter>
            </Stroke>
          </PolygonSymbolizer>"""


def generar():
    reglas = []
    for estado, (color, borde) in ESTADOS.items():
        clave = estado.replace(" ", "_")
        for tipo in TIPOS:
            reglas.append(regla(f"{clave}_Point_{tipo}", f"{estado} - {tipo} (punto)",
                                [igual("estado", estado), dimension(0), igual("tipo_incidente", tipo)], punto(color, tipo)))
        # un tipo que no esté en la lista se dibuja como "otro"
        alguno = "\n                  ".join(igual("tipo_incidente", t) for t in TIPOS)
        ninguno = f"<ogc:Not>\n                <ogc:Or>\n                  {alguno}\n                </ogc:Or>\n              </ogc:Not>"
        reglas.append(regla(f"{clave}_Point_desconocido", f"{estado} - tipo desconocido (punto)", [igual("estado", estado), dimension(0), ninguno], punto(color, "otro")))
        reglas.append(regla(f"{clave}_Line", f"{estado} - Línea", [igual("estado", estado), dimension(1)], linea(color)))
        reglas.append(regla(f"{clave}_Polygon", f"{estado} - Polígono", [igual("estado", estado), dimension(2)], poligono(color, borde)))
    return CABECERA + "".join(reglas) + PIE


if __name__ == "__main__":
    destino = os.path.join(os.path.dirname(os.path.abspath(__file__)), "styles", "incidentes_estado.sld")
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        f.write(generar())
    print(f"Escrito {destino}")
