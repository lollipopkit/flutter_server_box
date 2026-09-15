import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

typedef RemoteDesktopImageDecoder = Future<ui.Image> Function(
  Uint8List pixels,
  int width,
  int height,
  ui.PixelFormat format,
);

/// Decodes one frame at a time and drops stale queued frames.
class RemoteDesktopFrameDecoder extends ChangeNotifier {
  RemoteDesktopFrameDecoder({RemoteDesktopImageDecoder? decode})
    : _decode = decode ?? decodeRemoteDesktopImage;

  final RemoteDesktopImageDecoder _decode;
  _PendingFrame? _pending;
  bool _decoding = false;
  bool _disposed = false;
  int _generation = 0;
  ui.Image? _image;
  BigInt _sequence = BigInt.from(-1);

  ui.Image? get image => _image;
  BigInt get sequence => _sequence;

  /// Drops all pending and decoded state before a different session is shown.
  void reset() {
    if (_disposed) return;
    _generation++;
    _pending = null;
    _image?.dispose();
    _image = null;
    _sequence = BigInt.from(-1);
    notifyListeners();
  }

  void submit({
    required Uint8List pixels,
    required int width,
    required int height,
    required BigInt sequence,
    ui.PixelFormat format = ui.PixelFormat.bgra8888,
  }) {
    if (_disposed || width <= 0 || height <= 0 || sequence <= _sequence) {
      return;
    }
    _pending = _PendingFrame(pixels, width, height, sequence, format);
    if (!_decoding) unawaited(_drain());
  }

  Future<void> _drain() async {
    _decoding = true;
    var generation = _generation;
    while (!_disposed) {
      if (generation != _generation) generation = _generation;
      final frame = _pending;
      if (frame == null) break;
      _pending = null;
      ui.Image decoded;
      try {
        decoded = await _decode(
          frame.pixels,
          frame.width,
          frame.height,
          frame.format,
        );
      } catch (_) {
        continue;
      }
      if (_disposed || _pending != null) {
        decoded.dispose();
        continue;
      }
      if (generation != _generation) {
        generation = _generation;
        decoded.dispose();
        continue;
      }
      final old = _image;
      _image = decoded;
      _sequence = frame.sequence;
      old?.dispose();
      notifyListeners();
    }
    _decoding = false;
    if (!_disposed && _pending != null) unawaited(_drain());
  }

  @override
  void dispose() {
    _disposed = true;
    _pending = null;
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}

Future<ui.Image> decodeRemoteDesktopImage(
  Uint8List pixels,
  int width,
  int height,
  ui.PixelFormat format,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: format,
  );
  final codec = await descriptor.instantiateCodec();
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

class _PendingFrame {
  const _PendingFrame(
    this.pixels,
    this.width,
    this.height,
    this.sequence,
    this.format,
  );

  final Uint8List pixels;
  final int width;
  final int height;
  final BigInt sequence;
  final ui.PixelFormat format;
}
