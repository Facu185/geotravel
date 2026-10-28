<?xml version="1.0" encoding="UTF-8"?>
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
        <Rule>
          <Name>Registrado_Point_accidente_transito</Name>
          <Title>Registrado - accidente_transito (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#2b6b9e</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-accidente_transito.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Registrado_Point_incendio</Name>
          <Title>Registrado - incendio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#2b6b9e</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-incendio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Registrado_Point_corte_servicio</Name>
          <Title>Registrado - corte_servicio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#2b6b9e</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-corte_servicio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Registrado_Point_inundacion</Name>
          <Title>Registrado - inundacion (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#2b6b9e</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-inundacion.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Registrado_Point_calle_cortada</Name>
          <Title>Registrado - calle_cortada (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#2b6b9e</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-calle_cortada.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Registrado_Point_otro</Name>
          <Title>Registrado - otro (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#2b6b9e</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Registrado_Point_desconocido</Name>
          <Title>Registrado - tipo desconocido (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:Not>
                <ogc:Or>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                </ogc:Or>
              </ogc:Not>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#2b6b9e</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Registrado_Line</Name>
          <Title>Registrado - Línea</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#2b6b9e</CssParameter>
              <CssParameter name="stroke-width">3</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Registrado_Polygon</Name>
          <Title>Registrado - Polígono</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Registrado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PolygonSymbolizer>
            <Fill>
              <CssParameter name="fill">#2b6b9e</CssParameter>
              <CssParameter name="fill-opacity">0.4</CssParameter>
            </Fill>
            <Stroke>
              <CssParameter name="stroke">#1f4d73</CssParameter>
              <CssParameter name="stroke-width">1.5</CssParameter>
            </Stroke>
          </PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Point_accidente_transito</Name>
          <Title>En atención - accidente_transito (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-accidente_transito.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Point_incendio</Name>
          <Title>En atención - incendio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-incendio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Point_corte_servicio</Name>
          <Title>En atención - corte_servicio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-corte_servicio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Point_inundacion</Name>
          <Title>En atención - inundacion (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-inundacion.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Point_calle_cortada</Name>
          <Title>En atención - calle_cortada (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-calle_cortada.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Point_otro</Name>
          <Title>En atención - otro (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Point_desconocido</Name>
          <Title>En atención - tipo desconocido (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:Not>
                <ogc:Or>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                </ogc:Or>
              </ogc:Not>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#9a5a12</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Line</Name>
          <Title>En atención - Línea</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#9a5a12</CssParameter>
              <CssParameter name="stroke-width">3</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>En_atención_Polygon</Name>
          <Title>En atención - Polígono</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>En atención</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PolygonSymbolizer>
            <Fill>
              <CssParameter name="fill">#9a5a12</CssParameter>
              <CssParameter name="fill-opacity">0.4</CssParameter>
            </Fill>
            <Stroke>
              <CssParameter name="stroke">#73430d</CssParameter>
              <CssParameter name="stroke-width">1.5</CssParameter>
            </Stroke>
          </PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Point_accidente_transito</Name>
          <Title>Derivado - accidente_transito (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#7a3b8f</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-accidente_transito.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Point_incendio</Name>
          <Title>Derivado - incendio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#7a3b8f</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-incendio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Point_corte_servicio</Name>
          <Title>Derivado - corte_servicio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#7a3b8f</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-corte_servicio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Point_inundacion</Name>
          <Title>Derivado - inundacion (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#7a3b8f</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-inundacion.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Point_calle_cortada</Name>
          <Title>Derivado - calle_cortada (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#7a3b8f</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-calle_cortada.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Point_otro</Name>
          <Title>Derivado - otro (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#7a3b8f</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Point_desconocido</Name>
          <Title>Derivado - tipo desconocido (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:Not>
                <ogc:Or>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                </ogc:Or>
              </ogc:Not>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#7a3b8f</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Line</Name>
          <Title>Derivado - Línea</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#7a3b8f</CssParameter>
              <CssParameter name="stroke-width">3</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Derivado_Polygon</Name>
          <Title>Derivado - Polígono</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Derivado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PolygonSymbolizer>
            <Fill>
              <CssParameter name="fill">#7a3b8f</CssParameter>
              <CssParameter name="fill-opacity">0.4</CssParameter>
            </Fill>
            <Stroke>
              <CssParameter name="stroke">#5c2c6b</CssParameter>
              <CssParameter name="stroke-width">1.5</CssParameter>
            </Stroke>
          </PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Point_accidente_transito</Name>
          <Title>Resuelto - accidente_transito (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-accidente_transito.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Point_incendio</Name>
          <Title>Resuelto - incendio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-incendio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Point_corte_servicio</Name>
          <Title>Resuelto - corte_servicio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-corte_servicio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Point_inundacion</Name>
          <Title>Resuelto - inundacion (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-inundacion.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Point_calle_cortada</Name>
          <Title>Resuelto - calle_cortada (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-calle_cortada.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Point_otro</Name>
          <Title>Resuelto - otro (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Point_desconocido</Name>
          <Title>Resuelto - tipo desconocido (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:Not>
                <ogc:Or>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                </ogc:Or>
              </ogc:Not>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#1f7a5c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Line</Name>
          <Title>Resuelto - Línea</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#1f7a5c</CssParameter>
              <CssParameter name="stroke-width">3</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Resuelto_Polygon</Name>
          <Title>Resuelto - Polígono</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Resuelto</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PolygonSymbolizer>
            <Fill>
              <CssParameter name="fill">#1f7a5c</CssParameter>
              <CssParameter name="fill-opacity">0.4</CssParameter>
            </Fill>
            <Stroke>
              <CssParameter name="stroke">#15543f</CssParameter>
              <CssParameter name="stroke-width">1.5</CssParameter>
            </Stroke>
          </PolygonSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Point_accidente_transito</Name>
          <Title>Cancelado - accidente_transito (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-accidente_transito.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Point_incendio</Name>
          <Title>Cancelado - incendio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-incendio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Point_corte_servicio</Name>
          <Title>Cancelado - corte_servicio (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-corte_servicio.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Point_inundacion</Name>
          <Title>Cancelado - inundacion (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-inundacion.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Point_calle_cortada</Name>
          <Title>Cancelado - calle_cortada (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-calle_cortada.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Point_otro</Name>
          <Title>Cancelado - otro (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Point_desconocido</Name>
          <Title>Cancelado - tipo desconocido (punto)</Title>
          <MaxScaleDenominator>20000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:Not>
                <ogc:Or>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>accidente_transito</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>incendio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>corte_servicio</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>inundacion</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>calle_cortada</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                  <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>tipo_incidente</ogc:PropertyName>
                <ogc:Literal>otro</ogc:Literal>
              </ogc:PropertyIsEqualTo>
                </ogc:Or>
              </ogc:Not>
            </ogc:And>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>square</WellKnownName>
                <Fill><CssParameter name="fill">#a8392b</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">1.5</CssParameter>
                </Stroke>
              </Mark>
              <Size>21</Size>
              <Rotation>45</Rotation>
            </Graphic>
          </PointSymbolizer>
          <PointSymbolizer>
            <Graphic>
              <ExternalGraphic>
                <OnlineResource xlink:href="file:///opt/geoserver/data_dir/styles/incidente-otro.svg" xlink:type="simple"/>
                <Format>image/svg+xml</Format>
              </ExternalGraphic>
              <Size>13</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Line</Name>
          <Title>Cancelado - Línea</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <LineSymbolizer>
            <Stroke>
              <CssParameter name="stroke">#a8392b</CssParameter>
              <CssParameter name="stroke-width">3</CssParameter>
            </Stroke>
          </LineSymbolizer>
        </Rule>
        <Rule>
          <Name>Cancelado_Polygon</Name>
          <Title>Cancelado - Polígono</Title>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>estado</ogc:PropertyName>
                <ogc:Literal>Cancelado</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:Function name="dimension">
                  <ogc:PropertyName>geom</ogc:PropertyName>
                </ogc:Function>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <PolygonSymbolizer>
            <Fill>
              <CssParameter name="fill">#a8392b</CssParameter>
              <CssParameter name="fill-opacity">0.4</CssParameter>
            </Fill>
            <Stroke>
              <CssParameter name="stroke">#7d2a20</CssParameter>
              <CssParameter name="stroke-width">1.5</CssParameter>
            </Stroke>
          </PolygonSymbolizer>
        </Rule>
      </FeatureTypeStyle>
      <FeatureTypeStyle>
        <Transformation>
          <ogc:Function name="vec:PointStacker">
            <ogc:Function name="parameter"><ogc:Literal>data</ogc:Literal></ogc:Function>
            <ogc:Function name="parameter"><ogc:Literal>cellSize</ogc:Literal><ogc:Literal>64</ogc:Literal></ogc:Function>
            <ogc:Function name="parameter"><ogc:Literal>weightClusterPosition</ogc:Literal><ogc:Literal>false</ogc:Literal></ogc:Function>
            <ogc:Function name="parameter"><ogc:Literal>preserveLocation</ogc:Literal><ogc:Literal>Single</ogc:Literal></ogc:Function>
            <ogc:Function name="parameter"><ogc:Literal>outputBBOX</ogc:Literal><ogc:Function name="env"><ogc:Literal>wms_bbox</ogc:Literal></ogc:Function></ogc:Function>
            <ogc:Function name="parameter"><ogc:Literal>outputWidth</ogc:Literal><ogc:Function name="env"><ogc:Literal>wms_width</ogc:Literal></ogc:Function></ogc:Function>
            <ogc:Function name="parameter"><ogc:Literal>outputHeight</ogc:Literal><ogc:Function name="env"><ogc:Literal>wms_height</ogc:Literal></ogc:Function></ogc:Function>
          </ogc:Function>
        </Transformation>
        <Rule>
          <Name>agrupado_uno</Name>
          <Title>Uno solo</Title>
          <MinScaleDenominator>20000</MinScaleDenominator>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>1</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#13202c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">2</CssParameter>
                </Stroke>
              </Mark>
              <Size>12</Size>
              <Displacement><DisplacementX>-9</DisplacementX><DisplacementY>9</DisplacementY></Displacement>
            </Graphic>
          </PointSymbolizer>
        </Rule>
        <Rule>
          <Name>agrupado_2_a_9</Name>
          <Title>De 2 a 9</Title>
          <MinScaleDenominator>20000</MinScaleDenominator>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter><ogc:And><ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>2</ogc:Literal></ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyIsLessThan><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>10</ogc:Literal></ogc:PropertyIsLessThan></ogc:And></ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#13202c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">2</CssParameter>
                </Stroke>
              </Mark>
              <Size>28</Size>
              <Displacement><DisplacementX>-9</DisplacementX><DisplacementY>9</DisplacementY></Displacement>
            </Graphic>
          </PointSymbolizer>
          <TextSymbolizer>
            <Label><ogc:PropertyName>count</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">SansSerif</CssParameter>
              <CssParameter name="font-size">13</CssParameter>
              <CssParameter name="font-weight">bold</CssParameter>
            </Font>
            <LabelPlacement>
              <PointPlacement>
                <AnchorPoint><AnchorPointX>0.5</AnchorPointX><AnchorPointY>0.5</AnchorPointY></AnchorPoint>
                <Displacement><DisplacementX>-9</DisplacementX><DisplacementY>-9</DisplacementY></Displacement>
              </PointPlacement>
            </LabelPlacement>
            <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            <VendorOption name="conflictResolution">false</VendorOption>
          </TextSymbolizer>
        </Rule>
        <Rule>
          <Name>agrupado_10_a_99</Name>
          <Title>De 10 a 99</Title>
          <MinScaleDenominator>20000</MinScaleDenominator>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter><ogc:And><ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>10</ogc:Literal></ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyIsLessThan><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>100</ogc:Literal></ogc:PropertyIsLessThan></ogc:And></ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#13202c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">2</CssParameter>
                </Stroke>
              </Mark>
              <Size>34</Size>
              <Displacement><DisplacementX>-9</DisplacementX><DisplacementY>9</DisplacementY></Displacement>
            </Graphic>
          </PointSymbolizer>
          <TextSymbolizer>
            <Label><ogc:PropertyName>count</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">SansSerif</CssParameter>
              <CssParameter name="font-size">13</CssParameter>
              <CssParameter name="font-weight">bold</CssParameter>
            </Font>
            <LabelPlacement>
              <PointPlacement>
                <AnchorPoint><AnchorPointX>0.5</AnchorPointX><AnchorPointY>0.5</AnchorPointY></AnchorPoint>
                <Displacement><DisplacementX>-9</DisplacementX><DisplacementY>-9</DisplacementY></Displacement>
              </PointPlacement>
            </LabelPlacement>
            <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            <VendorOption name="conflictResolution">false</VendorOption>
          </TextSymbolizer>
        </Rule>
        <Rule>
          <Name>agrupado_100_o_mas</Name>
          <Title>100 o más</Title>
          <MinScaleDenominator>20000</MinScaleDenominator>
          <MaxScaleDenominator>200000</MaxScaleDenominator>
          <ogc:Filter><ogc:And><ogc:PropertyIsGreaterThanOrEqualTo><ogc:PropertyName>count</ogc:PropertyName><ogc:Literal>100</ogc:Literal></ogc:PropertyIsGreaterThanOrEqualTo></ogc:And></ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill><CssParameter name="fill">#13202c</CssParameter></Fill>
                <Stroke>
                  <CssParameter name="stroke">#ffffff</CssParameter>
                  <CssParameter name="stroke-width">2</CssParameter>
                </Stroke>
              </Mark>
              <Size>40</Size>
              <Displacement><DisplacementX>-9</DisplacementX><DisplacementY>9</DisplacementY></Displacement>
            </Graphic>
          </PointSymbolizer>
          <TextSymbolizer>
            <Label><ogc:PropertyName>count</ogc:PropertyName></Label>
            <Font>
              <CssParameter name="font-family">SansSerif</CssParameter>
              <CssParameter name="font-size">14</CssParameter>
              <CssParameter name="font-weight">bold</CssParameter>
            </Font>
            <LabelPlacement>
              <PointPlacement>
                <AnchorPoint><AnchorPointX>0.5</AnchorPointX><AnchorPointY>0.5</AnchorPointY></AnchorPoint>
                <Displacement><DisplacementX>-9</DisplacementX><DisplacementY>-9</DisplacementY></Displacement>
              </PointPlacement>
            </LabelPlacement>
            <Fill><CssParameter name="fill">#ffffff</CssParameter></Fill>
            <VendorOption name="conflictResolution">false</VendorOption>
          </TextSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
