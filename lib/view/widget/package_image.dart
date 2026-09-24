import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One file out of an installed theme package, drawn tinted.
///
/// A package may carry either format for anything it draws — a PNG is decoded
/// by the engine, an SVG by `flutter_svg` — so the file's extension decides the
/// widget, and [color] tints both the same way. `srcIn` is what makes a themed
/// icon follow the ambient icon color; an SVG's own `currentColor` follows
/// [color] too, and falls back to the surface's foreground when none is given.
class PackageImage extends StatelessWidget {
  const PackageImage({
    required this.path,
    this.size,
    this.color,
    this.fit = BoxFit.contain,
    this.fallback,
    super.key,
  });

  final String path;
  final double? size;
  final Color? color;
  final BoxFit fit;

  /// Drawn when there is nothing to draw, so an icon can show its glyph.
  final Widget? fallback;

  bool get _vector => path.endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) return fallback ?? const SizedBox.shrink();
    if (_vector) {
      return SvgPicture.file(
        file,
        width: size,
        height: size,
        fit: fit,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
        theme: SvgTheme(
          currentColor: color ?? Theme.of(context).colorScheme.onSurface,
        ),
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      );
    }
    return Image.file(
      file,
      width: size,
      height: size,
      fit: fit,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
    );
  }
}
