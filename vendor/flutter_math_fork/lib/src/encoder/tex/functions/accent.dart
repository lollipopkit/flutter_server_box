part of '../functions.dart';

EncodeResult _accentEncoder(GreenNode node) {
  final accentNode = node as AccentNode;

  final commandCandidates = accentCommandMapping.entries
      .where((entry) => entry.value == accentNode.label)
      .map((entry) => entry.key)
      .toList(growable: false);

  final textCommandCandidates = commandCandidates
      .where((candidate) => functions[candidate]?.allowedInText == true);

  final mathCommandCandidates = commandCandidates
      .where((candidate) => functions[candidate]?.allowedInMath == true);

  if (commandCandidates.isEmpty) {
    return NonStrictEncodeResult(
      'unknown accent',
      'Unrecognized accent symbol encountered during TeX encoding: '
          '${unicodeLiteral(accentNode.label)}',
      encodeTex(node.children.first),
    );
  }

  bool isCommandMatched(String command) =>
      accentNode.isStretchy == !nonStretchyAccents.contains(command) &&
      accentNode.isShifty ==
          (!accentNode.isStretchy || shiftyAccents.contains(command));

  final mathCommand = mathCommandCandidates.firstWhereOrNull(isCommandMatched);

  final math = mathCommand != null
      ? TexCommandEncodeResult(command: mathCommand, args: node.children)
      : mathCommandCandidates.firstOrNull != null
          ? NonStrictEncodeResult(
              'imprecise accent',
              'No strict match for accent symbol under math mode: '
                  '${unicodeLiteral(accentNode.label)}, '
                  '${accentNode.isStretchy ? '' : 'not '}stretchy and '
                  '${accentNode.isShifty ? '' : 'not '}shifty',
              TexCommandEncodeResult(
                command: mathCommandCandidates.first,
                args: node.children,
              ),
            )
          : NonStrictEncodeResult(
              'unknown accent',
              'No strict match for accent symbol under math mode: '
                  '${unicodeLiteral(accentNode.label)}, '
                  '${accentNode.isStretchy ? '' : 'not '}stretchy and '
                  '${accentNode.isShifty ? '' : 'not '}shifty',
              TexCommandEncodeResult(
                  command: commandCandidates.first, args: node.children),
            );

  final textCommand =
      accentNode.isStretchy == false && accentNode.isShifty == true
          ? textCommandCandidates.firstOrNull
          : null;

  final text = textCommand != null
      ? TexCommandEncodeResult(command: textCommand, args: node.children)
      : textCommandCandidates.firstOrNull != null
          ? NonStrictEncodeResult(
              'imprecise accent',
              'No strict match for accent symbol under text mode: '
                  '${unicodeLiteral(accentNode.label)}, '
                  '${accentNode.isStretchy ? '' : 'not '}stretchy and '
                  '${accentNode.isShifty ? '' : 'not '}shifty',
              TexCommandEncodeResult(
                command: textCommandCandidates.first,
                args: node.children,
              ),
            )
          : NonStrictEncodeResult(
              'unknown accent',
              'No strict match for accent symbol under text mode: '
                  '${unicodeLiteral(accentNode.label)}, '
                  '${accentNode.isStretchy ? '' : 'not '}stretchy and '
                  '${accentNode.isShifty ? '' : 'not '}shifty',
              TexCommandEncodeResult(
                  command: commandCandidates.first, args: node.children),
            );

  return ModeDependentEncodeResult(
    math: math,
    text: text,
  );
}
