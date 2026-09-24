import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// A monitor agent's blob store, as a backup destination.
///
/// **What is stored is ciphertext.** `BakSyncer.writeEncryptedBackup` encrypts
/// before anything is uploaded, with a password held in this device's secure
/// storage, so an agent holds bytes it cannot read and neither can its panel.
/// That is what makes leaving a backup on a server acceptable at all, and it is
/// also why nothing here inspects what it moves: this class reads the local
/// file, hands the bytes over, and writes back what it is given.
///
/// Not a `part of` fl_lib's sync library, though its three peers are. Those
/// live there because their credentials are prefs and their requests are plain
/// HTTP; this one dials *this app's own server records* through
/// `MonitorHttpClient`, a type fl_lib does not know about. It is why
/// `RemoteStorage` stopped being a `base` class — see its doc comment.
final class MonitorBackupStorage implements RemoteStorage<String> {
  MonitorBackupStorage(this.serverId, MonitorHttpCredential monitor)
    : _monitor = monitor,
      _client = MonitorHttpClient(monitor);

  /// The server record this store belongs to, so a caller holding a cached one
  /// can tell whether it is still the right one.
  final String serverId;

  final MonitorHttpCredential _monitor;
  final MonitorHttpClient _client;

  /// Which *configuration* of this backend this is, for the sync checkpoint.
  ///
  /// The address, because that is what makes two of these different stores: two
  /// server records pointing at one agent are one store, and a record whose
  /// address was edited is a different one. Hashed by the caller, so nothing
  /// that names an endpoint is written into device-local preferences a second
  /// time.
  @override
  String get identity => _monitor.addr;

  /// The path a call moves bytes to or from.
  ///
  /// `localPath` where the caller gave one — the app's manual export uses a
  /// dated name — and otherwise the same relative path the remote side uses,
  /// which is how every other backend here resolves it.
  String _localPath(String relativePath, String? localPath) =>
      localPath ?? Paths.doc.joinPath(relativePath);

  @override
  Future<void> upload({required String relativePath, String? localPath}) async {
    final path = _localPath(relativePath, localPath);
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('No backup at $path to upload');
    }
    // The length first, so the agent is told where the body ends rather than
    // reading until the connection closes — and so a file larger than its cap
    // is refused by the agent before the whole thing is sent.
    final size = await file.length();
    await _client.backupWrite(
      relativePath,
      file.openRead(),
      size: size,
      // A fresh stream per attempt: the PUT cannot be retried with the stream
      // it was already given, and `backupWrite` is what does the refresh.
      replayData: () => File(path).openRead(),
    );
  }

  @override
  Future<void> download({
    required String relativePath,
    String? localPath,
  }) async {
    final path = _localPath(relativePath, localPath);
    final stream = await _client.backupRead(relativePath);
    // Streamed to disk rather than buffered: a backup is megabytes and this
    // runs on devices where that is a real amount of memory.
    final sink = File(path).openWrite();
    try {
      await sink.addStream(stream);
    } finally {
      await sink.close();
    }
  }

  @override
  Future<void> delete(String relativePath) =>
      _client.backupRemove(relativePath);

  @override
  Future<bool> exists(String relativePath) async {
    final blobs = await _client.fetchBackups();
    return blobs.any((blob) => blob.name == relativePath);
  }

  @override
  Future<List<String>> list() async {
    final blobs = await _client.fetchBackups();
    return blobs.map((blob) => blob.name).toList();
  }

  /// An opaque token that changes when the remote copy does.
  ///
  /// A size and a timestamp, since the agent does not read a blob and so has
  /// nothing to hash. `null` means "assume it changed", which is what a copy
  /// that is not there reads as — the shortcut must not skip the first upload
  /// to a fresh agent.
  @override
  Future<String?> versionTag(String relativePath) async {
    final blobs = await _client.fetchBackups();
    for (final blob in blobs) {
      if (blob.name == relativePath) return blob.versionTag;
    }
    return null;
  }

  /// Releases the HTTP client. A store is built for one server and kept while
  /// the sync points at it, so whoever owns it has to say when it is done with
  /// it — `BakSyncer` does, when the chosen server changes.
  void close() => _client.dispose();
}
