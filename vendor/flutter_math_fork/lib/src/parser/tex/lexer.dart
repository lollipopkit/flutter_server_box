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

import 'parse_error.dart';
import 'settings.dart';
import 'source_location.dart';
import 'token.dart';

const spaceRegexString = '[ \r\n\t]';
const controlWordRegexString = '\\\\[a-zA-Z@]+';
const controlSymbolRegexString = '\\\\[^\uD800-\uDFFF]';
const controlWordWhitespaceRegexString =
    '$controlWordRegexString$spaceRegexString*';
final controlWordWhitespaceRegex =
    RegExp('^($controlWordRegexString)$spaceRegexString*\$');
const combiningDiacriticalMarkString = '[\u0300-\u036f]';
final combiningDiacriticalMarksEndRegex =
    RegExp('$combiningDiacriticalMarkString+\$');
const tokenRegexString = '($spaceRegexString+)|' // white space
    '([!-\\[\\]-\u2027\u202A-\uD7FF\uF900-\uFFFF]' // single codepoint
    '$combiningDiacriticalMarkString*' // ...plus accents
    '|[\uD800-\uDBFF][\uDC00-\uDFFF]' // surrogate pair
    '$combiningDiacriticalMarkString*' // ...plus accents
    '|\\\\verb\\*([^]).*?\\3' // \verb*
    '|\\\\verb([^*a-zA-Z]).*?\\4' // \verb unstarred
    '|\\\\operatorname\\*' // \operatorname*
    '|$controlWordWhitespaceRegexString' // \macroName + spaces
    '|$controlSymbolRegexString)'; // \\, \', etc.

abstract class LexerInterface {
  String get input;
  static final RegExp tokenRegex = RegExp(tokenRegexString, multiLine: true);
}

class Lexer implements LexerInterface {
  static final tokenRegex = RegExp(tokenRegexString, multiLine: true);
  Lexer(this.input, this.settings) : it = tokenRegex.allMatches(input).iterator;

  final String input;
  final TexParserSettings settings;
  final Map<String, int> catCodes = {'%': 14};
  int pos = 0;
  // final Iterable<RegExpMatch> matches;
  final Iterator<RegExpMatch> it;

  Token lex() {
    if (this.pos == input.length) {
      return Token('EOF', SourceLocation(this, pos, pos));
    }
    final hasMatch = it.moveNext();
    if (!hasMatch) {
      throw ParseException('Unexpected character: \'${input[pos]}\'',
          Token(input[pos], SourceLocation(this, pos, pos + 1)));
    }

    final match = it.current;
    if (match.start != pos) {
      throw ParseException('Unexpected character: \'${input[pos]}\'',
          Token(input[pos], SourceLocation(this, pos, pos + 1)));
    }
    pos = match.end;

    var text = match[2] ?? ' ';
    if (text == '%') {
      // comment character
      final nlIndex = input.indexOf('\n', it.current.end);
      if (nlIndex == -1) {
        pos = input.length;
        while (it.moveNext()) {
          pos = it.current.end;
        }
        this.settings.reportNonstrict(
            'commentAtEnd',
            '% comment has no terminating newline; LaTeX would '
                'fail because of commenting the end of math mode (e.g. \$)');
      } else {
        while (it.current.end < nlIndex + 1) {
          final canMoveNext = it.moveNext();
          if (canMoveNext) {
            pos = it.current.end;
          } else {
            break;
          }
        }
      }
      return this.lex();
    }
    final controlMatch = controlWordWhitespaceRegex.firstMatch(text);
    if (controlMatch != null) {
      text = controlMatch.group(1)!;
    }
    return Token(text, SourceLocation(this, match.start, match.end));
  }
}
