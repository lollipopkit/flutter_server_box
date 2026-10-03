import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// A monitor agent's backup store, as a backup sync destination.
///
/// What is stored is the backup `BakSyncer.writeEncryptedBackup` already
/// encrypted, so this only moves bytes. Not part of fl_lib's sync library like
/// its three peers: it dials through this app's own [MonitorHttpClient], which
/// fl_lib does not know about.
final class MonitorBackupStorage implements RemoteStorage<String> {
  MonitorBackupStorage(this.serverId, MonitorHttpCredential monitor)
    : _monitor = monitor,
      _client = MonitorHttpClient(monitor);

  /// The server record this store was built from.
  final String serverId;

  final MonitorHttpCredential _monitor;
  final MonitorHttpClient _client;

  /// Whether this store was built from [monitor], so a cached one can be
  /// reused only while the record's agent settings stay the same.
  bool matches(String serverId, MonitorHttpCredential monitor) =>
      this.serverId == serverId && _client.matches(monitor);

  /// The agent's address: two records pointing at one agent are one store, and
  /// a record whose address was edited is another. Hashed by the caller.
  @override
  String get identity => _monitor.addr;

  /// Throws a [MonitorHttpErr] worded for the user when this agent cannot
  /// host the backup: it predates the endpoints, or the account is not an
  /// admin.
  Future<void> check() async {
    final caps = await _client.fetchCapabilities();
    if (!caps.features.contains('backup')) {
      throw MonitorHttpErr(
        type: MonitorHttpErrType.notFound,
        message: l10n.monitorBackupUnsupported,
      );
    }
    if (caps.me?.admin == false) {
      throw MonitorHttpErr(
        type: MonitorHttpErrType.forbidden,
        message: l10n.monitorBackupAdminOnly,
      );
    }
  }

  String _localPath(String relativePath, String? localPath) =>
      localPath ?? Paths.doc.joinPath(relativePath);

  @override
  Future<void> upload({required String relativePath, String? localPath}) async {
    final path = _localPath(relativePath, localPath);
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('No backup at $path to upload');
    }
    await _client.backupWrite(
      relativePath,
      file.openRead,
      size: await file.length(),
    );
  }

  /// Streamed to a temporary file and renamed, so a download that fails
  /// halfway leaves the previous local copy in place.
  @override
  Future<void> download({
    required String relativePath,
    String? localPath,
  }) async {
    final path = _localPath(relativePath, localPath);
    final stream = await _client.backupRead(relativePath);
    final tmp = File('$path.part');
    final sink = tmp.openWrite();
    try {
      await sink.addStream(stream);
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
    await tmp.rename(path);
  }

  @override
  Future<void> delete(String relativePath) =>
      _client.backupRemove(relativePath);

  @override
  Future<bool> exists(String relativePath) async {
    final list = await _client.fetchBackups();
    return list.blobs.any((blob) => blob.name == relativePath);
  }

  @override
  Future<List<String>> list() async {
    final list = await _client.fetchBackups();
    return [for (final blob in list.blobs) blob.name];
  }

  /// `updated_at/size`; null when the blob is absent, which a sync reads as
  /// "changed" and so never skips the first upload to a fresh agent.
  @override
  Future<String?> versionTag(String relativePath) async {
    final list = await _client.fetchBackups();
    for (final blob in list.blobs) {
      if (blob.name == relativePath) return blob.versionTag;
    }
    return null;
  }

  void close() => _client.dispose();
}
