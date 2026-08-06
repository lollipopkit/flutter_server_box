part of '../functions.dart';

EncodeResult _stretchyOpEncoder(GreenNode node) {
  final arrowNode = node as StretchyOpNode;
  final command = arrowCommandMapping.entries
      .firstWhereOrNull((entry) => entry.value == arrowNode.symbol)
      ?.key;
  return command == null
      ? NonStrictEncodeResult(
          'unknown strechy_op',
          'No strict match for stretchy_op symbol under math mode: '
              '${unicodeLiteral(arrowNode.symbol)}',
        )
      : TexCommandEncodeResult(
          command: command,
          args: <dynamic>[
            arrowNode.above,
            arrowNode.below,
          ],
        );
}
