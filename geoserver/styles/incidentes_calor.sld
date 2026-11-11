<?xml version="1.0" encoding="UTF-8"?>
<!--
  Mapa de calor de incidentes (opcional de la letra: "Mapa de calor de concentración de incidentes").

  No es el estilo por defecto de la capa geotravel:incidente (ese dibuja los íconos): se pide con styles=incidentes_calor.
  Lo calcula GeoServer con la transformación de renderizado vec:Heatmap, sin traer los incidentes al navegador: cada punto
  suma una "campana" de radiusPixels píxeles y donde se juntan varios el valor sube. Un incidente que es una línea o un
  polígono entra por su centroide. Respeta el CQL_FILTER del pedido, así que el calor sigue los filtros de la capa Incidentes
  (tipo, estado, prioridad y fechas).

  Colores: de azul (pocos) a rojo (muchos), con el fondo transparente donde no hay incidentes cerca.
  Parámetro opcional del pedido: env=radio:60 cambia el radio (por defecto 45 píxeles).
-->
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:incidente</Name>
    <UserStyle>
      <Name>incidentes_calor</Name>
      <Title>Mapa de calor de incidentes</Title>
      <FeatureTypeStyle>
        <Transformation>
          <ogc:Function name="vec:Heatmap">
            <ogc:Function name="parameter"><ogc:Literal>data</ogc:Literal></ogc:Function>
            <ogc:Function name="parameter">
              <ogc:Literal>radiusPixels</ogc:Literal>
              <ogc:Function name="env"><ogc:Literal>radio</ogc:Literal><ogc:Literal>45</ogc:Literal></ogc:Function>
            </ogc:Function>
            <ogc:Function name="parameter"><ogc:Literal>pixelsPerCell</ogc:Literal><ogc:Literal>4</ogc:Literal></ogc:Function>
            <ogc:Function name="parameter">
              <ogc:Literal>outputBBOX</ogc:Literal>
              <ogc:Function name="env"><ogc:Literal>wms_bbox</ogc:Literal></ogc:Function>
            </ogc:Function>
            <ogc:Function name="parameter">
              <ogc:Literal>outputWidth</ogc:Literal>
              <ogc:Function name="env"><ogc:Literal>wms_width</ogc:Literal></ogc:Function>
            </ogc:Function>
            <ogc:Function name="parameter">
              <ogc:Literal>outputHeight</ogc:Literal>
              <ogc:Function name="env"><ogc:Literal>wms_height</ogc:Literal></ogc:Function>
            </ogc:Function>
          </ogc:Function>
        </Transformation>
        <Rule>
          <Name>Calor</Name>
          <Title>Concentración de incidentes</Title>
          <RasterSymbolizer>
            <Opacity>0.8</Opacity>
            <ColorMap type="ramp">
              <ColorMapEntry color="#2c7bb6" quantity="0" label="Pocos" opacity="0"/>
              <ColorMapEntry color="#2c7bb6" quantity="0.04" opacity="0.35"/>
              <ColorMapEntry color="#abd9e9" quantity="0.2" label="" opacity="0.6"/>
              <ColorMapEntry color="#ffffbf" quantity="0.4" label="" opacity="0.75"/>
              <ColorMapEntry color="#fdae61" quantity="0.65" label="" opacity="0.85"/>
              <ColorMapEntry color="#d7191c" quantity="1" label="Muchos" opacity="0.9"/>
            </ColorMap>
          </RasterSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
