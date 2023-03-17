import 'dart:convert';
import 'dart:typed_data';

extension FutureUint8ListX on Future<Uint8List> {
  Future<String> get string async => utf8.decode(await this);
  Future<ByteData> get byteData async => (await this).buffer.asByteData();
}

extension Uint8ListX on Uint8List {
  String get string => utf8.decode(this);
}
