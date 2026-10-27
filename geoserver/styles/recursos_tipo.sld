<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>geotravel:recurso</Name>
    <UserStyle>
      <Name>recursos_tipo</Name>
      <Title>Recursos por tipo y estado operativo</Title>
      <FeatureTypeStyle>
        <!-- Ambulancia - Disponible -->
        <Rule>
          <Name>ambulancia_disponible</Name>
          <Title>Ambulancia - Disponible</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>ambulancia</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Disponible</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-ambulancia.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Ambulancia - En servicio -->
        <Rule>
          <Name>ambulancia_en_servicio</Name>
          <Title>Ambulancia - En servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>ambulancia</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>En servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-ambulancia.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Ambulancia - Fuera de servicio -->
        <Rule>
          <Name>ambulancia_fuera_servicio</Name>
          <Title>Ambulancia - Fuera de servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>ambulancia</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Fuera de servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-ambulancia.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Bomberos - Disponible -->
        <Rule>
          <Name>bomberos_disponible</Name>
          <Title>Bomberos - Disponible</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>bomberos</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Disponible</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-bomberos.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Bomberos - En servicio -->
        <Rule>
          <Name>bomberos_en_servicio</Name>
          <Title>Bomberos - En servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>bomberos</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>En servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-bomberos.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Bomberos - Fuera de servicio -->
        <Rule>
          <Name>bomberos_fuera_servicio</Name>
          <Title>Bomberos - Fuera de servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>bomberos</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Fuera de servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-bomberos.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Patrulla - Disponible -->
        <Rule>
          <Name>patrulla_disponible</Name>
          <Title>Patrulla - Disponible</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>patrulla</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Disponible</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-patrulla.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Patrulla - En servicio -->
        <Rule>
          <Name>patrulla_en_servicio</Name>
          <Title>Patrulla - En servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>patrulla</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>En servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-patrulla.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Patrulla - Fuera de servicio -->
        <Rule>
          <Name>patrulla_fuera_servicio</Name>
          <Title>Patrulla - Fuera de servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>patrulla</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Fuera de servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-patrulla.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Centro de atención - Disponible -->
        <Rule>
          <Name>centro_atencion_disponible</Name>
          <Title>Centro de atención - Disponible</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>centro_atencion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Disponible</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-centro_atencion.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Centro de atención - En servicio -->
        <Rule>
          <Name>centro_atencion_en_servicio</Name>
          <Title>Centro de atención - En servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>centro_atencion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>En servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-centro_atencion.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Centro de atención - Fuera de servicio -->
        <Rule>
          <Name>centro_atencion_fuera_servicio</Name>
          <Title>Centro de atención - Fuera de servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>centro_atencion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Fuera de servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-centro_atencion.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Otro - Disponible -->
        <Rule>
          <Name>otro_disponible</Name>
          <Title>Otro - Disponible</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Disponible</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Otro - En servicio -->
        <Rule>
          <Name>otro_en_servicio</Name>
          <Title>Otro - En servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>En servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <!-- Otro - Fuera de servicio -->
        <Rule>
          <Name>otro_fuera_servicio</Name>
          <Title>Otro - Fuera de servicio</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado_operativo</ogc:PropertyName>
                <ogc:Literal>Fuera de servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
              </Mark>
              <Size>30</Size>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/recurso-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>14</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
