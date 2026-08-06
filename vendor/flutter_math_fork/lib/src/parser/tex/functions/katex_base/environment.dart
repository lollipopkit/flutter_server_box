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

part of katex_base;

const _environmentEntries = {
  ['\\begin', '\\end']: FunctionSpec(numArgs: 1, handler: _enviromentHandler)
};
GreenNode _enviromentHandler(TexParser parser, FunctionContext context) {
  final nameGroup = parser.parseArgNode(mode: Mode.text, optional: false)!;
  if (nameGroup.children.any((element) => element is! SymbolNode)) {
    throw ParseException('Invalid environment name');
  }
  final envName =
      nameGroup.children.map((node) => (node as SymbolNode).symbol).join();

  if (context.funcName == '\\begin') {
    // begin...end is similar to left...right
    if (!environments.containsKey(envName)) {
      throw ParseException('No such environment: $envName');
    }
    // Build the environment object. Arguments and other information will
    // be made available to the begin and end methods using properties.
    final env = environments[envName]!;
    final result = env.handler(
      parser,
      EnvContext(
        mode: parser.mode,
        envName: envName,
      ),
    );
    parser.expect('\\end', consume: false);
    final endNameToken = parser.nextToken;
    final end = assertNodeType<_EndEnvironmentNode>(
        parser.parseFunction(null, null, null));
    if (end.name != envName) {
      throw ParseException(
          'Mismatch: \\begin{$envName} matched by \\end{${end.name}}',
          endNameToken);
    }
    return result;
  } else {
    return _EndEnvironmentNode(
      name: envName,
    );
  }
}

class _EndEnvironmentNode extends TemporaryNode {
  final String name;
  _EndEnvironmentNode({required this.name});
}
