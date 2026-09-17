<?xml version="1.0" encoding="UTF-8"?>
<!-- Estilo para la capa 'zona_turistica' (PolygonSymbolizer), rampa por nivel_atractivo (1 = mayor atractivo). -->
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:zona_turistica</Name>
    <UserStyle>
      <Name>zonas_atractivo</Name>
      <Title>Zonas por nivel de atractivo</Title>
      <FeatureTypeStyle>

        <Rule>
          <Name>nivel1</Name><Title>1 - Máximo atractivo</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>nivel_atractivo</ogc:PropertyName><ogc:Literal>1</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#c0392b</CssParameter><CssParameter name="fill-opacity">0.45</CssParameter></Fill>
            <Stroke><CssParameter name="stroke">#7b241c</CssParameter><CssParameter name="stroke-width">1</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>

        <Rule>
          <Name>nivel2</Name><Title>2</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>nivel_atractivo</ogc:PropertyName><ogc:Literal>2</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#d9754f</CssParameter><CssParameter name="fill-opacity">0.4</CssParameter></Fill>
            <Stroke><CssParameter name="stroke">#7b241c</CssParameter><CssParameter name="stroke-width">1</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>

        <Rule>
          <Name>nivel3</Name><Title>3</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>nivel_atractivo</ogc:PropertyName><ogc:Literal>3</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#e6a95f</CssParameter><CssParameter name="fill-opacity">0.35</CssParameter></Fill>
            <Stroke><CssParameter name="stroke">#8a5a2b</CssParameter><CssParameter name="stroke-width">0.8</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>

        <Rule>
          <Name>nivel4</Name><Title>4</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>nivel_atractivo</ogc:PropertyName><ogc:Literal>4</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#dce3d5</CssParameter><CssParameter name="fill-opacity">0.35</CssParameter></Fill>
            <Stroke><CssParameter name="stroke">#5b6b52</CssParameter><CssParameter name="stroke-width">0.6</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>

        <Rule>
          <Name>nivel5</Name><Title>5 - Mínimo atractivo</Title>
          <ogc:Filter><ogc:PropertyIsEqualTo>
            <ogc:PropertyName>nivel_atractivo</ogc:PropertyName><ogc:Literal>5</ogc:Literal>
          </ogc:PropertyIsEqualTo></ogc:Filter>
          <PolygonSymbolizer>
            <Fill><CssParameter name="fill">#eef1ef</CssParameter><CssParameter name="fill-opacity">0.3</CssParameter></Fill>
            <Stroke><CssParameter name="stroke">#5b6b52</CssParameter><CssParameter name="stroke-width">0.5</CssParameter></Stroke>
          </PolygonSymbolizer>
        </Rule>

        <Rule>
          <Name>etiqueta</Name>
          <TextSymbolizer>
            <Label><ogc:PropertyName>nombre</ogc:PropertyName></Label>
            <Font><CssParameter name="font-family">Sans</CssParameter><CssParameter name="font-size">11</CssParameter></Font>
            <Halo><Radius>1.5</Radius><Fill><CssParameter name="fill">#ffffff</CssParameter></Fill></Halo>
            <Fill><CssParameter name="fill">#2b2b2b</CssParameter></Fill>
          </TextSymbolizer>
        </Rule>

      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
