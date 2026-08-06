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

import '../../../ast.dart';
import 'functions/custom/cursor.dart';
import 'functions/katex_base.dart';
import 'functions/katex_ext.dart';
import 'parser.dart';
import 'token.dart';

class FunctionContext {
  final String funcName;
  final Token? token;
  final String? breakOnTokenText;
  final List<GreenNode> infixExistingArguments;
  const FunctionContext({
    required this.funcName,
    this.token,
    required this.breakOnTokenText,
    this.infixExistingArguments = const [],
  });
}

typedef FunctionHandler<T extends GreenNode> = T Function(
    TexParser parser, FunctionContext context);

class FunctionSpec<T extends GreenNode> {
  final int numArgs;
  final int greediness;
  final bool allowedInText;
  final bool allowedInMath;
  final int numOptionalArgs;
  final bool infix;
  final FunctionHandler<T> handler;

  // Has no real usage during parsing. Serves as hint during encoding.
  final List<Mode?>? argModes;

  const FunctionSpec({
    required this.numArgs,
    this.greediness = 1,
    this.allowedInText = false,
    this.allowedInMath = true,
    this.numOptionalArgs = 0,
    this.infix = false,
    required this.handler,
    this.argModes,
  });

  int get totalArgs => numArgs + numOptionalArgs;
}

extension RegisterFunctionExt on Map<String, FunctionSpec> {
  void registerFunctions(Map<List<String>, FunctionSpec> entries) {
    entries.forEach((key, value) {
      for (final name in key) {
        this[name] = value;
      }
    });
  }
}

final Map<String, FunctionSpec> functions = <String, FunctionSpec>{}
  ..registerFunctions(katexBaseFunctionEntries)
  ..registerFunctions(katexExtFunctionEntries)
  ..registerFunctions(cursorEntries);

