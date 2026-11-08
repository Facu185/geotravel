<?xml version="1.0" encoding="UTF-8"?>
<!--
  Calles de referencia para guiarse en el mapa de gestión (zonas, recursos, incidentes, consultas y tiempo de llegada).
  Se dibujan debajo de todo, en gris, y por jerarquía según el zoom: a lo lejos solo las rutas y avenidas principales; al
  acercarse aparecen las calles secundarias y después las de barrio y las de servicio. Los nombres, solo cerca.
  Es otro estilo de la misma capa de la Red de rutas (red_vial_arco), que usa el estilo red_vial en verde.
-->
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:red_vial_arco</Name>
    <UserStyle>
      <Name>calles_referencia</Name>
      <Title>Calles de referencia por jerarquía</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>Rutas y principales</Name>
          <Title>Autopista, ruta y avenida principal</Title>
          <MaxScaleDenominator>3000000</MaxScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>trunk</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>trunk_link</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>primary</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>primary_link</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#6f7d8a</CssParameter>
              <CssParameter name="stroke-width">1.6</CssParameter>
              <CssParameter name="stroke-linecap">round</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Secundarias</Name>
          <Title>Calle secundaria</Title>
          <MaxScaleDenominator>250000</MaxScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>secondary</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>secondary_link</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#8693a0</CssParameter>
              <CssParameter name="stroke-width">1.4</CssParameter>
              <CssParameter name="stroke-linecap">round</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Terciarias</Name>
          <Title>Calle terciaria</Title>
          <MaxScaleDenominator>120000</MaxScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>tertiary</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>tertiary_link</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#99a5b0</CssParameter>
              <CssParameter name="stroke-width">1.2</CssParameter>
              <CssParameter name="stroke-linecap">round</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Calles</Name>
          <Title>Calle de barrio</Title>
          <MaxScaleDenominator>60000</MaxScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>residential</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>unclassified</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>living_street</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#aab4be</CssParameter>
              <CssParameter name="stroke-width">1.0</CssParameter>
              <CssParameter name="stroke-linecap">round</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Servicio</Name>
          <Title>Calle de servicio</Title>
          <MaxScaleDenominator>15000</MaxScaleDenominator>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>service</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#c3cbd2</CssParameter>
              <CssParameter name="stroke-width">0.8</CssParameter>
              <CssParameter name="stroke-linecap">round</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Nombres principales</Name>
          <Title>Nombre de rutas y avenidas principales</Title>
          <MaxScaleDenominator>120000</MaxScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>trunk</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>trunk_link</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>primary</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>primary_link</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>secondary</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>secondary_link</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <TextSymbolizer>
            <Label><ogc:PropertyName>nombre</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">Arial</CssParameter>
              <CssParameter name="font-size">11</CssParameter>
              <CssParameter name="font-weight">bold</CssParameter>
            </Font>
            <LabelPlacement><LinePlacement><PerpendicularOffset>0</PerpendicularOffset></LinePlacement></LabelPlacement>
            <Halo>
              <Radius>2</Radius>
              <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            </Halo>
            <Fill><CssParameter name="fill">#3d4a57</CssParameter></Fill>
            <VendorOption name="followLine">true</VendorOption>
            <VendorOption name="maxDisplacement">80</VendorOption>
            <VendorOption name="repeat">500</VendorOption>
            <VendorOption name="group">yes</VendorOption>
            <VendorOption name="maxAngleDelta">30</VendorOption>
          </TextSymbolizer>
        </Rule>
        <Rule>
          <Name>Nombres terciarias</Name>
          <Title>Nombre de calles terciarias</Title>
          <MaxScaleDenominator>60000</MaxScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>tertiary</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>tertiary_link</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <TextSymbolizer>
            <Label><ogc:PropertyName>nombre</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">Arial</CssParameter>
              <CssParameter name="font-size">10</CssParameter>
              
            </Font>
            <LabelPlacement><LinePlacement><PerpendicularOffset>0</PerpendicularOffset></LinePlacement></LabelPlacement>
            <Halo>
              <Radius>2</Radius>
              <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            </Halo>
            <Fill><CssParameter name="fill">#3d4a57</CssParameter></Fill>
            <VendorOption name="followLine">true</VendorOption>
            <VendorOption name="maxDisplacement">80</VendorOption>
            <VendorOption name="repeat">500</VendorOption>
            <VendorOption name="group">yes</VendorOption>
            <VendorOption name="maxAngleDelta">30</VendorOption>
          </TextSymbolizer>
        </Rule>
        <Rule>
          <Name>Nombres calles</Name>
          <Title>Nombre de calles de barrio</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter><ogc:Or><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>residential</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>unclassified</ogc:Literal></ogc:PropertyIsEqualTo><ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>living_street</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Or></ogc:Filter>
          <TextSymbolizer>
            <Label><ogc:PropertyName>nombre</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">Arial</CssParameter>
              <CssParameter name="font-size">10</CssParameter>
              
            </Font>
            <LabelPlacement><LinePlacement><PerpendicularOffset>0</PerpendicularOffset></LinePlacement></LabelPlacement>
            <Halo>
              <Radius>2</Radius>
              <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            </Halo>
            <Fill><CssParameter name="fill">#3d4a57</CssParameter></Fill>
            <VendorOption name="followLine">true</VendorOption>
            <VendorOption name="maxDisplacement">80</VendorOption>
            <VendorOption name="repeat">500</VendorOption>
            <VendorOption name="group">yes</VendorOption>
            <VendorOption name="maxAngleDelta">30</VendorOption>
          </TextSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
