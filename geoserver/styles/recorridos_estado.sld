<?xml version="1.0" encoding="UTF-8"?>
<!--
  Estilo para la capa publicada sobre la vista v_recorrido_geom (db/migrations/V2__vista_recorrido_geom.sql).
  Un color por estado, siguiendo el mismo patrón usado para ft_departamentos en el Práctico 3
  (PropertyIsEqualTo por regla). Cargar en GeoServer: Estilos → Agregar nuevo → pegar este XML.
-->
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:v_recorrido_geom</Name>
    <UserStyle>
      <Name>recorridos_estado</Name>
      <Title>Recorridos por estado</Title>
      <FeatureTypeStyle>

        <Rule>
          <Name>disponible</Name>
          <Title>Disponible</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>estado</ogc:PropertyName><ogc:Literal>Disponible</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#1f7a5c</CssParameter>
              <CssParameter name="stroke-width">3</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>

        <Rule>
          <Name>pendiente</Name>
          <Title>Pendiente</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>estado</ogc:PropertyName><ogc:Literal>Pendiente</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#9a5a12</CssParameter>
              <CssParameter name="stroke-width">3</CssParameter>
              <CssParameter name="stroke-dasharray">6 3</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>

        <Rule>
          <Name>fuera_de_estacion</Name>
          <Title>Fuera de estación</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>estado</ogc:PropertyName><ogc:Literal>Fuera de estacion</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#2b6b9e</CssParameter>
              <CssParameter name="stroke-width">2</CssParameter>
              <CssParameter name="stroke-dasharray">2 4</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>

        <Rule>
          <Name>cancelado</Name>
          <Title>Cancelado</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>estado</ogc:PropertyName><ogc:Literal>Cancelado</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#b5482e</CssParameter>
              <CssParameter name="stroke-width">1.5</CssParameter>
              <CssParameter name="stroke-opacity">0.5</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>

      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
