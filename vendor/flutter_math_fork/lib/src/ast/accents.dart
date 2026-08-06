class AccentRenderConfig {
  final String? overChar;
  final String? overImageName;
  final String? underImageName;
  // final bool alwaysShifty;
  const AccentRenderConfig({
    this.overChar,
    this.overImageName,
    this.underImageName,
    // this.alwaysShifty = false,
  });
}

const accentRenderConfigs = {
  '\u005e': AccentRenderConfig(
    // '\u0302'
    overChar: '\u005e', // \hat
    overImageName: 'widehat',
    // alwaysShifty: true,
  ),
  '\u02c7': AccentRenderConfig(
    // '\u030C'
    overChar: '\u02c7', // \check
    overImageName: 'widecheck',
    // alwaysShifty: true,
  ),
  '\u007e': AccentRenderConfig(
    // '\u0303'
    overChar: '\u007e', // \tilde
    overImageName: 'widetilde',
    underImageName: 'utilde',
    // alwaysShifty: true,
  ),
  '\u00b4': AccentRenderConfig(
    // '\u0301'
    overChar: '\u02ca', // \acute
  ),
  '\u0060': AccentRenderConfig(
    // '\u0300'
    overChar: '\u02cb', // \grave
  ),
  '\u02d9': AccentRenderConfig(
    // '\u0307'
    overChar: '\u02d9', // \dot
  ),
  '\u00a8': AccentRenderConfig(
    // '\u0308'
    overChar: '\u00a8', // \ddot
  ),
  // '\u20DB': AccentRenderConfig(
  //   isOverAccent: true,
  //   symbol: '', // \dddot
  //   svgName: '',
  // ),
  '\u00AF': AccentRenderConfig(
    // '\u0304'
    overChar: '\u02c9', // \bar
  ),
  '\u2192': AccentRenderConfig(
    // '\u20D7'
    overChar: '\u20d7', // \vec
    overImageName: 'overrightarrow',
    underImageName: 'underrightarrow',
  ),
  '\u02d8': AccentRenderConfig(
    // '\u0306'
    overChar: '\u02d8', // \breve
  ),
  '\u02da': AccentRenderConfig(
    // '\u030a'
    overChar: '\u02da', // \mathring
  ),
  '\u02dd': AccentRenderConfig(
    // '\u030b'
    overChar: '\u02dd', // \H
  ),
  '\u2190': AccentRenderConfig(
    // '\u20d6'
    overImageName: 'overleftarrow',
    underImageName: 'underleftarrow',
  ),
  '\u2194': AccentRenderConfig(
    // '\u20e1'
    overImageName: 'overleftrightarrow',
    underImageName: 'underleftrightarrow',
  ),

  '\u23de': AccentRenderConfig(
    overImageName: 'overbrace',
  ),

  '\u23df': AccentRenderConfig(
    underImageName: 'underbrace',
  ),

  ...katexCompatibleAccents,
};

const katexCompatibleAccents = {
  '\u21d2': AccentRenderConfig(
    // '\u21d2'
    overImageName: 'Overrightarrow',
  ),
  '\u23e0': AccentRenderConfig(
      // '\u0311'
      overImageName: 'overgroup',
      underImageName: 'undergroup'),
  // '\u': AccentRenderConfig(
  //   overImageName: 'overlinesegment',
  //   underImageName: 'underlinesegment',
  // ),
  '\u21bc': AccentRenderConfig(
    // '\u20d0'
    overImageName: 'overleftharpoon',
  ),
  '\u21c0': AccentRenderConfig(
    // '\u20d1'
    overImageName: 'overrightharpoon',
  ),
};
