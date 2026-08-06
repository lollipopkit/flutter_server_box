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

import '../../utils/log.dart';
import 'macros.dart';
import 'parse_error.dart';
import 'parser.dart';
import 'token.dart';

/// Strict level for [TexParser]
enum Strict {
  /// Ignore non-strict behaviors
  ignore,

  /// Warn on non-strict behaviors
  warn,

  /// Throw on non-strict behaviors
  error,

  /// Non-strict behaviors will be reported to [TexParserSettings.strictFun] and
  /// processed according to the return value
  function,
}

/// Settings for [TexParser]
class TexParserSettings {
  final bool displayMode; // TODO
  final bool throwOnError; // TODO

  /// Extra macros
  final Map<String, MacroDefinition> macros;

  /// Max expand depth for macro expansions. Default 1000
  final int maxExpand;

  /// Strict level for parsing. Default [Strict.warn]
  final Strict strict;

  /// Functions to decide how to handle non-strict behaviors. Must set
  /// [TexParserSettings.strict] to [Strict.function]
  final Strict Function(String, String, Token?)? strictFun;

  final bool globalGroup; // TODO

  /// Behavior of `\color` command
  ///
  /// See https://katex.org/docs/options.html
  final bool colorIsTextColor;

  const TexParserSettings({
    this.displayMode = false,
    this.throwOnError = true,
    this.macros = const {},
    this.maxExpand = 1000,
    Strict strict = Strict.warn,
    this.strictFun,
    this.globalGroup = false,
    this.colorIsTextColor = false,
  }) : this.strict = strictFun == null ? strict : Strict.function
  //: assert(strict != Strict.function || strictFun != null) // This line causes analyzer error
  ;

  void reportNonstrict(String errorCode, String errorMsg, [Token? token]) {
    final strict = this.strict != Strict.function
        ? this.strict
        : (strictFun?.call(errorCode, errorMsg, token) ?? Strict.warn);
    switch (strict) {
      case Strict.ignore:
        return;
      case Strict.error:
        throw ParseException(
            "LaTeX-incompatible input and strict mode is set to 'error': "
            '$errorMsg [$errorCode]',
            token);
      case Strict.warn:
        warn("LaTeX-incompatible input and strict mode is set to 'warn': "
            '$errorMsg [$errorCode]');
        break;
      default:
        warn('LaTeX-incompatible input and strict mode is set to '
            "unrecognized '$strict': $errorMsg [$errorCode]");
    }
  }

  bool useStrictBehavior(String errorCode, String errorMsg, [Token? token]) {
    var strict = this.strict;
    if (strict == Strict.function) {
      try {
        strict = strictFun!(errorCode, errorMsg, token);
      } on Object {
        strict = Strict.error;
      }
    }
    switch (strict) {
      case Strict.ignore:
        return false;
      case Strict.error:
        return true;
      case Strict.warn:
        warn("LaTeX-incompatible input and strict mode is set to 'warn': "
            '$errorMsg [$errorCode]');
        return false;
      default:
        warn('LaTeX-incompatible input and strict mode is set to '
            "unrecognized '$strict': $errorMsg [$errorCode]");
        return false;
    }
  }
}
