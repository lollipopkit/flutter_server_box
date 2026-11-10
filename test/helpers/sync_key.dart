import 'dart:async';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';

/// A sync key's file, in memory, with the version a write must name. While
/// [blind], a device that does not see the one there yet (iCloud's
/// delivery, a write at the same moment); while [offline], one that cannot
/// reach it.
final class MemoryKeyFile implements SyncKeyFile {
  MemoryKeyFile([this.id = 'test']);

  @override
  final String id;

  Uint8List? body;
  var _version = 0;
  var writes = 0;
  var blind = false;
  var offline = false;

  /// As a store that does not order writes, holding what was synced.
  var holdsSynced = false;

  @override
  Future<bool> canCreate() async => !holdsSynced;

  String? get _current => body == null || blind ? null : '$_version';

  /// Each read waits for it while set: a read still on its way.
  Completer<void>? held;

  @override
  Future<({Uint8List body, String version})?> read() async {
    await held?.future;
    if (offline) throw StateError('offline');
    final current = _current;
    return current == null ? null : (body: body!, version: current);
  }

  @override
  Future<String?> write(Uint8List body, {required String? ifVersion}) async {
    if (offline) throw StateError('offline');
    if (_current != ifVersion) return null;
    this.body = body;
    writes++;
    return '${++_version}';
  }

  /// Another device's write.
  void put(Uint8List body) {
    this.body = body;
    _version++;
  }
}

/// [file]'s sync key, opened with the backup password here, as the app
/// opens one.
Future<SyncKeyHandle> keyOf(SyncKeyFile file, {bool create = true}) {
  SyncKeyring.init(label: 'ServerBox sync key');
  return SyncKeyring.ofFiles(file, create: create);
}
