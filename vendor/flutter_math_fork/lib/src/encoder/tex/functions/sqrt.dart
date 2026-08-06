part of '../functions.dart';

EncodeResult _sqrtEncoder(GreenNode node) {
  final sqrtNode = node as SqrtNode;
  return TexCommandEncodeResult(
    command: '\\sqrt',
    args: sqrtNode.children,
  );
}
