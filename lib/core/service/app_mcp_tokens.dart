import 'dart:io';

import 'package:logging/logging.dart';
import 'package:server_box/core/extension/context/locale.dart' show l10n;
import 'package:server_box/src/rust/api/app_mcp.dart' as ffi;

export 'package:server_box/src/rust/api/app_mcp.dart'
    show AppMcpRegistry, AppMcpToken, appMcpScopes;

/// The registry as it is on disk; empty when there is none yet.
///
/// Its format and every check on it are `sbm_ffi::api::app_mcp`'s. The file
/// may be edited in any editor: it is read again on every request.
Future<String> readMcpRegistryText(File file) async =>
    await file.exists() ? await file.readAsString() : '';

Future<ffi.AppMcpRegistry> loadMcpRegistry(File file) async {
  try {
    return ffi.appMcpRegistry(text: await readMcpRegistryText(file));
  } on String catch (detail) {
    throw FormatException('${l10n.appMcpRegistry}: $detail');
  }
}

/// A new token named [name] holding [scopes] (null: every scope), shown once.
Future<String> createMcpToken(
  File file,
  String name, {
  List<String>? scopes,
}) async {
  if (name.trim().isEmpty) throw FormatException(l10n.appMcpName);
  late String token;
  await _edit(file, (text) {
    final minted = ffi.appMcpMint(
      text: text,
      name: name,
      scopes: scopes,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    token = minted.token;
    return minted.registry;
  });
  return token;
}

Future<void> revokeMcpToken(File file, String id) =>
    _edit(file, (text) => ffi.appMcpRevoke(text: text, id: id));

bool _editing = false;

/// Writes what [change] makes of the registry, under a lock another app
/// instance honours, through a file only this account can read.
Future<void> _edit(File file, String Function(String text) change) async {
  if (_editing) throw StateError(l10n.appMcpBusy);
  _editing = true;
  RandomAccessFile? lock;
  try {
    await file.parent.create(recursive: true);
    lock = await File('${file.path}.lock').open(mode: FileMode.append);
    await lock.lock(FileLock.blockingExclusive);
    final String next;
    try {
      next = change(await readMcpRegistryText(file));
    } on String catch (detail) {
      throw FormatException('${l10n.appMcpRegistry}: $detail');
    }
    final staging = await file.parent.createTemp('mcp-registry-');
    try {
      final pending = File('${staging.path}/registry.json');
      await pending.writeAsString(next, flush: true);
      if (Platform.isMacOS || Platform.isLinux) {
        final chmod = await Process.run('/bin/chmod', ['600', pending.path]);
        if (chmod.exitCode != 0) throw StateError(l10n.appMcpProtect);
      }
      await pending.rename(file.path);
    } finally {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        Logger('AppMcp').warning('Could not remove registry staging directory.');
      }
    }
  } finally {
    try {
      await lock?.close();
    } on FileSystemException {
      Logger('AppMcp').warning('Could not close the registry lock.');
    } finally {
      _editing = false;
    }
  }
}
