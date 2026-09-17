<?xml version="1.0" encoding="UTF-8"?>
<!-- Estilo para la capa 'atraccion' (PointSymbolizer), un color por clasificacion. -->
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:atraccion</Name>
    <UserStyle>
      <Name>atracciones_clasificacion</Name>
      <Title>Atracciones por clasificación</Title>
      <FeatureTypeStyle>

        <Rule>
          <Name>cultural</Name><Title>Cultural</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>clasificacion</ogc:PropertyName><ogc:Literal>cultural</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark><WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#7a3b8f</CssParameter></Fill>
              </Mark>
              <Size>10</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

        <Rule>
          <Name>gastronomica</Name><Title>Gastronómica</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>clasificacion</ogc:PropertyName><ogc:Literal>gastronomica</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark><WellKnownName>triangle</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
              </Mark>
              <Size>11</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

        <Rule>
          <Name>natural</Name><Title>Natural</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>clasificacion</ogc:PropertyName><ogc:Literal>natural</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark><WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
              </Mark>
              <Size>10</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

        <Rule>
          <Name>historica</Name><Title>Histórica</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>clasificacion</ogc:PropertyName><ogc:Literal>historica</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark><WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#2b6b9e</CssParameter></Fill>
              </Mark>
              <Size>10</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
