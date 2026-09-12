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
    final point = Offset(
      (local.dx - destination.left) / scale,
      (local.dy - destination.top) / scale,
    );
    return Offset(
      point.dx.clamp(0, math.max(0, desktop.width - 1)),
      point.dy.clamp(0, math.max(0, desktop.height - 1)),
    );
  }

  Offset toLocal(Offset remote) => Offset(
    destination.left + remote.dx * scale,
    destination.top + remote.dy * scale,
  );
}
