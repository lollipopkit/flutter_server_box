import '../size.dart';
import '../syntax_tree.dart';

const ligatures = {
  '–': '--',
  '—': '---',
  '“': '``',
  '”': "''",
};

// Composite symbols caused by the folding of \not
const negatedOperatorSymbols = {
  '\u219A': ['\u0338', '\u2190'],
  '\u219B': ['\u0338', '\u2192'],
  '\u21AE': ['\u0338', '\u2194'],
  '\u21CD': ['\u0338', '\u21D0'],
  '\u21CF': ['\u0338', '\u21D2'],
  '\u21CE': ['\u0338', '\u21D4'],
  '\u2209': ['\u0338', '\u2208'],
  '\u220C': ['\u0338', '\u220B'],
  '\u2224': ['\u0338', '\u2223'],
  '\u2226': ['\u0338', '\u2225'],
  '\u2241': ['\u0338', '\u223C'],
  // '\u2241': ['\u0338', '\u007E'],
  '\u2244': ['\u0338', '\u2243'],
  '\u2247': ['\u0338', '\u2245'],
  '\u2249': ['\u0338', '\u2248'],
  '\u226D': ['\u0338', '\u224D'],
  '\u2260': ['\u0338', '\u003D'],
  '\u2262': ['\u0338', '\u2261'],
  '\u226E': ['\u0338', '\u003C'],
  '\u226F': ['\u0338', '\u003E'],
  '\u2270': ['\u0338', '\u2264'],
  '\u2271': ['\u0338', '\u2265'],
  '\u2274': ['\u0338', '\u2272'],
  '\u2275': ['\u0338', '\u2273'],
  '\u2278': ['\u0338', '\u2276'],
  '\u2279': ['\u0338', '\u2277'],
  '\u2280': ['\u0338', '\u227A'],
  '\u2281': ['\u0338', '\u227B'],
  '\u2284': ['\u0338', '\u2282'],
  '\u2285': ['\u0338', '\u2283'],
  '\u2288': ['\u0338', '\u2286'],
  '\u2289': ['\u0338', '\u2287'],
  '\u22AC': ['\u0338', '\u22A2'],
  '\u22AD': ['\u0338', '\u22A8'],
  '\u22AE': ['\u0338', '\u22A9'],
  '\u22AF': ['\u0338', '\u22AB'],
  '\u22E0': ['\u0338', '\u227C'],
  '\u22E1': ['\u0338', '\u227D'],
  '\u22E2': ['\u0338', '\u2291'],
  '\u22E3': ['\u0338', '\u2292'],
  '\u22EA': ['\u0338', '\u22B2'],
  '\u22EB': ['\u0338', '\u22B3'],
  '\u22EC': ['\u0338', '\u22B4'],
  '\u22ED': ['\u0338', '\u22B5'],
  '\u2204': ['\u0338', '\u2203'],
};

// Compacted composite symbols

const compactedCompositeSymbols = {
  '\u2237': [':', ':'], //\dblcolon
  '\u2254': [':', '='], //\coloneqq
  '\u2255': ['=', ':'], //\eqqcolon
  '\u2239': ['-', ':'], //\eqcolon
  '\u27e6': ['[', '['], //\llbracket
  '\u27e7': [']', ']'], //\rrbracket
  '\u2983': ['{', '['], //\lBrace
  '\u2984': [']', '}'], //\rBrace
};

final compactedCompositeSymbolSpacings = {
  '\u2237': (-0.9).mu, //\dblcolon
  '\u2254': (-1.2).mu, //\coloneqq
  '\u2255': (-3.2).mu, //\eqqcolon
  '\u2239': (-3.2).mu, //\eqcolon
  '\u27e6': (-3.2).mu, //\llbracket
  '\u27e7': (-3.2).mu, //\rrbracket
  '\u2983': (-3.2).mu, //\lBrace
  '\u2984': (-3.2).mu, //\rBrace
};

final compactedCompositeSymbolTypes = {
  '\u2237': AtomType.rel, //\dblcolon
  '\u2254': AtomType.rel, //\coloneqq
  '\u2255': AtomType.rel, //\eqqcolon
  '\u2239': AtomType.rel, //\eqcolon
  '\u27e6': AtomType.open, //\llbracket
  '\u27e7': AtomType.close, //\rrbracket
  '\u2983': AtomType.open, //\lBrace
  '\u2984': AtomType.close, //\rBrace
};
