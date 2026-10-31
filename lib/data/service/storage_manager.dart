import 'dart:convert';

import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/storage.dart';
import 'package:server_box/data/service/command_output.dart';
import 'package:server_box/src/rust/api/storage.dart' as ffi;

final class StorageManagerException implements Exception {
  const StorageManagerException(this.code, {this.device, this.why, this.detail});

  final String code;
  final String? device;
  final String? why;
  final String? detail;

  @override
  String toString() => detail ?? code;
}

/// Runs the Rust storage parser and scripts; policy remains in `sbm_parser`.
abstract final class StorageManager {
  static Future<StorageView> view(CommandExec exec) async =>
      StorageView.fromJson(jsonDecode(await _viewJson(exec)) as Map<String, Object?>);

  /// The view as Rust parsed it. [act] checks against this JSON itself, so
  /// the check sees every field `sbm_parser` reads, whatever the Dart model
  /// keeps.
  static Future<String> _viewJson(CommandExec exec) async {
    final result = await exec.run(ffi.storageViewScript(), entry: 'sh');
    if (!result.succeeded) {
      throw StorageManagerException(
        'failed',
        detail: lastOutputLine(result.combined, 'Unable to read storage'),
      );
    }
    try {
      return await ffi.parseStorageViewJson(raw: result.stdout);
    } on ffi.StorageFfiError catch (e) {
      throw StorageManagerException(e.code);
    }
  }

  static Future<List<DiskHealth>> health(
    CommandExec exec, {
    required bool isRoot,
    String? password,
  }) async {
    final result = await PrivilegedExec.run(
      exec,
      ffi.storageHealthScript(),
      isRoot: isRoot,
      password: password,
    );
    if (!result.succeeded) {
      throw StorageManagerException(
        !isRoot && result.exitCode == kSudoPasswordRejected
            ? 'sudo_rejected'
            : 'failed',
        detail: lastOutputLine(result.combined, 'Unable to read disk health'),
      );
    }
    try {
      final json = await ffi.parseStorageHealthJson(raw: result.stdout);
      return [
        for (final item in jsonDecode(json) as List)
          DiskHealth.fromJson(item as Map<String, Object?>),
      ];
    } on ffi.StorageFfiError catch (e) {
      throw StorageManagerException(e.code);
    }
  }

  static Future<void> act(
    CommandExec exec,
    StorageAction action, {
    required bool isRoot,
    String? password,
    String? passphrase,
  }) async {
    // The page's view may be stale: the check reads the machine again.
    final actionJson = jsonEncode(action.toJson());
    final refusalJson = ffi.storageCheckJson(
      viewJson: await _viewJson(exec),
      actionJson: actionJson,
    );
    if (refusalJson != null) {
      try {
        final refusal = StorageRefusal.fromJson(
          jsonDecode(refusalJson) as Map<String, Object?>,
        );
        throw StorageManagerException(
          refusal.error,
          device: refusal.device,
          why: refusal.why,
        );
      } on FormatException {
        throw const StorageManagerException('malformed');
      }
    }

    final script = _actionScript(actionJson, passphrase);
    final result = await PrivilegedExec.run(
      exec,
      script,
      isRoot: isRoot,
      password: password,
    );
    if (!result.succeeded) {
      throw StorageManagerException(
        !isRoot && result.exitCode == kSudoPasswordRejected
            ? 'sudo_rejected'
            : 'failed',
        detail: lastOutputLine(result.combined, 'Storage action failed'),
      );
    }
  }

  static String _actionScript(String actionJson, String? passphrase) {
    try {
      return ffi.storageActionScript(
        actionJson: actionJson,
        passphrase: passphrase,
      );
    } on ffi.StorageFfiError catch (e) {
      throw StorageManagerException(e.code);
    }
  }
}
