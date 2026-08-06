part of katex_ext;

const _notEntries = {
  ['\\not']: FunctionSpec(numArgs: 1, handler: _notHandler)
};

const _notRemap = {
  '\u2190': '\u219A',
  '\u2192': '\u219B',
  '\u2194': '\u21AE',
  '\u21D0': '\u21CD',
  '\u21D2': '\u21CF',
  '\u21D4': '\u21CE',
  '\u2208': '\u2209',
  '\u220B': '\u220C',
  '\u2223': '\u2224',
  '\u2225': '\u2226',
  '\u223C': '\u2241',
  '\u007E': '\u2241',
  '\u2243': '\u2244',
  '\u2245': '\u2247',
  '\u2248': '\u2249',
  '\u224D': '\u226D',
  '\u003D': '\u2260',
  '\u2261': '\u2262',
  '\u003C': '\u226E',
  '\u003E': '\u226F',
  '\u2264': '\u2270',
  '\u2265': '\u2271',
  '\u2272': '\u2274',
  '\u2273': '\u2275',
  '\u2276': '\u2278',
  '\u2277': '\u2279',
  '\u227A': '\u2280',
  '\u227B': '\u2281',
  '\u2282': '\u2284',
  '\u2283': '\u2285',
  '\u2286': '\u2288',
  '\u2287': '\u2289',
  '\u22A2': '\u22AC',
  '\u22A8': '\u22AD',
  '\u22A9': '\u22AE',
  '\u22AB': '\u22AF',
  '\u227C': '\u22E0',
  '\u227D': '\u22E1',
  '\u2291': '\u22E2',
  '\u2292': '\u22E3',
  '\u22B2': '\u22EA',
  '\u22B3': '\u22EB',
  '\u22B4': '\u22EC',
  '\u22B5': '\u22ED',
  '\u2203': '\u2204'
};
GreenNode _notHandler(TexParser parser, FunctionContext context) {
  final base = parser.parseArgNode(mode: null, optional: false)!;
  final node = assertNodeType<SymbolNode>(base);
  final remappedSymbol = _notRemap[node.symbol];
  if (node.mode != Mode.math ||
      node.variantForm == true ||
      remappedSymbol == null) {
    throw ParseException('\\not has to be followed by a combinable character');
  }
  return node.withSymbol(
    remappedSymbol,
  );
}
