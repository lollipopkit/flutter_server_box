// The MIT License (MIT)
//
// Copyright (c) 2013-2019 Khan Academy and other contributors
// Copyright (c) 2020 znjameswu <znjameswu@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

//ignore_for_file: prefer_single_quotes
//ignore_for_file: lines_longer_than_80_chars

import '../../ast/syntax_tree.dart';
import '../../ast/types.dart';
import '../../font/metrics/font_metrics_data.dart';
import '../../utils/log.dart';

import 'functions.dart';
import 'macro_expander.dart';
import 'parse_error.dart';
import 'symbols.dart';
import 'token.dart';

class MacroDefinition {
  final MacroExpansion Function(MacroContext context) expand;
  const MacroDefinition(this.expand, {this.unexpandable = false});
  final bool unexpandable;

  bool get expandable => !unexpandable;

  MacroDefinition.fromString(String output)
      : this((context) => MacroExpansion.fromString(output, context));
  MacroDefinition.fromCtxString(String Function(MacroContext) expand)
      : this((context) => MacroExpansion.fromString(expand(context), context));
  MacroDefinition.fromMacroExpansion(MacroExpansion output)
      : this((_) => output, unexpandable: output.unexpandable);
}

class MacroExpansion {
  const MacroExpansion({
    required this.tokens,
    required this.numArgs,
    this.unexpandable = false,
  });
  final List<Token> tokens;
  final int numArgs;

  final bool unexpandable;

  static final _strippedRegex = RegExp(r'##', multiLine: true);
  static MacroExpansion fromString(String expansion, MacroContext context) {
    var numArgs = 0;
    if (expansion.contains('#')) {
      final stripped = expansion.replaceAll(_strippedRegex, '');
      while (stripped.contains('#${numArgs + 1}')) {
        numArgs += 1;
      }
    }
    final bodyLexer = context.getNewLexer(expansion);
    final tokens = <Token>[];
    var tok = bodyLexer.lex();
    while (tok.text != 'EOF') {
      tokens.add(tok);
      tok = bodyLexer.lex();
    }
    return MacroExpansion(tokens: tokens.reversed.toList(), numArgs: numArgs);
  }
}

void defineMacro(String name, MacroDefinition body) {
  builtinMacros[name] = body;
}

const digitToNumber = {
  "0": 0,
  "1": 1,
  "2": 2,
  "3": 3,
  "4": 4,
  "5": 5,
  "6": 6,
  "7": 7,
  "8": 8,
  "9": 9,
  "a": 10,
  "A": 10,
  "b": 11,
  "B": 11,
  "c": 12,
  "C": 12,
  "d": 13,
  "D": 13,
  "e": 14,
  "E": 14,
  "f": 15,
  "F": 15,
};

// ignore: avoid_positional_boolean_parameters
String newcommand(MacroContext context, bool existsOK, bool nonexistsOK) {
  var arg = context.consumeArgs(1)[0];
  if (arg.length != 1) {
    throw ParseException("\\newcommand's first argument must be a macro name");
  }
  final name = arg[0].text;

  final exists = context.isDefined(name);
  if (exists && !existsOK) {
    throw ParseException('\\newcommand{$name} attempting to redefine '
        '$name; use \\renewcommand');
  }
  if (!exists && !nonexistsOK) {
    throw ParseException('\\renewcommand{$name} when command $name '
        'does not yet exist; use \\newcommand');
  }

  var numArgs = 0;
  arg = context.consumeArgs(1)[0];
  if (arg.length == 1 && arg[0].text == "[") {
    var argText = '';
    var token = context.expandNextToken();
    while (token.text != "]" && token.text != "EOF") {
      // TODO: Should properly expand arg, e.g., ignore {}s
      argText += token.text;
      token = context.expandNextToken();
    }
    if (!RegExp(r'^\s*[0-9]+\s*$').hasMatch(argText)) {
      throw ParseException('Invalid number of arguments: $argText');
    }
    numArgs = int.parse(argText);
    arg = context.consumeArgs(1)[0];
  }

  // Final arg is the expansion of the macro
  context.macros.set(
      name,
      MacroDefinition.fromMacroExpansion(MacroExpansion(
        tokens: arg,
        numArgs: numArgs,
      )));
  return '';
}

final latexRaiseA =
    '${fontMetricsData['Main-Regular']!["T".codeUnitAt(0)]!.height - 0.7 * fontMetricsData['Main-Regular']!["A".codeUnitAt(0)]!.height}em';

