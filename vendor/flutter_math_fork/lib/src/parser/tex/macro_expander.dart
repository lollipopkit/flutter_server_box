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

import '../../ast/types.dart';
import 'functions.dart';
import 'lexer.dart';
import 'macros.dart';
import 'namespace.dart';
import 'parse_error.dart';
import 'settings.dart';
import 'symbols.dart';
import 'token.dart';

// List of commands that act like macros but aren't defined as a macro,
// function, or symbol.  Used in `isDefined`.
const implicitCommands = {
  '\\relax', // MacroExpander.js
  '^', // Parser.js
  '_', // Parser.js
  '\\limits', // Parser.js
  '\\nolimits', // Parser.js
};

class MacroExpander implements MacroContext {
  MacroExpander(this.input, this.settings, this.mode)
      : this.macros = Namespace(builtinMacros, settings.macros),
        this.lexer = Lexer(input, settings);

  String input;
  TexParserSettings settings;
  Mode mode;
  int expansionCount = 0;
  var stack = <Token>[];
  Lexer lexer;
  Namespace<MacroDefinition> macros;

  Token expandAfterFuture() {
    this.expandOnce();
    return this.future();
  }

  Token expandNextToken() {
    while (true) {
      final expanded = this.expandOnce();
      if (expanded != null) {
        if (expanded.text == r'\relax') {
          this.stack.removeLast();
        } else {
          return this.stack.removeLast();
        }
      }
    }
  }

  // switchMode is replaced by a plain setter

  void beginGroup() {
    this.macros.beginGroup();
  }

  void endGroup() {
    this.macros.endGroup();
  }

  Token? expandOnce([bool expandableOnly = false]) {
    final topToken = this.popToken();
    final name = topToken.text;
    final expansion = !topToken.noexpand ? this._getExpansion(name) : null;
    if (expansion == null || (expandableOnly && expansion.unexpandable)) {
      if (expandableOnly &&
          expansion == null &&
          name[0] == '\\' &&
          this.isDefined(name)) {
        throw ParseException('Undefined control sequence: $name');
      }
      this.pushToken(topToken);
      return topToken;
    }
    this.expansionCount += 1;
    if (this.expansionCount > this.settings.maxExpand) {
      throw ParseException('Too many expansions: infinite loop or '
          'need to increase maxExpand setting');
    }
    var tokens = expansion.tokens;
    if (expansion.numArgs != 0) {
      final args = this.consumeArgs(expansion.numArgs);
      // Make a copy to avoid modify to be sure.
      // Actually not needed with current implementation.
      // But who knows for the future?
      tokens = tokens.toList();
      for (var i = tokens.length - 1; i >= 0; --i) {
        var tok = tokens[i];
        if (tok.text == '#') {
          if (i == 0) {
            throw ParseException(
                'Incomplete placeholder at end of macro body', tok);
          }
          --i;
          tok = tokens[i];
          if (tok.text == '#') {
            tokens.removeAt(i + 1);
          } else {
            try {
              tokens.replaceRange(i, i + 2, args[int.parse(tok.text) - 1]);
            } on FormatException {
              throw ParseException('Not a valid argument number', tok);
            }
          }
        }
      }
    }
    this.pushTokens(tokens);
    return null;
  }

  void pushToken(Token token) {
    this.stack.add(token);
  }

  void pushTokens(List<Token> tokens) {
    this.stack.addAll(tokens);
  }

  Token popToken() {
    this.future();
    return this.stack.removeLast();
  }

  Token future() {
    if (this.stack.isEmpty) {
      this.stack.add(this.lexer.lex());
    }
    return this.stack.last;
  }

  MacroExpansion? _getExpansion(String name) {
    final definition = this.macros.get(name);
    if (definition == null) {
      return null;
    }
    return definition.expand(this);
  }

  List<List<Token>> consumeArgs(int numArgs) {
    final args = List<List<Token>>.generate(numArgs, (i) {
      this.consumeSpaces();
      final startOfArg = this.popToken();
      if (startOfArg.text == '{') {
        final arg = <Token>[];
        var depth = 1;
        while (depth != 0) {
          final tok = this.popToken();
          arg.add(tok);
          switch (tok.text) {
            case '{':
              ++depth;
              break;
            case '}':
              --depth;
              break;
            case 'EOF':
              throw ParseException(
                  'End of input in macro argument', startOfArg);
          }
        }
        arg.removeLast();
        return arg.reversed.toList();
      } else if (startOfArg.text == 'EOF') {
        throw ParseException('End of input expecting macro argument');
      } else {
        return [startOfArg];
      }
    });
    return args;
  }

  void consumeSpaces() {
    while (true) {
      final token = this.future();
      if (token.text == ' ') {
        this.stack.removeLast();
      } else {
        break;
      }
    }
  }

  bool isDefined(String name) =>
      this.macros.has(name) ||
      texSymbolCommandConfigs[Mode.math]!.containsKey(name) ||
      texSymbolCommandConfigs[Mode.text]!.containsKey(name) ||
      functions.containsKey(name) ||
      implicitCommands.contains(name);

  bool isExpandable(String name) {
    final macro = macros.get(name);
    return macro?.expandable ?? functions.containsKey(name);
  }

  Lexer getNewLexer(String input) => Lexer(input, this.settings);

  String? expandMacroAsText(String name) {
    final tokens = this.expandMacro(name);
    if (tokens != null) {
      return tokens.map((token) => token.text).join('');
    }
    return null;
  }

  List<Token>? expandMacro(String name) {
    if (this.macros.get(name) == null) {
      return null;
    }
    final output = <Token>[];
    final oldStackLength = this.stack.length;
    this.pushToken(Token(name));
    while (this.stack.length > oldStackLength) {
      final expanded = this.expandOnce();
      // expandOnce returns Token if and only if it's fully expanded.
      if (expanded != null) {
        output.add(this.stack.removeLast());
      }
    }
    return output;
  }
}

abstract class MacroContext {
  Mode get mode;
  Namespace<MacroDefinition> get macros;
  Token future();
  Token popToken();
  void consumeSpaces();
//  Token expandAfterFuture();
  // ignore: avoid_positional_boolean_parameters
  Token? expandOnce([bool expandableOnly]);
  Token expandAfterFuture();
  Token expandNextToken();
//
  List<List<Token>> consumeArgs(int numArgs);
  bool isDefined(String name);
  bool isExpandable(String name);

  Lexer getNewLexer(String input);
}
