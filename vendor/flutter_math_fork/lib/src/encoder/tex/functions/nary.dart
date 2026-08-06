part of '../functions.dart';

EncodeResult _naryEncoder(GreenNode node) {
  final naryNode = node as NaryOperatorNode;
  final command = _naryOperatorMapping[naryNode.operator];
  if (command == null) {
    return NonStrictEncodeResult(
      'unknown Nary opertor',
      'Unknown Nary opertor symbol ${unicodeLiteral(naryNode.operator)} '
          'encountered during encoding.',
    );
  }
  return TransparentTexEncodeResult(<dynamic>[
    TexMultiscriptEncodeResult(
      base: naryNode.limits != null
          ? '$command\\${naryNode.limits! ? '' : 'no'}limits'
          : command,
      sub: naryNode.lowerLimit,
      sup: naryNode.upperLimit,
    ),
    naryNode.naryand,
  ]);
}

// Dart compiler bug here. Cannot set it to const
final _naryOperatorMapping = {
  ...singleCharBigOps,
  ...singleCharIntegrals,
};
