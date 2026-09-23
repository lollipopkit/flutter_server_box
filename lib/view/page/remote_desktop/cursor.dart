part of 'viewer.dart';

/// The remote pointer, drawn here.
///
/// Both protocols are asked for the pointer separately from the picture — RDP
/// with `with_server_pointer`, VNC with the cursor pseudo-encoding — so the
/// server never paints it into a frame, and until this was drawn nobody did.
/// On a touch screen that left no pointer at all: the touchpad moved something
/// invisible. With a mouse the system's own pointer is on screen, so nothing
/// is drawn over it.
///
/// [_pointer] is where this app last put the pointer, in desktop pixels, or
/// where the server says it moved it. Desktop pixels rather than a point on
/// screen, so a zoom or a pan moves the picture and the pointer with it.
extension _CursorX on _RemoteDesktopViewerState {
  bool get _drawsCursor => switch (_inputKind) {
    null => _touchScreen,
    ui.PointerDeviceKind.mouse || ui.PointerDeviceKind.trackpad => false,
    _ => true,
  };

  void _noteInputKind(ui.PointerDeviceKind kind) {
    if (_inputKind == kind) return;
    final drew = _drawsCursor;
    _inputKind = kind;
    if (_drawsCursor != drew) _update(() {});
  }

  /// The pointer, or the middle of the desktop before anything has put it
  /// anywhere — where a touchpad pointer starts, and where it is drawn.
  Offset? _pointerOr(RemoteDesktopViewportTransform transform) =>
      _pointer.value ??
      transform.toRemote(transform.destination.center, clamp: true);

  /// Gives the pointer somewhere to be drawn before the first touch.
  void _placePointer(RemoteDesktopViewportTransform transform) {
    if (_pointer.value != null || transform.destination.isEmpty) return;
    _pointer.value = _pointerOr(transform);
  }

  void _resetCursor() {
    _pointer.value = null;
    _serverCursorAt = null;
    _cursorRgba = null;
    _cursorImage?.dispose();
    _cursorImage = null;
  }

  /// Follows what the server says about the pointer: a move it made itself,
  /// and the picture to draw.
  void _syncCursor(RemoteDesktopSessionView session) {
    final cursor = session.cursor;
    final at = (cursor.x, cursor.y);
    // Only a change. The first value is the model's default of 0,0, and a
    // repeat of an old position would pull the pointer back from wherever
    // this app has put it since.
    if (_serverCursorAt != null && _serverCursorAt != at) {
      _pointer.value = Offset(cursor.x.toDouble(), cursor.y.toDouble());
    }
    _serverCursorAt = at;

    final rgba = cursor.useDefault ? null : cursor.rgba;
    if (identical(rgba, _cursorRgba)) return;
    _cursorRgba = rgba;
    final width = cursor.width;
    final height = cursor.height;
    if (rgba == null ||
        width <= 0 ||
        height <= 0 ||
        rgba.length < width * height * 4) {
      _cursorImage?.dispose();
      _cursorImage = null;
      return;
    }
    // Straight alpha from both sources: IronRDP's accelerated target and
    // vnc-rs's mask-derived alpha.
    ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, (
      image,
    ) {
      // A newer picture may have arrived while this one decoded.
      if (!mounted || !identical(_cursorRgba, rgba)) {
        image.dispose();
        return;
      }
      _update(() {
        _cursorImage?.dispose();
        _cursorImage = image;
      });
    });
  }
}

final class _CursorPainter extends CustomPainter {
  _CursorPainter({
    required this.pointer,
    required this.transform,
    required this.cursor,
    required this.image,
  }) : super(repaint: pointer);

  final ValueNotifier<Offset?> pointer;
  final RemoteDesktopViewportTransform transform;
  final RemoteDesktopCursor cursor;
  final ui.Image? image;

  /// The smallest the remote pointer is drawn, as a share of its own pixels.
  /// A phone fits a desktop at a third of its size or less, which made a
  /// 32-pixel pointer about ten points tall — too small to aim with.
  static const _minScale = 0.75;

  @override
  void paint(Canvas canvas, Size size) {
    final at = pointer.value;
    if (at == null || !cursor.visible) return;
    final tip = transform.toLocal(at);
    final image = this.image;
    if (image == null) {
      _paintArrow(canvas, tip);
      return;
    }
    final scale = math.max(transform.scale, _minScale);
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        tip.dx - cursor.hotspotX * scale,
        tip.dy - cursor.hotspotY * scale,
        image.width * scale,
        image.height * scale,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// The pointer the desktop would draw by default, for before it has sent
  /// one of its own and for a server that says to use the default.
  static void _paintArrow(Canvas canvas, Offset tip) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 17)
      ..lineTo(4, 13)
      ..lineTo(7, 20)
      ..lineTo(10, 19)
      ..lineTo(7, 12)
      ..lineTo(12, 12)
      ..close();
    final shifted = path.shift(tip);
    canvas
      ..drawPath(shifted, Paint()..color = Colors.white)
      ..drawPath(
        shifted,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) =>
      !identical(oldDelegate.cursor, cursor) ||
      !identical(oldDelegate.image, image) ||
      oldDelegate.pointer != pointer ||
      oldDelegate.transform.destination != transform.destination ||
      oldDelegate.transform.scale != transform.scale;
}