const dotsByToken = {
  ',': '\\dotsc',
  '\\not': '\\dotsb',
  // \keybin@ checks for the following:
  '+': '\\dotsb',
  '=': '\\dotsb',
  '<': '\\dotsb',
  '>': '\\dotsb',
  '-': '\\dotsb',
  '*': '\\dotsb',
  ':': '\\dotsb',
  // Symbols whose definition starts with \DOTSB:
  '\\DOTSB': '\\dotsb',
  '\\coprod': '\\dotsb',
  '\\bigvee': '\\dotsb',
  '\\bigwedge': '\\dotsb',
  '\\biguplus': '\\dotsb',
  '\\bigcap': '\\dotsb',
  '\\bigcup': '\\dotsb',
  '\\prod': '\\dotsb',
  '\\sum': '\\dotsb',
  '\\bigotimes': '\\dotsb',
  '\\bigoplus': '\\dotsb',
  '\\bigodot': '\\dotsb',
  '\\bigsqcup': '\\dotsb',
  '\\And': '\\dotsb',
  '\\longrightarrow': '\\dotsb',
  '\\Longrightarrow': '\\dotsb',
  '\\longleftarrow': '\\dotsb',
  '\\Longleftarrow': '\\dotsb',
  '\\longleftrightarrow': '\\dotsb',
  '\\Longleftrightarrow': '\\dotsb',
  '\\mapsto': '\\dotsb',
  '\\longmapsto': '\\dotsb',
  '\\hookrightarrow': '\\dotsb',
  '\\doteq': '\\dotsb',
  // Symbols whose definition starts with \mathbin:
  '\\mathbin': '\\dotsb',
  // Symbols whose definition starts with \mathrel:
  '\\mathrel': '\\dotsb',
  '\\relbar': '\\dotsb',
  '\\Relbar': '\\dotsb',
  '\\xrightarrow': '\\dotsb',
  '\\xleftarrow': '\\dotsb',
  // Symbols whose definition starts with \DOTSI:
  '\\DOTSI': '\\dotsi',
  '\\int': '\\dotsi',
  '\\oint': '\\dotsi',
  '\\iint': '\\dotsi',
  '\\iiint': '\\dotsi',
  '\\iiiint': '\\dotsi',
  '\\idotsint': '\\dotsi',
  // Symbols whose definition starts with \DOTSX:
  '\\DOTSX': '\\dotsx',
};

//////////////////////////////////////////////////////////////////////
// macro tools

/// Transformed by:
/// /defineMacro\((['"][^'"]*['"]),[\s\r]*(['"][^'"]*['"])/ -> defineMacro($1, MacroDefinition.fromString($2)
/// /defineMacro\((['"][^'"]*['"]), function/ -> defineMacro($1, MacroDefinition(
/// /const ([a-zA-Z]* = context.[a-zA-Z]*[^;]*;)/ -> final $1
/// /let ([^;]*;)$/ -> var $1
/// /==/ -> ==
/// /!=/ -> !=
/// \}\);(([\s\r]*|[\s]//[^\n]*)*defineMacro) -> }));$1
/// `([^']*)` -> '$1'
/// defineMacro\((['"][^'"]*['"]), \(context -> defineMacro($1, MacroDefinition.fromCtxString((context
/// (\([a-zA-Z,:_]*\))[\s]*=>[\s]*\{ -> $1 {
/// charCodeAt -> codeUnitAt
/// ([a-zA-Z.]*) in ([a-zA-Z.]*) -> $2.containsKey($1)
///
/// defineMacro\([\s\n]*"([^"]*)", -> '$1':

