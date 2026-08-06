part of '../functions.dart';

EncodeResult _multisciprtsEncoder(GreenNode node) {
  final scriptsNode = node as MultiscriptsNode;
  return TexMultiscriptEncodeResult(
    base: scriptsNode.base,
    sub: scriptsNode.sub,
    sup: scriptsNode.sup,
    presub: scriptsNode.presub,
    presup: scriptsNode.presup,
  );
}
