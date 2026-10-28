#!/usr/bin/env python3
"""
El agrupamiento de incidentes y recursos cuando el mapa está alejado (varios objetos juntos = un círculo con la cantidad),
para los estilos SLD de GeoServer. Es la misma idea que hace el frontend con los objetos que dibuja él
(frontend/src/components/CapaAgrupada.jsx): hasta el zoom 14 se agrupa; del 15 en adelante se ven los íconos.

Cómo funciona: la transformación de renderizado `vec:PointStacker` de GeoServer divide la imagen en celdas de 64 px (un
cuarto de la tesela de 256 px: así una celda nunca queda cortada entre dos teselas) y devuelve un punto por celda con el
atributo `count`. Un incidente que es una línea o un polígono entra por su centroide, igual que en el frontend. El círculo de un grupo se
dibuja en el centro de su celda (weightClusterPosition=false): como la grilla coincide con las teselas, un círculo de hasta
40 px nunca cruza el borde entre dos teselas y no queda cortado. Un objeto solo conserva su lugar (preserveLocation).

Este módulo no se corre solo para los incidentes (lo usa generar_sld_incidentes.py). Para los recursos, cuyo estilo está
escrito a mano, sirve para reescribir el bloque entre los marcadores AGRUPAMIENTO de recursos_tipo.sld:

    python geoserver/agrupamiento_sld.py
"""
import os
import re

ESCALA_ICONOS = 20000   # con el mapa más cerca que esto (zoom 15 o más) se dibujan los íconos
ESCALA_MAXIMA = 200000  # y con el mapa más lejos que esto no se dibuja nada
CELDA = 64              # píxeles; tiene que dividir a 256
COLOR_INCIDENTES = "#13202c"
COLOR_RECURSOS = "#0f766e"
DESPLAZAMIENTO_INCIDENTES = (-9, 9)
DESPLAZAMIENTO_RECURSOS = (9, -9)

INICIO = "<!-- AGRUPAMIENTO:inicio (generado por geoserver/agrupamiento_sld.py, no editar a mano) -->"
FIN = "<!-- AGRUPAMIENTO:fin -->"


def _parametro(nombre, valor):
    return f"""<ogc:Function name="parameter"><ogc:Literal>{nombre}</ogc:Literal>{valor}</ogc:Function>"""


def _entorno(variable):
    return f"""<ogc:Function name="env"><ogc:Literal>{variable}</ogc:Literal></ogc:Function>"""


def _regla(nombre, titulo, condicion, tamano, color, etiqueta, desplazamiento):
    dx, dy = desplazamiento
    texto = ""
    if etiqueta:
        texto = f"""
          <TextSymbolizer>
            <Label><ogc:PropertyName>count</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">SansSerif</CssParameter>
              <CssParameter name="font-size">{13 if tamano < 40 else 14}</CssParameter>
              <CssParameter name="font-weight">bold</CssParameter>
            </Font>
            <LabelPlacement>
              <PointPlacement>
                <AnchorPoint><AnchorPointX>0.5</AnchorPointX><AnchorPointY>0.5</AnchorPointY></AnchorPoint>
                <Displacement><DisplacementX>{dx}</DisplacementX><DisplacementY>{-dy}</DisplacementY></Displacement>
              </PointPlacement>
            </LabelPlacement>
            <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            <VendorOption name="conflictResolution">false</VendorOption>
          </TextSymbolizer>"""
    return f"""        <Rule>
          <Name>{nombre}</Name>
          <Title>{titulo}</Title>
          <MinScaleDenominator>{ESCALA_ICONOS}</MinScaleDenominator>
          <MaxScaleDenominator>{ESCALA_MAXIMA}</MaxScaleDenominator>
          <ogc:Filter>{condicion}</ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">{color}</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">2</CssParameter>
                </Stroke>
              </Mark>
              <Size>{tamano}</Size>
              <Displacement><DisplacementX>{dx}</DisplacementX><DisplacementY>{dy}</DisplacementY></Displacement>
            </Graphic>
          </PointSymbolizer>{texto}
        </Rule>
"""


def _entre(minimo, maximo):
    partes = [f"<ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>{minimo}</ogc:Literal></ogc:PropertyIsGreaterThanOrEqualTo>"]
    if maximo is not None:
        partes.append(f"<ogc:PropertyIsLessThan><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>{maximo}</ogc:Literal></ogc:PropertyIsLessThan>")
    return "<ogc:And>" + "".join(partes) + "</ogc:And>"


def feature_type_style(color, desplazamiento):
    """El <FeatureTypeStyle> del agrupamiento: va DESPUÉS de los de los íconos para que quede encima.

    desplazamiento (dx, dy) en píxeles: un grupo de incidentes y uno de recursos de la misma celda no se tapan entre sí."""
    return f"""      <FeatureTypeStyle>
        <Transformation>
          <ogc:Function name="vec:PointStacker">
            {_parametro("data", "")}
            {_parametro("cellSize", f"<ogc:Literal>{CELDA}</ogc:Literal>")}
            {_parametro("weightClusterPosition", "<ogc:Literal>false</ogc:Literal>")}
            {_parametro("preserveLocation", "<ogc:Literal>Single</ogc:Literal>")}
            {_parametro("outputBBOX", _entorno("wms_bbox"))}
            {_parametro("outputWidth", _entorno("wms_width"))}
            {_parametro("outputHeight", _entorno("wms_height"))}
          </ogc:Function>
        </Transformation>
{_regla("agrupado_uno", "Uno solo", '<ogc:PropertyIsEqualTo><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>1</ogc:Literal></ogc:PropertyIsEqualTo>', 12, color, False, desplazamiento)}{_regla("agrupado_2_a_9", "De 2 a 9", _entre(2, 10), 28, color, True, desplazamiento)}{_regla("agrupado_10_a_99", "De 10 a 99", _entre(10, 100), 34, color, True, desplazamiento)}{_regla("agrupado_100_o_mas", "100 o más", _entre(100, None), 40, color, True, desplazamiento)}      </FeatureTypeStyle>
"""


def reescribir_en(archivo, color, desplazamiento):
    """Reemplaza, en un SLD escrito a mano, lo que hay entre los marcadores AGRUPAMIENTO (o lo agrega antes de </UserStyle>)."""
    with open(archivo, encoding="utf-8", newline="") as f:
        crudo = f.read()
    crlf = "\r\n" in crudo
    s = crudo.replace("\r\n", "\n")
    bloque = f"      {INICIO}\n{feature_type_style(color, desplazamiento)}      {FIN}\n"
    if INICIO in s:
        s = re.sub(re.escape("      " + INICIO) + r".*?" + re.escape(FIN) + r"\n", lambda _: bloque, s, count=1, flags=re.S)
    else:
        s = s.replace("    </UserStyle>", bloque + "    </UserStyle>", 1)
    with open(archivo, "w", encoding="utf-8", newline="") as f:
        f.write(s.replace("\n", "\r\n") if crlf else s)


if __name__ == "__main__":
    carpeta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "styles")
    reescribir_en(os.path.join(carpeta, "recursos_tipo.sld"), COLOR_RECURSOS, DESPLAZAMIENTO_RECURSOS)
    print("Escrito el agrupamiento en recursos_tipo.sld")
