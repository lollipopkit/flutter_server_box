import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum RemoteDesktopScaleMode { fit, actual, custom }

/// Maps points between the Flutter viewport and remote desktop pixels.
class RemoteDesktopViewportTransform {
  const RemoteDesktopViewportTransform({
    required this.viewport,
    required this.desktop,
    required this.destination,
    required this.scale,
  });

  final Size viewport;
  final Size desktop;
  final Rect destination;
  final double scale;

  static RemoteDesktopViewportTransform calculate({
    required Size viewport,
    required Size desktop,
    required RemoteDesktopScaleMode mode,
    double customScale = 1,
    Offset pan = Offset.zero,
  }) {
    if (viewport.isEmpty || desktop.isEmpty) {
      return RemoteDesktopViewportTransform(
        viewport: viewport,
        desktop: desktop,
        destination: Rect.zero,
        scale: 1,
      );
    }
    final fit = math.min(
      viewport.width / desktop.width,
      viewport.height / desktop.height,
    );
    final scale = switch (mode) {
      RemoteDesktopScaleMode.fit => fit,
      RemoteDesktopScaleMode.actual => 1.0,
      RemoteDesktopScaleMode.custom => customScale.clamp(0.1, 8.0),
    };
    final size = Size(desktop.width * scale, desktop.height * scale);
    final origin = Offset(
      (viewport.width - size.width) / 2,
      (viewport.height - size.height) / 2,
    ) + pan;
    return RemoteDesktopViewportTransform(
      viewport: viewport,
      desktop: desktop,
      destination: origin & size,
      scale: scale,
    );
  }

  Offset? toRemote(Offset local, {bool clamp = false}) {
    if (destination.isEmpty) return null;
    if (!clamp && !destination.contains(local)) return null;
    return clampToDesktop(
      Offset(
        (local.dx - destination.left) / scale,
        (local.dy - destination.top) / scale,
      ),
    );
  }

  /// [remote] kept on the desktop, whose last pixel is one short of its size.
  Offset clampToDesktop(Offset remote) => Offset(
    remote.dx.clamp(0, math.max(0, desktop.width - 1)),
    remote.dy.clamp(0, math.max(0, desktop.height - 1)),
  );

  Offset toLocal(Offset remote) => Offset(
    destination.left + remote.dx * scale,
    destination.top + remote.dy * scale,
  );
}

/// How far to move the picture up while a soft keyboard covers the bottom of
/// the canvas: enough that [pointer] — where the user is typing — stays
/// [margin] above the keyboard, and no more than the keyboard covers.
///
/// [atRest] is laid out at the size the canvas had before the keyboard, so
/// the picture keeps its scale instead of shrinking into the strip above it
/// (#1639); [visibleHeight] is what is left of that above the keyboard.
double remoteDesktopKeyboardShift(
  RemoteDesktopViewportTransform atRest, {
  required double visibleHeight,
  required Offset? pointer,
  double margin = 48,
}) {
  final covered = atRest.viewport.height - visibleHeight;
  if (pointer == null || covered <= 0) return 0;
  final y = atRest.toLocal(pointer).dy;
  return (y - (visibleHeight - margin)).clamp(0, covered).toDouble();
}
