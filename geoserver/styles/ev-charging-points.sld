<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0"
    xmlns="http://www.opengis.net/sld"
    xmlns:ogc="http://www.opengis.net/ogc"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.opengis.net/sld
      http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>ev:ladepunkte</Name>
    <UserStyle>
      <Name>ev-charging-points</Name>
      <Title>EV Charging Points</Title>
      <Abstract>Scale-dependent circular markers: blue AC (smaller), orange DC (larger).</Abstract>
      <FeatureTypeStyle>

        <!-- ============================ AC (blue) ============================ -->
        <Rule>
          <Name>AC Regional</Name>
          <Title>AC - regional</Title>
          <ogc:Filter>
            <ogc:PropertyIsEqualTo>
              <ogc:PropertyName>anschlussart</ogc:PropertyName>
              <ogc:Literal>AC</ogc:Literal>
            </ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <MinScaleDenominator>500000</MinScaleDenominator>
          <MaxScaleDenominator>5000000</MaxScaleDenominator>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill>
                  <CssParameter name="fill">#2F80ED</CssParameter>
                  <CssParameter name="fill-opacity">0.82</CssParameter>
                </Fill>
                <Stroke>
                  <CssParameter name="stroke">#111827</CssParameter>
                  <CssParameter name="stroke-opacity">0.90</CssParameter>
                  <CssParameter name="stroke-width">0.8</CssParameter>
                </Stroke>
              </Mark>
              <Size>3.5</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

        <Rule>
          <Name>AC City</Name>
          <Title>AC - city</Title>
          <ogc:Filter>
            <ogc:PropertyIsEqualTo>
              <ogc:PropertyName>anschlussart</ogc:PropertyName>
              <ogc:Literal>AC</ogc:Literal>
            </ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <MinScaleDenominator>100000</MinScaleDenominator>
          <MaxScaleDenominator>500000</MaxScaleDenominator>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill>
                  <CssParameter name="fill">#2F80ED</CssParameter>
                  <CssParameter name="fill-opacity">0.82</CssParameter>
                </Fill>
                <Stroke>
                  <CssParameter name="stroke">#111827</CssParameter>
                  <CssParameter name="stroke-opacity">0.90</CssParameter>
                  <CssParameter name="stroke-width">0.9</CssParameter>
                </Stroke>
              </Mark>
              <Size>5.5</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

        <Rule>
          <Name>AC Local</Name>
          <Title>AC - local</Title>
          <ogc:Filter>
            <ogc:PropertyIsEqualTo>
              <ogc:PropertyName>anschlussart</ogc:PropertyName>
              <ogc:Literal>AC</ogc:Literal>
            </ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <MaxScaleDenominator>100000</MaxScaleDenominator>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill>
                  <CssParameter name="fill">#2F80ED</CssParameter>
                  <CssParameter name="fill-opacity">0.82</CssParameter>
                </Fill>
                <Stroke>
                  <CssParameter name="stroke">#111827</CssParameter>
                  <CssParameter name="stroke-opacity">0.90</CssParameter>
                  <CssParameter name="stroke-width">1.0</CssParameter>
                </Stroke>
              </Mark>
              <Size>7.5</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

        <!-- ============================ DC (orange) ============================ -->
        <Rule>
          <Name>DC Regional</Name>
          <Title>DC - regional</Title>
          <ogc:Filter>
            <ogc:PropertyIsEqualTo>
              <ogc:PropertyName>anschlussart</ogc:PropertyName>
              <ogc:Literal>DC</ogc:Literal>
            </ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <MinScaleDenominator>500000</MinScaleDenominator>
          <MaxScaleDenominator>5000000</MaxScaleDenominator>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill>
                  <CssParameter name="fill">#F97316</CssParameter>
                  <CssParameter name="fill-opacity">0.86</CssParameter>
                </Fill>
                <Stroke>
                  <CssParameter name="stroke">#111827</CssParameter>
                  <CssParameter name="stroke-opacity">0.95</CssParameter>
                  <CssParameter name="stroke-width">0.9</CssParameter>
                </Stroke>
              </Mark>
              <Size>5</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

        <Rule>
          <Name>DC City</Name>
          <Title>DC - city</Title>
          <ogc:Filter>
            <ogc:PropertyIsEqualTo>
              <ogc:PropertyName>anschlussart</ogc:PropertyName>
              <ogc:Literal>DC</ogc:Literal>
            </ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <MinScaleDenominator>100000</MinScaleDenominator>
          <MaxScaleDenominator>500000</MaxScaleDenominator>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill>
                  <CssParameter name="fill">#F97316</CssParameter>
                  <CssParameter name="fill-opacity">0.86</CssParameter>
                </Fill>
                <Stroke>
                  <CssParameter name="stroke">#111827</CssParameter>
                  <CssParameter name="stroke-opacity">0.95</CssParameter>
                  <CssParameter name="stroke-width">1.0</CssParameter>
                </Stroke>
              </Mark>
              <Size>7.5</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

        <Rule>
          <Name>DC Local</Name>
          <Title>DC - local</Title>
          <ogc:Filter>
            <ogc:PropertyIsEqualTo>
              <ogc:PropertyName>anschlussart</ogc:PropertyName>
              <ogc:Literal>DC</ogc:Literal>
            </ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <MaxScaleDenominator>100000</MaxScaleDenominator>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill>
                  <CssParameter name="fill">#F97316</CssParameter>
                  <CssParameter name="fill-opacity">0.86</CssParameter>
                </Fill>
                <Stroke>
                  <CssParameter name="stroke">#111827</CssParameter>
                  <CssParameter name="stroke-opacity">0.95</CssParameter>
                  <CssParameter name="stroke-width">1.1</CssParameter>
                </Stroke>
              </Mark>
              <Size>10</Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>

      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
