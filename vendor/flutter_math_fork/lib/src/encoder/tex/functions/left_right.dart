part of '../functions.dart';

EncodeResult _leftRightEncoder(GreenNode node) {
  final leftRightNode = node as LeftRightNode;
  final left = _delimEncoder(leftRightNode.leftDelim);
  final right = _delimEncoder(leftRightNode.rightDelim);
  final middles =
      leftRightNode.middle.map(_delimEncoder).toList(growable: false);
  return TransparentTexEncodeResult(<dynamic>[
    '\\left',
    left,
    ...leftRightNode.body.first.children,
    for (var i = 1; i < leftRightNode.body.length; i++) ...[
      '\\middle',
      middles[i - 1],
      ...leftRightNode.body[i].children,
    ],
    '\\right',
    right,
  ]);
}

EncodeResult _delimEncoder(String? delim) {
  if (delim == null) return StaticEncodeResult('.');
  final result = _baseSymbolEncoder(delim, Mode.math);
  return result != null
      ? delimiterCommands.contains(result)
          ? StaticEncodeResult(result)
          : NonStrictEncodeResult.string(
              'illegal delimiter',
              'Non-delimiter symbol ${unicodeLiteral(delim)} '
                  'occured as delimiter',
              result,
            )
      : NonStrictEncodeResult.string(
          'unknown symbol',
          'Unrecognized symbol encountered during TeX encoding: '
              '${unicodeLiteral(delim)} with mode Math',
          '.',
        );
}
