import 'dart:convert';
import 'dart:typed_data';

extension Uint8ListX on Future<Uint8List> {
  Future<String> get string async => utf8.decode(await this);
}