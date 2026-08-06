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

import '../../widgets/exception.dart';
import 'token.dart';

class ParseException implements FlutterMathException {
  /// Nullable
  int? position;
  String message;

  String get messageWithType => 'Parser Error: $message';

  /// Nullable
  Token? token;

  ParseException(String message, [this.token]) : message = '$message' {
    final loc = token?.loc;
    if (loc != null && loc.start <= loc.end) {
      final input = loc.lexer.input;

      final start = loc.start;
      this.position = start;
      final end = loc.end;
      if (start == input.length) {
        message = '$message at end of input: ';
      } else {
        message = '$message at position ${start + 1}: ';
      }

      final underlined = input
          .substring(start, end)
          .replaceAllMapped(RegExp(r'[^]'), (match) => '${match[0]}\u0332');
      if (start > 15) {
        message = '$message…${input.substring(start - 15, start)}$underlined';
      } else {
        message = '$message${input.substring(0, start)}$underlined';
      }
      if (end + 15 < input.length) {
        message = '$message${input.substring(end, end + 15)}…';
      } else {
        message = '$message${input.substring(end)}';
      }
    }
  }
}
