<?xml version="1.0" encoding="UTF-8"?>
<!--
  Nombres de ciudades, pueblos y barrios (nodos place=* de OpenStreetMap, tabla lugar_osm), para guiarse a lo lejos.
  Cada tipo se ve en un rango de zoom: las ciudades y los pueblos grandes de lejos y los barrios desde el zoom 12 hasta el 14
  (1:100.000 a 1:20.000); más cerca ya no se dibujan, porque ahí toman la posta los nombres de las calles (calles_referencia).
  Las escalas son a la latitud de Uruguay: 1:3.000.000 = zoom 7, 1:250.000 = 11, 1:100.000 = 12, 1:30.000 = 14, 1:15.000 = 15.
-->
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:lugar_osm</Name>
    <UserStyle>
      <Name>lugares_referencia</Name>
      <Title>Ciudades, pueblos y barrios</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>Ciudades</Name>
          <Title>Ciudad</Title>
          <MaxScaleDenominator>3000000</MaxScaleDenominator>
          <MinScaleDenominator>30000</MinScaleDenominator>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>tipo</ogc:PropertyName><ogc:Literal>city</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <TextSymbolizer>
            <Label><ogc:Function name="strToUpperCase"><ogc:PropertyName>nombre</ogc:PropertyName></ogc:Function></Label>
            <Font>
              <CssParameter name="font-family">Arial</CssParameter>
              <CssParameter name="font-size">15</CssParameter>
              <CssParameter name="font-style">italic</CssParameter>
              <CssParameter name="font-weight">bold</CssParameter>
            </Font>
            <LabelPlacement><PointPlacement><AnchorPoint><AnchorPointX>0.5</AnchorPointX><AnchorPointY>0.5</AnchorPointY></AnchorPoint></PointPlacement></LabelPlacement>
            <Halo>
              <Radius>2</Radius>
              <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            </Halo>
            <Fill><CssParameter name="fill">#2f3b47</CssParameter></Fill>
            <VendorOption name="autoWrap">90</VendorOption>
            <VendorOption name="spaceAround">4</VendorOption>
            <VendorOption name="goodnessOfFit">0.3</VendorOption>
          </TextSymbolizer>
        </Rule>
        <Rule>
          <Name>Pueblos</Name>
          <Title>Pueblo</Title>
          <MaxScaleDenominator>1000000</MaxScaleDenominator>
          <MinScaleDenominator>20000</MinScaleDenominator>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>tipo</ogc:PropertyName><ogc:Literal>town</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <TextSymbolizer>
            <Label><ogc:PropertyName>nombre</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">Arial</CssParameter>
              <CssParameter name="font-size">13</CssParameter>
              <CssParameter name="font-style">italic</CssParameter>
              <CssParameter name="font-weight">bold</CssParameter>
            </Font>
            <LabelPlacement><PointPlacement><AnchorPoint><AnchorPointX>0.5</AnchorPointX><AnchorPointY>0.5</AnchorPointY></AnchorPoint></PointPlacement></LabelPlacement>
            <Halo>
              <Radius>2</Radius>
              <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            </Halo>
            <Fill><CssParameter name="fill">#3d4a57</CssParameter></Fill>
            <VendorOption name="autoWrap">90</VendorOption>
            <VendorOption name="spaceAround">4</VendorOption>
            <VendorOption name="goodnessOfFit">0.3</VendorOption>
          </TextSymbolizer>
        </Rule>
        <Rule>
          <Name>Villas</Name>
          <Title>Villa y caserío</Title>
          <MaxScaleDenominator>250000</MaxScaleDenominator>
          <MinScaleDenominator>15000</MinScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>tipo</ogc:PropertyName><ogc:Literal>village</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>tipo</ogc:PropertyName><ogc:Literal>hamlet</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <TextSymbolizer>
            <Label><ogc:PropertyName>nombre</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">Arial</CssParameter>
              <CssParameter name="font-size">11</CssParameter>
              <CssParameter name="font-style">italic</CssParameter>
              
            </Font>
            <LabelPlacement><PointPlacement><AnchorPoint><AnchorPointX>0.5</AnchorPointX><AnchorPointY>0.5</AnchorPointY></AnchorPoint></PointPlacement></LabelPlacement>
            <Halo>
              <Radius>2</Radius>
              <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            </Halo>
            <Fill><CssParameter name="fill">#4a5764</CssParameter></Fill>
            <VendorOption name="autoWrap">90</VendorOption>
            <VendorOption name="spaceAround">4</VendorOption>
            <VendorOption name="goodnessOfFit">0.3</VendorOption>
          </TextSymbolizer>
        </Rule>
        <Rule>
          <Name>Barrios</Name>
          <Title>Barrio</Title>
          <MaxScaleDenominator>100000</MaxScaleDenominator>
          <MinScaleDenominator>20000</MinScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>tipo</ogc:PropertyName><ogc:Literal>suburb</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>tipo</ogc:PropertyName><ogc:Literal>neighbourhood</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <TextSymbolizer>
            <Label><ogc:PropertyName>nombre</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">Arial</CssParameter>
              <CssParameter name="font-size">11</CssParameter>
              <CssParameter name="font-style">italic</CssParameter>
              
            </Font>
            <LabelPlacement><PointPlacement><AnchorPoint><AnchorPointX>0.5</AnchorPointX><AnchorPointY>0.5</AnchorPointY></AnchorPoint></PointPlacement></LabelPlacement>
            <Halo>
              <Radius>2</Radius>
              <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            </Halo>
            <Fill><CssParameter name="fill">#56636f</CssParameter></Fill>
            <VendorOption name="autoWrap">90</VendorOption>
            <VendorOption name="spaceAround">4</VendorOption>
            <VendorOption name="goodnessOfFit">0.3</VendorOption>
          </TextSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
