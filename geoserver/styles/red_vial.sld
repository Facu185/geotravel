<?xml version="1.0" encoding="UTF-8"?>
<!--
  Estilo de la red vial por la que se calculan las rutas (tabla red_vial_arco, OpenStreetMap de todo Uruguay).
  Color y grosor según el tipo de vía; en las calles de MANO ÚNICA se dibujan flechas en el sentido de circulación
  (el trazado de cada arco va de source a target, que es el sentido permitido); el nombre de la calle, solo con el mapa
  muy acercado. Verde azulado, para distinguirla de la capa "Calles" (grises) que es la referencia.
-->
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:red_vial_arco</Name>
    <UserStyle>
      <Name>red_vial</Name>
      <Title>Red vial de rutas por tipo de vía y sentido</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>Rutas_y_avenidas</Name>
          <Title>Autopista, ruta y avenida principal</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:Or>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>motorway</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>motorway_link</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>trunk</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>trunk_link</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>primary</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>primary_link</ogc:Literal></ogc:PropertyIsEqualTo>
            </ogc:Or>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#0f766e</CssParameter>
              <CssParameter name="stroke-width">2.6</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Secundarias</Name>
          <Title>Calle secundaria</Title>
          <MaxScaleDenominator>100000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:Or>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>secondary</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>secondary_link</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>tertiary</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>tertiary_link</ogc:Literal></ogc:PropertyIsEqualTo>
            </ogc:Or>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#2f9a91</CssParameter>
              <CssParameter name="stroke-width">1.8</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Calles</Name>
          <Title>Calle</Title>
          <MaxScaleDenominator>60000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:Or>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>residential</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>unclassified</ogc:Literal></ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>living_street</ogc:Literal></ogc:PropertyIsEqualTo>
            </ogc:Or>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#6fbab2</CssParameter>
              <CssParameter name="stroke-width">1.2</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Servicio</Name>
          <Title>Calle de servicio</Title>
          <MaxScaleDenominator>25000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:PropertyIsEqualTo><ogc:PropertyName>highway</ogc:PropertyName><ogc:Literal>service</ogc:Literal></ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#a9d4cf</CssParameter>
              <CssParameter name="stroke-width">0.9</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Mano_unica</Name>
          <Title>Mano única (flecha en el sentido permitido)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:PropertyIsEqualTo><ogc:PropertyName>mano_unica</ogc:PropertyName><ogc:Literal>true</ogc:Literal></ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <GraphicStroke>
                <Graphic>
                  <Mark>
                    <WellKnownName>shape://oarrow</WellKnownName>
                    <Stroke>
                      <CssParameter name="stroke">#0b4f4a</CssParameter>
                      <CssParameter name="stroke-width">1.2</CssParameter>
                    </Stroke>
                  </Mark>
                  <Size>8</Size>
                </Graphic>
              </GraphicStroke>
              <CssParameter name="stroke-dasharray">8 26</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Nombres</Name>
          <Title>Nombre de la calle</Title>
          <MaxScaleDenominator>6000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:Not>
              <ogc:PropertyIsNull><ogc:PropertyName>nombre</ogc:PropertyName></ogc:PropertyIsNull>
            </ogc:Not>
          </ogc:Filter>
          <TextSymbolizer>
            <Label><ogc:PropertyName>nombre</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">SansSerif</CssParameter>
              <CssParameter name="font-size">10</CssParameter>
            </Font>
            <LabelPlacement>
              <LinePlacement>
                <PerpendicularOffset>9</PerpendicularOffset>
              </LinePlacement>
            </LabelPlacement>
            <Halo>
              <Radius>1.5</Radius>
              <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            </Halo>
            <Fill><CssParameter name="fill">#0b4f4a</CssParameter></Fill>
            <VendorOption name="followLine">true</VendorOption>
            <VendorOption name="maxDisplacement">40</VendorOption>
            <VendorOption name="repeat">200</VendorOption>
          </TextSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
