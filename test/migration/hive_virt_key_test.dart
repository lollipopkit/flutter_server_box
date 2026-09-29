/// A virtual key in a Hive box, read after `clipboard` left `VirtKey`.
///
/// The generated adapter wrote a key as one byte, its place in
/// `hive_adapters.g.yaml` — which is not the enum's order. Regenerated from the
/// enum without `clipboard`, it would have read every byte past it as another
/// key, so the adapter is frozen; this is what it has to keep answering.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/hive/legacy_adapters.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sbm-hive-virt-key-');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('each byte names the key it was written for', () async {
    // The bytes the released adapter wrote, straight: a writer that went
    // through the frozen table would only prove the table agrees with itself.
    Hive.registerAdapter(_ByteWriter(), override: true);
    final written = await Hive.openBox<Object>('setting');
    const bytes = {'esc': 0, 'clipboard': 12, 'ime': 13, 'shift': 44, 'tmux': 46};
    for (final MapEntry(:key, :value) in bytes.entries) {
      await written.put(key, _Byte(value));
    }
    await written.put('unknown', const _Byte(99));
    await written.close();

    Hive.registerAdapter(LegacyVirtKeyAdapter(), override: true);
    final read = await Hive.openBox<Object>('setting');
    for (final name in bytes.keys) {
      expect((read.get(name)! as LegacyVirtKeyV1).toJson(), name);
    }
    // As the generated adapter answered a byte it had no case for.
    expect((read.get('unknown')! as LegacyVirtKeyV1).toJson(), 'esc');
  });
}

class _Byte {
  const _Byte(this.value);

  final int value;
}

class _ByteWriter extends TypeAdapter<_Byte> {
  @override
  final typeId = 4;

  @override
  _Byte read(BinaryReader reader) => throw UnsupportedError('seed-only');

  @override
  void write(BinaryWriter writer, _Byte obj) => writer.writeByte(obj.value);
}
