import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:server_box/core/extension/context/locale.dart' show l10n;

typedef McpRegistry = ({
  Map<String, String> tokens,
  Map<String, String> commands,
});

McpRegistry readMcpRegistry(String text) {
  final dynamic root;
  try {
    root = jsonDecode(text);
  } on FormatException {
    throw FormatException(l10n.appMcpRegistry);
  }
  // TODO(migration): remove pre-release policy recognition after the preview.
  // Scoped credentials must be reissued before they can access all tools.
  if (root is Map &&
      root.isNotEmpty &&
      root.keys.every(
        (k) => k == 'defaults' || RegExp(r'^[0-9a-f]{64}$').hasMatch(k),
      )) {
    return (tokens: {}, commands: {});
  }
  if (root is! Map || root.keys.any((k) => k != 'tokens' && k != 'commands')) {
    throw FormatException(l10n.appMcpRegistry);
  }
  Map<String, String> entries(String key) {
    final value = root[key] ?? {};
    if (value is! Map || value.values.any((v) => v is! String)) {
      throw FormatException(l10n.appMcpRegistry);
    }
    return Map<String, String>.from(value);
  }

  final tokens = entries('tokens');
  if (tokens.keys.any((id) => !RegExp(r'^[0-9a-f]{64}$').hasMatch(id))) {
    throw FormatException(l10n.appMcpDigest);
  }
  return (tokens: tokens, commands: entries('commands'));
}

bool _editingTokens = false;

Future<McpRegistry> loadMcpRegistry(File file) async =>
    readMcpRegistry(await file.exists() ? await file.readAsString() : '{}');

Future<String> createMcpToken(File file, String label) async {
  if (label.trim().isEmpty) {
    throw FormatException(l10n.appMcpName);
  }
  final random = Random.secure();
  final token =
      'sbt_${base64Url.encode(List.generate(32, (_) => random.nextInt(256))).replaceAll('=', '')}';
  final digest = sha256.convert(utf8.encode(token)).toString();
  await _editTokens(file, (tokens) => tokens[digest] = label.trim());
  return token;
}

Future<void> revokeMcpToken(File file, String id) =>
    _editTokens(file, (tokens) => tokens.remove(id));

Future<void> _editTokens(
  File file,
  void Function(Map<String, String>) edit,
) async {
  if (_editingTokens) {
    throw StateError(l10n.appMcpBusy);
  }
  _editingTokens = true;
  try {
    final original = await file.exists() ? await file.readAsString() : null;
    final registry = readMcpRegistry(original ?? '{}');
    edit(registry.tokens);
    final staging = await file.parent.createTemp('mcp-tokens-');
    try {
      final pending = File('${staging.path}/tokens.json');
      await pending.writeAsString(
        jsonEncode({'tokens': registry.tokens, 'commands': registry.commands}),
        flush: true,
      );
      if (Platform.isMacOS || Platform.isLinux) {
        final chmod = await Process.run('/bin/chmod', ['600', pending.path]);
        if (chmod.exitCode != 0) {
          throw StateError(l10n.appMcpProtect);
        }
      }
      final current = await file.exists() ? await file.readAsString() : null;
      if (current != original) {
        throw StateError(l10n.appMcpChanged);
      }
      await pending.rename(file.path);
    } finally {
      await staging.delete(recursive: true);
    }
  } finally {
    _editingTokens = false;
  }
}
