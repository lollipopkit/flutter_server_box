part of '../functions.dart';

EncodeResult _accentUnderEncoder(GreenNode node) {
  final accentNode = node as AccentUnderNode;
  final label = accentNode.label;
  final command = accentUnderMapping.entries
      .firstWhereOrNull((entry) => entry.value == label)
      ?.key;
  return command == null
      ? NonStrictEncodeResult(
          'unknown accent_under',
          'No strict match for accent_under symbol under math mode: '
              '${unicodeLiteral(accentNode.label)}',
        )
      : TexCommandEncodeResult(
          command: command,
          args: accentNode.children,
        );
}