final Map<String, MacroDefinition> builtinMacros = {
  '\\noexpand': MacroDefinition((context) {
    // The expansion is the token itself; but that token is interpreted
    // as if its meaning were ‘\relax’ if it is a control sequence that
    // would ordinarily be expanded by TeX’s expansion rules.
    final t = context.popToken();
    if (context.isExpandable(t.text)) {
      t.noexpand = true;
      t.treatAsRelax = true;
    }
    return MacroExpansion(tokens: [t], numArgs: 0);
  }),

  '\\expandafter': MacroDefinition((context) {
    // TeX first reads the token that comes immediately after \expandafter,
    // without expanding it; let’s call this token t. Then TeX reads the
    // token that comes after t (and possibly more tokens, if that token
    // has an argument), replacing it by its expansion. Finally TeX puts
    // t back in front of that expansion.
    final t = context.popToken();
    context.expandOnce(true); // expand only an expandable token
    return MacroExpansion(tokens: [t], numArgs: 0);
  }),

// LaTeX's \@firstoftwo{#1}{#2} expands to #1, skipping #2
// TeX source: \long\def\@firstoftwo#1#2{#1}
  '\\@firstoftwo': MacroDefinition((context) {
    final args = context.consumeArgs(2);
    return MacroExpansion(tokens: args[0], numArgs: 0);
  }),

// LaTeX's \@secondoftwo{#1}{#2} expands to #2, skipping #1
// TeX source: \long\def\@secondoftwo#1#2{#2}
  '\\@secondoftwo': MacroDefinition((context) {
    final args = context.consumeArgs(2);
    return MacroExpansion(tokens: args[1], numArgs: 0);
  }),

// LaTeX's \@ifnextchar{#1}{#2}{#3} looks ahead to the next (unexpanded)
// symbol that isn't a space, consuming any spaces but not consuming the
// first nonspace character.  If that nonspace character matches #1, then
// the macro expands to #2; otherwise, it expands to #3.
  '\\@ifnextchar': MacroDefinition((context) {
    final args = context.consumeArgs(3); // symbol, if, else
    context.consumeSpaces();
    final nextToken = context.future();
    if (args[0].length == 1 && args[0][0].text == nextToken.text) {
      return MacroExpansion(tokens: args[1], numArgs: 0);
    } else {
      return MacroExpansion(tokens: args[2], numArgs: 0);
    }
  }),

// LaTeX's \@ifstar{#1}{#2} looks ahead to the next (unexpanded) symbol.
// If it is '*', then it consumes the symbol, and the macro expands to #1;
// otherwise, the macro expands to #2 (without consuming the symbol).
// TeX source: \def\@ifstar#1{\@ifnextchar *{\@firstoftwo{#1}}}
  '\\@ifstar': MacroDefinition.fromString("\\@ifnextchar *{\\@firstoftwo{#1}}"),

// LaTeX's \TextOrMath{#1}{#2} expands to #1 in text mode, #2 in math mode
  '\\TextOrMath': MacroDefinition((context) {
    final args = context.consumeArgs(2);
    if (context.mode == Mode.text) {
      return MacroExpansion(tokens: args[0], numArgs: 0);
    } else {
      return MacroExpansion(tokens: args[1], numArgs: 0);
    }
  }),

// TeX \char makes a literal character (catcode 12) using the following forms:
// (see The TeXBook, p. 43)
//   \char123  -- decimal
//   \char'123 -- octal
//   \char"123 -- hex
//   \char`x   -- character that can be written (i.e. isn't active)
//   \char`\x  -- character that cannot be written (e.g. %)
// These all refer to characters from the font, so we turn them into special
// calls to a function \@char dealt with in the Parser.
  '\\char': MacroDefinition.fromCtxString((context) {
    var token = context.popToken();
    int? base;
    int? number;
    if (token.text == "'") {
      base = 8;
      token = context.popToken();
    } else if (token.text == '"') {
      base = 16;
      token = context.popToken();
    } else if (token.text == "`") {
      token = context.popToken();
      if (token.text[0] == "\\") {
        number = token.text.codeUnitAt(1);
      } else if (token.text == "EOF") {
        throw ParseException("\\char` missing argument");
      } else {
        number = token.text.codeUnitAt(0);
      }
    } else {
      base = 10;
    }
    if (base != null) {
      // Parse a number in the given base, starting with first 'token'.
      number = digitToNumber[token.text];
      if (number == null || number >= base) {
        throw ParseException('Invalid base-$base digit ${token.text}');
      }
      int? digit;
      while ((digit = digitToNumber[context.future().text]) != null &&
          digit! < base) {
        number = number! * base;
        number += digit;
        context.popToken();
      }
    }
    return '\\@char{$number}';
  }),

// \newcommand{\macro}[args]{definition}
// \renewcommand{\macro}[args]{definition}
// TODO: Optional arguments: \newcommand{\macro}[args][default]{definition}

  '\\newcommand': MacroDefinition.fromCtxString(
      (context) => newcommand(context, false, true)),
  '\\renewcommand': MacroDefinition.fromCtxString(
      (context) => newcommand(context, true, false)),
  '\\providecommand': MacroDefinition.fromCtxString(
      (context) => newcommand(context, true, true)),

// terminal (console) tools
  '\\message': MacroDefinition.fromCtxString((context) {
    final arg = context.consumeArgs(1)[0];
    info(arg.reversed.map((token) => token.text).join(""));
    return '';
  }),
  '\\errmessage': MacroDefinition.fromCtxString((context) {
    final arg = context.consumeArgs(1)[0];
    error(arg.reversed.map((token) => token.text).join(""));
    return '';
  }),
  '\\show': MacroDefinition.fromCtxString((context) {
    final tok = context.popToken();
    final name = tok.text;
    info('$tok, ${context.macros.get(name)}, ${functions[name]},'
        '${texSymbolCommandConfigs[Mode.math]![name]}, ${texSymbolCommandConfigs[Mode.text]![name]}');
    return '';
  }),

//////////////////////////////////////////////////////////////////////
// Grouping
// \let\bgroup={ \let\egroup=}
  '\\bgroup': MacroDefinition.fromString("{"),
  '\\egroup': MacroDefinition.fromString("}"),

// Symbols from latex.ltx:
// \def\lq{`}
// \def\rq{'}
// \def \aa {\r a}
// \def \AA {\r A}
  '\\lq': MacroDefinition.fromString("`"),
  '\\rq': MacroDefinition.fromString("'"),
  // '\\aa': MacroDefinition.fromString("\\r a"),
  // '\\AA': MacroDefinition.fromString("\\r A"),

// TODO these should be migrated into renderconfigs
// Characters omitted from Unicode range 1D400–1D7FF
  '\u212C': MacroDefinition.fromString("\\mathscr{B}"), // script
  '\u2130': MacroDefinition.fromString("\\mathscr{E}"),
  '\u2131': MacroDefinition.fromString("\\mathscr{F}"),
  '\u210B': MacroDefinition.fromString("\\mathscr{H}"),
  '\u2110': MacroDefinition.fromString("\\mathscr{I}"),
  '\u2112': MacroDefinition.fromString("\\mathscr{L}"),
  '\u2133': MacroDefinition.fromString("\\mathscr{M}"),
  '\u211B': MacroDefinition.fromString("\\mathscr{R}"),
  '\u212D': MacroDefinition.fromString("\\mathfrak{C}"), // Fraktur
  '\u210C': MacroDefinition.fromString("\\mathfrak{H}"),
  '\u2128': MacroDefinition.fromString("\\mathfrak{Z}"),

// Define \Bbbk with a macro that works in both HTML and MathML.
  '\\Bbbk': MacroDefinition.fromString("\\Bbb{k}"),

// Unicode middle dot
// The KaTeX fonts do not contain U+00B7. Instead, \cdotp displays
// the dot at U+22C5 and gives it punct spacing.
  '\u00b7': MacroDefinition.fromString("\\cdotp"),

  // wont support
  // \llap and \rlap render their contents in text mode
  // '\\llap': MacroDefinition.fromString("\\mathllap{\\textrm{#1}}"),
  // '\\rlap': MacroDefinition.fromString("\\mathrlap{\\textrm{#1}}"),
  // '\\clap': MacroDefinition.fromString("\\mathclap{\\textrm{#1}}"),

// \not is defined by base/fontmath.ltx via
// \DeclareMathSymbol{\not}{\mathrel}{symbols}{"36}
// It's thus treated like a \mathrel, but defined by a symbol that has zero
// width but extends to the right.  We use \rlap to get that spacing.
// For MathML we write U+0338 here. buildMathML.js will then do the overlay.
// TODO fold 'not' with applicable operators
  // defineMacro(
  //     "\\not",
  //     MacroDefinition.fromString(
  //         '\\html@mathml{\\mathrel{\\mathrlap\\@not}}{\\char")338}'));

// Negated symbols from base/fontmath.ltx:
// \def\neq{\not=} \let\ne=\neq
// \DeclareRobustCommand
//   \notin{\mathrel{\m@th\mathpalette\c@ncel\in}}
// \def\c@ncel#1#2{\m@th\ooalign{$\hfil#1\mkern1mu/\hfil$\crcr$#1#2$}}
  '\\ne': MacroDefinition.fromString("\\neq"),
  '\u2260': MacroDefinition.fromString("\\neq"),
  '\u2209': MacroDefinition.fromString("\\notin"),

// Unicode stacked relations are migrated to complex symbols

// Misc Unicode
  '\u27C2': MacroDefinition.fromString("\\perp"),
  '\u203C': MacroDefinition.fromString("\\mathclose{!\\mkern-0.8mu!}"),
  '\u220C': MacroDefinition.fromString("\\notni"),
  '\u231C': MacroDefinition.fromString("\\ulcorner"),
  '\u231D': MacroDefinition.fromString("\\urcorner"),
  '\u231E': MacroDefinition.fromString("\\llcorner"),
  '\u231F': MacroDefinition.fromString("\\lrcorner"),
  '\u00A9': MacroDefinition.fromString("\\copyright"),
  '\u00AE': MacroDefinition.fromString("\\textregistered"),
  '\uFE0F': MacroDefinition.fromString("\\textregistered"),

// The KaTeX fonts have corners at codepoints that don't match Unicode.
// For MathML purposes, use the Unicode code point.
// TODO strip useless @
  '\\ulcorner': MacroDefinition.fromString("\\@ulcorner"),
  '\\urcorner': MacroDefinition.fromString("\\@urcorner"),
  '\\llcorner': MacroDefinition.fromString("\\@llcorner"),
  '\\lrcorner': MacroDefinition.fromString("\\@lrcorner"),

//////////////////////////////////////////////////////////////////////
// LaTeX_2ε

// \vdots{\vbox{\baselineskip4\p@  \lineskiplimit\z@
// \kern6\p@\hbox{.}\hbox{.}\hbox{.}}}
// We'll call \varvdots, which gets a glyph from symbols.js.
// The zero-width rule gets us an equivalent to the vertical 6pt kern.
// TODO should we accept \vdots's kern ?
  '\\vdots':
      MacroDefinition.fromString("\\mathord{\\varvdots\\rule{0pt}{15pt}}"),
  '\u22ee': MacroDefinition.fromString("\\vdots"),

//////////////////////////////////////////////////////////////////////
// amsmath.sty
// http://mirrors.concertpass.com/tex-archive/macros/latex/required/amsmath/amsmath.pdf

// Italic Greek capital letters.  AMS defines these with \DeclareMathSymbol,
// but they are equivalent to \mathit{\Letter}.
// TODO make them as overrided fonts
  '\\varGamma': MacroDefinition.fromString("\\mathit{\\Gamma}"),
  '\\varDelta': MacroDefinition.fromString("\\mathit{\\Delta}"),
  '\\varTheta': MacroDefinition.fromString("\\mathit{\\Theta}"),
  '\\varLambda': MacroDefinition.fromString("\\mathit{\\Lambda}"),
  '\\varXi': MacroDefinition.fromString("\\mathit{\\Xi}"),
  '\\varPi': MacroDefinition.fromString("\\mathit{\\Pi}"),
  '\\varSigma': MacroDefinition.fromString("\\mathit{\\Sigma}"),
  '\\varUpsilon': MacroDefinition.fromString("\\mathit{\\Upsilon}"),
  '\\varPhi': MacroDefinition.fromString("\\mathit{\\Phi}"),
  '\\varPsi': MacroDefinition.fromString("\\mathit{\\Psi}"),
  '\\varOmega': MacroDefinition.fromString("\\mathit{\\Omega}"),

//\newcommand{\substack}[1]{\subarray{c}#1\endsubarray}
  '\\substack':
      MacroDefinition.fromString("\\begin{subarray}{c}#1\\end{subarray}"),

// \renewcommand{\colon}{\nobreak\mskip2mu\mathpunct{}\nonscript
// \mkern-\thinmuskip{:}\mskip6muplus1mu\relax}

// \newcommand{\boxed}[1]{\fbox{\m@th$\displaystyle#1$}}
// TODO fbox
  '\\boxed': MacroDefinition.fromString("\\fbox{\$\\displaystyle{#1}\$}"),

// \def\iff{\DOTSB\;\Longleftrightarrow\;}
// \def\implies{\DOTSB\;\Longrightarrow\;}
// \def\impliedby{\DOTSB\;\Longleftarrow\;}
  '\\iff': MacroDefinition.fromString("\\DOTSB\\;\\Longleftrightarrow\\;"),
  '\\implies': MacroDefinition.fromString("\\DOTSB\\;\\Longrightarrow\\;"),
  '\\impliedby': MacroDefinition.fromString("\\DOTSB\\;\\Longleftarrow\\;"),

// AMSMath's automatic \dots, based on \mdots@@ macro.

  '\\dots': MacroDefinition.fromCtxString((context) {
    // TODO: If used in text mode, should expand to \textellipsis.
    // However, in KaTeX, \textellipsis and \ldots behave the same
    // (in text mode), and it's unlikely we'd see any of the math commands
    // that affect the behavior of \dots when in text mode.  So fine for now
    // (until we support \ifmmode ... \else ... \fi).
    var thedots = '\\dotso';
    final next = context.expandAfterFuture().text;
    if (dotsByToken.containsKey(next)) {
      thedots = dotsByToken[next]!;
    } else if (
        // next != null &&
        next.length >= 4 && next.substring(0, 4) == '\\not') {
      thedots = '\\dotsb';
    } else if (texSymbolCommandConfigs[Mode.math]!.containsKey(next)) {
      final command = texSymbolCommandConfigs[Mode.math]![next]!;
      if (command.type == AtomType.bin || command.type == AtomType.rel) {
        thedots = '\\dotsb';
      }
    }
    return thedots;
  }),

  '\\dotso': MacroDefinition.fromString("\\ldots"),

  '\\dotsc': MacroDefinition.fromString("\\ldots"),

  '\\cdots': MacroDefinition.fromString("\\@cdots"),

  '\\dotsb': MacroDefinition.fromString("\\cdots"),
  '\\dotsm': MacroDefinition.fromString("\\cdots"),
  '\\dotsi': MacroDefinition.fromString("\\!\\cdots"),
// amsmath doesn't actually define \dotsx, but \dots followed by a macro
// starting with \DOTSX implies \dotso, and then \extra@ detects this case
// and forces the added '\,'.
  '\\dotsx': MacroDefinition.fromString("\\ldots\\,"),

// \let\DOTSI\relax
// \let\DOTSB\relax
// \let\DOTSX\relax
  '\\DOTSI': MacroDefinition.fromString("\\relax"),
  '\\DOTSB': MacroDefinition.fromString("\\relax"),
  '\\DOTSX': MacroDefinition.fromString("\\relax"),

// Spacing, based on amsmath.sty's override of LaTeX defaults
// \DeclareRobustCommand{\tmspace}[3]{%
//   \ifmmode\mskip#1#2\else\kern#1#3\fi\relax}
  '\\tmspace': MacroDefinition.fromString(
      "\\TextOrMath{\\kern#1#3}{\\mskip#1#2}\\relax"),
// \renewcommand{\,}{\tmspace+\thinmuskip{.1667em}}
// TODO: math mode should use \thinmuskip
  '\\,': MacroDefinition.fromString("\\tmspace+{3mu}{.1667em}"),
// \let\thinspace\,
  '\\thinspace': MacroDefinition.fromString("\\,"),
// \def\>{\mskip\medmuskip}
// \renewcommand{\:}{\tmspace+\medmuskip{.2222em}}
// TODO: \> and math mode of \: should use \medmuskip = 4mu plus 2mu minus 4mu
  '\\>': MacroDefinition.fromString("\\mskip{4mu}"),
  '\\:': MacroDefinition.fromString("\\tmspace+{4mu}{.2222em}"),
// \let\medspace\:
  '\\medspace': MacroDefinition.fromString("\\:"),
// \renewcommand{\;}{\tmspace+\thickmuskip{.2777em}}
// TODO: math mode should use \thickmuskip = 5mu plus 5mu
  '\\;': MacroDefinition.fromString("\\tmspace+{5mu}{.2777em}"),
// \let\thickspace\;
  '\\thickspace': MacroDefinition.fromString("\\;"),
// \renewcommand{\!}{\tmspace-\thinmuskip{.1667em}}
// TODO: math mode should use \thinmuskip
  '\\!': MacroDefinition.fromString("\\tmspace-{3mu}{.1667em}"),
// \let\negthinspace\!
  '\\negthinspace': MacroDefinition.fromString("\\!"),
// \newcommand{\negmedspace}{\tmspace-\medmuskip{.2222em}}
// TODO: math mode should use \medmuskip
  '\\negmedspace': MacroDefinition.fromString("\\tmspace-{4mu}{.2222em}"),
// \newcommand{\negthickspace}{\tmspace-\thickmuskip{.2777em}}
// TODO: math mode should use \thickmuskip
  '\\negthickspace': MacroDefinition.fromString("\\tmspace-{5mu}{.277em}"),
// \def\enspace{\kern.5em }
  '\\enspace': MacroDefinition.fromString("\\kern.5em "),
// \def\enskip{\hskip.5em\relax}
  '\\enskip': MacroDefinition.fromString("\\hskip.5em\\relax"),
// \def\quad{\hskip1em\relax}
  '\\quad': MacroDefinition.fromString("\\hskip1em\\relax"),
// \def\qquad{\hskip2em\relax}
  '\\qquad': MacroDefinition.fromString("\\hskip2em\\relax"),

// \tag@in@display form of \tag
// TODO tag
  '\\tag': MacroDefinition.fromString("\\@ifstar\\tag@literal\\tag@paren"),
  '\\tag@paren': MacroDefinition.fromString("\\tag@literal{({#1})}"),
  '\\tag@literal': MacroDefinition.fromCtxString((context) {
    if (context.macros.get("\\df@tag") != null) {
      throw ParseException("Multiple \\tag");
    }
    return "\\gdef\\df@tag{\\text{#1}}";
  }),

// \renewcommand{\bmod}{\nonscript\mskip-\medmuskip\mkern5mu\mathbin
//   {\operator@font mod}\penalty900
//   \mkern5mu\nonscript\mskip-\medmuskip}
// \newcommand{\pod}[1]{\allowbreak
//   \if@display\mkern18mu\else\mkern8mu\fi(#1)}
// \renewcommand{\pmod}[1]{\pod{{\operator@font mod}\mkern6mu#1}}
// \newcommand{\mod}[1]{\allowbreak\if@display\mkern18mu
//   \else\mkern12mu\fi{\operator@font mod}\,\,#1}
// TODO: math mode should use \medmuskip = 4mu plus 2mu minus 4mu
  '\\bmod': MacroDefinition.fromString("\\mskip5mu"
      "\\mathbin{\\rm mod}"
      "\\mskip5mu"),
// TODO what should we do about \pod ?
  '\\pod': MacroDefinition.fromString("\\allowbreak"
      "\\mkern8mu(#1)"),
  '\\pmod': MacroDefinition.fromString("\\pod{{\\rm mod}\\mkern6mu#1}"),
  '\\mod': MacroDefinition.fromString("\\allowbreak"
      "\\mkern18mu{\\rm mod}\\,\\,#1"),

//////////////////////////////////////////////////////////////////////
// LaTeX source2e

// \\ defaults to \newline, but changes to \cr within array environment
  '\\\\': MacroDefinition.fromString("\\newline"),

// \def\TeX{T\kern-.1667em\lower.5ex\hbox{E}\kern-.125emX\@}
// TODO: Doesn't normally work in math mode because \@ fails.  KaTeX doesn't
// support \@ yet, so that's omitted, and we add \text so that the result
// doesn't look funny in math mode.

  '\\TeX': MacroDefinition.fromString("\\textrm{"
      "T\\kern-.1667em\\raisebox{-.5ex}{E}\\kern-.125emX"
      "}"),

// \DeclareRobustCommand{\LaTeX}{L\kern-.36em%
//         {\sbox\z@ T%
//          \vbox to\ht\z@{\hbox{\check@mathfonts
//                               \fontsize\sf@size\z@
//                               \math@fontsfalse\selectfont
//                               A}%
//                         \vss}%
//         }%
//         \kern-.15em%
//         \TeX}
// This code aligns the top of the A with the T (from the perspective of TeX's
// boxes, though visually the A appears to extend above slightly).
// We compute the corresponding \raisebox when A is rendered in \normalsize
// \scriptstyle, which has a scale factor of 0.7 (see Options.js).

  '\\LaTeX': MacroDefinition.fromString("\\textrm{"
      'L\\kern-.36em\\raisebox{$latexRaiseA}{\\scriptstyle A}'
      "\\kern-.15em\\TeX}"),

// KaTeX logo based on tweaking LaTeX logo
  '\\KaTeX': MacroDefinition.fromString("\\textrm{"
      'K\\kern-.17em\\raisebox{$latexRaiseA}{\\scriptstyle A}'
      "\\kern-.15em\\TeX}"),

// \DeclareRobustCommand\hspace{\@ifstar\@hspacer\@hspace}
// \def\@hspace#1{\hskip  #1\relax}
// \def\@hspacer#1{\vrule \@width\z@\nobreak
//                 \hskip #1\hskip \z@skip}
  '\\hspace': MacroDefinition.fromString("\\hskip #1\\relax"),

//////////////////////////////////////////////////////////////////////
// mathtools.sty migrated to extra_symbols
// TODO: make as overrided type & font

//\providecommand\ordinarycolon{:}
  '\\ordinarycolon': MacroDefinition.fromString(":"),
//\def\vcentcolon{\mathrel{\mathop\ordinarycolon}}
//TODO(edemaine): Not yet centered. Fix via \raisebox or #726
  '\\vcentcolon':
      MacroDefinition.fromString("\\mathrel{\\mathop\\ordinarycolon}"),

// Some Unicode characters are implemented with macros to mathtools functions.
  '\u2237': MacroDefinition.fromString("\\dblcolon"), // ::
  '\u2239': MacroDefinition.fromString("\\eqcolon"), // -:
  '\u2254': MacroDefinition.fromString("\\coloneqq"), // :=
  '\u2255': MacroDefinition.fromString("\\eqqcolon"), // =:
  // '\u2A74': MacroDefinition.fromString("\\Coloneqq"), // ::=

//////////////////////////////////////////////////////////////////////
// colonequals.sty

// Alternate names for mathtools's macros:
  '\\ratio': MacroDefinition.fromString("\\vcentcolon"),
  '\\coloncolon': MacroDefinition.fromString("\\dblcolon"),
  '\\colonequals': MacroDefinition.fromString("\\coloneqq"),
  '\\equalscolon': MacroDefinition.fromString("\\eqqcolon"),
  '\\minuscolon': MacroDefinition.fromString("\\eqcolon"),

// Present in newtxmath, pxfonts and txfonts
  '\\limsup': MacroDefinition.fromString("\\DOTSB\\operatorname*{lim\\,sup}"),
  '\\liminf': MacroDefinition.fromString("\\DOTSB\\operatorname*{lim\\,inf}"),

//////////////////////////////////////////////////////////////////////
// MathML alternates for KaTeX glyphs in the Unicode private area

//////////////////////////////////////////////////////////////////////
// stmaryrd and semantic migrated to extra symbols

// The stmaryrd and semantic packages render the next four items by calling a
// glyph. Those glyphs do not exist in the KaTeX fonts. Hence the macros.

//////////////////////////////////////////////////////////////////////
// texvc.sty

// The texvc package contains macros available in mediawiki pages.
// We omit the functions deprecated at
// https://en.wikipedia.org/wiki/Help:Displaying_a_formula#Deprecated_syntax

// We also omit texvc's \O, which conflicts with \text{\O}
// TODO: make as override font
  '\\darr': MacroDefinition.fromString("\\downarrow"),
  '\\dArr': MacroDefinition.fromString("\\Downarrow"),
  '\\Darr': MacroDefinition.fromString("\\Downarrow"),
  '\\lang': MacroDefinition.fromString("\\langle"),
  '\\rang': MacroDefinition.fromString("\\rangle"),
  '\\uarr': MacroDefinition.fromString("\\uparrow"),
  '\\uArr': MacroDefinition.fromString("\\Uparrow"),
  '\\Uarr': MacroDefinition.fromString("\\Uparrow"),
  '\\N': MacroDefinition.fromString("\\mathbb{N}"),
  '\\R': MacroDefinition.fromString("\\mathbb{R}"),
  '\\Z': MacroDefinition.fromString("\\mathbb{Z}"),
  '\\alef': MacroDefinition.fromString("\\aleph"),
  '\\alefsym': MacroDefinition.fromString("\\aleph"),
  '\\Alpha': MacroDefinition.fromString("\\mathrm{A}"),
  '\\Beta': MacroDefinition.fromString("\\mathrm{B}"),
  '\\bull': MacroDefinition.fromString("\\bullet"),
  '\\Chi': MacroDefinition.fromString("\\mathrm{X}"),
  '\\clubs': MacroDefinition.fromString("\\clubsuit"),
  '\\cnums': MacroDefinition.fromString("\\mathbb{C}"),
  '\\Complex': MacroDefinition.fromString("\\mathbb{C}"),
  '\\Dagger': MacroDefinition.fromString("\\ddagger"),
  '\\diamonds': MacroDefinition.fromString("\\diamondsuit"),
  '\\empty': MacroDefinition.fromString("\\emptyset"),
  '\\Epsilon': MacroDefinition.fromString("\\mathrm{E}"),
  '\\Eta': MacroDefinition.fromString("\\mathrm{H}"),
  '\\exist': MacroDefinition.fromString("\\exists"),
  '\\harr': MacroDefinition.fromString("\\leftrightarrow"),
  '\\hArr': MacroDefinition.fromString("\\Leftrightarrow"),
  '\\Harr': MacroDefinition.fromString("\\Leftrightarrow"),
  '\\hearts': MacroDefinition.fromString("\\heartsuit"),
  '\\image': MacroDefinition.fromString("\\Im"),
  '\\infin': MacroDefinition.fromString("\\infty"),
  '\\Iota': MacroDefinition.fromString("\\mathrm{I}"),
  '\\isin': MacroDefinition.fromString("\\in"),
  '\\Kappa': MacroDefinition.fromString("\\mathrm{K}"),
  '\\larr': MacroDefinition.fromString("\\leftarrow"),
  '\\lArr': MacroDefinition.fromString("\\Leftarrow"),
  '\\Larr': MacroDefinition.fromString("\\Leftarrow"),
  '\\lrarr': MacroDefinition.fromString("\\leftrightarrow"),
  '\\lrArr': MacroDefinition.fromString("\\Leftrightarrow"),
  '\\Lrarr': MacroDefinition.fromString("\\Leftrightarrow"),
  '\\Mu': MacroDefinition.fromString("\\mathrm{M}"),
  '\\natnums': MacroDefinition.fromString("\\mathbb{N}"),
  '\\Nu': MacroDefinition.fromString("\\mathrm{N}"),
  '\\Omicron': MacroDefinition.fromString("\\mathrm{O}"),
  '\\plusmn': MacroDefinition.fromString("\\pm"),
  '\\rarr': MacroDefinition.fromString("\\rightarrow"),
  '\\rArr': MacroDefinition.fromString("\\Rightarrow"),
  '\\Rarr': MacroDefinition.fromString("\\Rightarrow"),
  '\\real': MacroDefinition.fromString("\\Re"),
  '\\reals': MacroDefinition.fromString("\\mathbb{R}"),
  '\\Reals': MacroDefinition.fromString("\\mathbb{R}"),
  '\\Rho': MacroDefinition.fromString("\\mathrm{P}"),
  '\\sdot': MacroDefinition.fromString("\\cdot"),
  '\\sect': MacroDefinition.fromString("\\S"),
  '\\spades': MacroDefinition.fromString("\\spadesuit"),
  '\\sub': MacroDefinition.fromString("\\subset"),
  '\\sube': MacroDefinition.fromString("\\subseteq"),
  '\\supe': MacroDefinition.fromString("\\supseteq"),
  '\\Tau': MacroDefinition.fromString("\\mathrm{T}"),
  '\\thetasym': MacroDefinition.fromString("\\vartheta"),
// TODO: '\\varcoppa': MacroDefinition.fromString("\\\mbox{\\coppa}"),
  '\\weierp': MacroDefinition.fromString("\\wp"),
  '\\Zeta': MacroDefinition.fromString("\\mathrm{Z}"),

//////////////////////////////////////////////////////////////////////
// statmath.sty
// https://ctan.math.illinois.edu/macros/latex/contrib/statmath/statmath.pdf

  '\\argmin': MacroDefinition.fromString("\\DOTSB\\operatorname*{arg\\,min}"),
  '\\argmax': MacroDefinition.fromString("\\DOTSB\\operatorname*{arg\\,max}"),
  '\\plim': MacroDefinition.fromString("\\DOTSB\\operatorname*{plim}\\limits"),
  // "\\DOTSB\\mathop{\\operatorname{plim}}\\limits"),

//////////////////////////////////////////////////////////////////////
// braket.sty
// http://ctan.math.washington.edu/tex-archive/macros/latex/contrib/braket/braket.pdf

  '\\bra': MacroDefinition.fromString("\\mathinner{\\langle{#1}|}"),
  '\\ket': MacroDefinition.fromString("\\mathinner{|{#1}\\rangle}"),
  '\\braket': MacroDefinition.fromString("\\mathinner{\\langle{#1}\\rangle}"),
  '\\Bra': MacroDefinition.fromString("\\left\\langle#1\\right|"),
  '\\Ket': MacroDefinition.fromString("\\left|#1\\right\\rangle"),

// Custom Khan Academy colors, should be moved to an optional package
  '\\blue': MacroDefinition.fromString("\\textcolor{##6495ed}{#1}"),
  '\\orange': MacroDefinition.fromString("\\textcolor{##ffa500}{#1}"),
  '\\pink': MacroDefinition.fromString("\\textcolor{##ff00af}{#1}"),
  '\\red': MacroDefinition.fromString("\\textcolor{##df0030}{#1}"),
  '\\green': MacroDefinition.fromString("\\textcolor{##28ae7b}{#1}"),
  '\\gray': MacroDefinition.fromString("\\textcolor{gray}{#1}"),
  '\\purple': MacroDefinition.fromString("\\textcolor{##9d38bd}{#1}"),
  '\\blueA': MacroDefinition.fromString("\\textcolor{##ccfaff}{#1}"),
  '\\blueB': MacroDefinition.fromString("\\textcolor{##80f6ff}{#1}"),
  '\\blueC': MacroDefinition.fromString("\\textcolor{##63d9ea}{#1}"),
  '\\blueD': MacroDefinition.fromString("\\textcolor{##11accd}{#1}"),
  '\\blueE': MacroDefinition.fromString("\\textcolor{##0c7f99}{#1}"),
  '\\tealA': MacroDefinition.fromString("\\textcolor{##94fff5}{#1}"),
  '\\tealB': MacroDefinition.fromString("\\textcolor{##26edd5}{#1}"),
  '\\tealC': MacroDefinition.fromString("\\textcolor{##01d1c1}{#1}"),
  '\\tealD': MacroDefinition.fromString("\\textcolor{##01a995}{#1}"),
  '\\tealE': MacroDefinition.fromString("\\textcolor{##208170}{#1}"),
  '\\greenA': MacroDefinition.fromString("\\textcolor{##b6ffb0}{#1}"),
  '\\greenB': MacroDefinition.fromString("\\textcolor{##8af281}{#1}"),
  '\\greenC': MacroDefinition.fromString("\\textcolor{##74cf70}{#1}"),
  '\\greenD': MacroDefinition.fromString("\\textcolor{##1fab54}{#1}"),
  '\\greenE': MacroDefinition.fromString("\\textcolor{##0d923f}{#1}"),
  '\\goldA': MacroDefinition.fromString("\\textcolor{##ffd0a9}{#1}"),
  '\\goldB': MacroDefinition.fromString("\\textcolor{##ffbb71}{#1}"),
  '\\goldC': MacroDefinition.fromString("\\textcolor{##ff9c39}{#1}"),
  '\\goldD': MacroDefinition.fromString("\\textcolor{##e07d10}{#1}"),
  '\\goldE': MacroDefinition.fromString("\\textcolor{##a75a05}{#1}"),
  '\\redA': MacroDefinition.fromString("\\textcolor{##fca9a9}{#1}"),
  '\\redB': MacroDefinition.fromString("\\textcolor{##ff8482}{#1}"),
  '\\redC': MacroDefinition.fromString("\\textcolor{##f9685d}{#1}"),
  '\\redD': MacroDefinition.fromString("\\textcolor{##e84d39}{#1}"),
  '\\redE': MacroDefinition.fromString("\\textcolor{##bc2612}{#1}"),
  '\\maroonA': MacroDefinition.fromString("\\textcolor{##ffbde0}{#1}"),
  '\\maroonB': MacroDefinition.fromString("\\textcolor{##ff92c6}{#1}"),
  '\\maroonC': MacroDefinition.fromString("\\textcolor{##ed5fa6}{#1}"),
  '\\maroonD': MacroDefinition.fromString("\\textcolor{##ca337c}{#1}"),
  '\\maroonE': MacroDefinition.fromString("\\textcolor{##9e034e}{#1}"),
  '\\purpleA': MacroDefinition.fromString("\\textcolor{##ddd7ff}{#1}"),
  '\\purpleB': MacroDefinition.fromString("\\textcolor{##c6b9fc}{#1}"),
  '\\purpleC': MacroDefinition.fromString("\\textcolor{##aa87ff}{#1}"),
  '\\purpleD': MacroDefinition.fromString("\\textcolor{##7854ab}{#1}"),
  '\\purpleE': MacroDefinition.fromString("\\textcolor{##543b78}{#1}"),
  '\\mintA': MacroDefinition.fromString("\\textcolor{##f5f9e8}{#1}"),
  '\\mintB': MacroDefinition.fromString("\\textcolor{##edf2df}{#1}"),
  '\\mintC': MacroDefinition.fromString("\\textcolor{##e0e5cc}{#1}"),
  '\\grayA': MacroDefinition.fromString("\\textcolor{##f6f7f7}{#1}"),
  '\\grayB': MacroDefinition.fromString("\\textcolor{##f0f1f2}{#1}"),
  '\\grayC': MacroDefinition.fromString("\\textcolor{##e3e5e6}{#1}"),
  '\\grayD': MacroDefinition.fromString("\\textcolor{##d6d8da}{#1}"),
  '\\grayE': MacroDefinition.fromString("\\textcolor{##babec2}{#1}"),
  '\\grayF': MacroDefinition.fromString("\\textcolor{##888d93}{#1}"),
  '\\grayG': MacroDefinition.fromString("\\textcolor{##626569}{#1}"),
  '\\grayH': MacroDefinition.fromString("\\textcolor{##3b3e40}{#1}"),
  '\\grayI': MacroDefinition.fromString("\\textcolor{##21242c}{#1}"),
  '\\kaBlue': MacroDefinition.fromString("\\textcolor{##314453}{#1}"),
  '\\kaGreen': MacroDefinition.fromString("\\textcolor{##71B307}{#1}"),
};
