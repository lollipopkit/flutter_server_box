import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/motion.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/data/res/store.dart';

/// The image or gradient the app stands on.
///
/// Drawn once behind the whole app — the pages over it are
/// [Colors.transparent] on purpose — and again inside a page while that page
/// is arriving or leaving, which is what [AppPageTransitions] is for.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.visible = true});

  final Widget child;

  /// Whether the background is to be drawn here.
  ///
  /// Always for the copy behind the app. Inside a page, only while the page is
  /// moving: at rest the page is transparent and the copy behind the app is
  /// already what is being looked at, and a second one drawn in the page's own
  /// box is not the same picture — the background is `cover`-fitted, so a page
  /// covering a pane gets the pane's crop of it rather than the window's.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final preview = ThemePackages.preview.value;
    final style =
        preview?.backgroundStyle ?? Stores.setting.appBackgroundStyle.fetch();
    final path = preview != null
        ? preview.backgroundPath ?? ''
        : Stores.setting.appBackgroundPath.fetch();
    if (style == BackgroundStyle.none ||
        (style == BackgroundStyle.image && path.isEmpty)) {
      return child;
    }
    // A `Stack` either way, and the background switched through an `Opacity`
    // rather than taken out of it: the child is a whole page, and a page
    // rebuilt from a different parent loses what it was holding — a scroll
    // position, a field being typed in — every time a transition starts.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: visible ? 1 : 0,
            child: _layer(context, style, path),
          ),
        ),
        child,
      ],
    );
  }

  Widget _layer(BuildContext context, BackgroundStyle style, String path) {
    if (ThemePackages.preview.value case final preview?) {
      return BackgroundLayer.of(preview) ?? const SizedBox.shrink();
    }
    final settings = Stores.setting;
    return BackgroundLayer(
      style: style,
      path: path,
      opacity: settings.appBackgroundOpacity.fetch(),
      blur: settings.appBackgroundBlur.fetch(),
      tile: settings.appBackgroundTile.fetch(),
    );
  }
}

/// One background as the app draws it: the gradient from the ambient scheme,
/// or the image faint over the surface, once and cover-fitted or repeated
/// every [tile] logical pixels. What [AppBackground] draws behind the app, and
/// what the theme store draws behind a preview.
class BackgroundLayer extends StatelessWidget {
  const BackgroundLayer({
    super.key,
    required this.style,
    required this.path,
    required this.opacity,
    required this.blur,
    this.tile = 0,
  });

  final BackgroundStyle style;
  final String path;
  final double opacity;
  final double blur;
  final double tile;

  /// [package]'s background, or null for a package without one.
  static BackgroundLayer? of(ThemePackage package) {
    final path = package.backgroundPath ?? '';
    if (package.backgroundStyle == BackgroundStyle.none ||
        (package.backgroundStyle == BackgroundStyle.image && path.isEmpty)) {
      return null;
    }
    return BackgroundLayer(
      style: package.backgroundStyle,
      path: path,
      opacity: package.opacity,
      blur: package.blur,
      tile: package.backgroundTile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (style == BackgroundStyle.gradient) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(scheme.surface, scheme.primary, 0.22)!,
              scheme.surface,
              Color.lerp(scheme.surface, scheme.primary, 0.12)!,
            ],
          ),
        ),
      );
    }
    final blur = this.blur.clamp(0.0, 30.0);
    final Widget image;
    if (tile > 0) {
      // A pattern: decoded at one repeat's width in physical pixels and drawn
      // at that size from the top left, so it keeps its size on any window
      // rather than growing with it the way a `cover`-fitted picture does.
      final ratio = MediaQuery.devicePixelRatioOf(context);
      image = Image(
        image: ResizeImage(
          FileImage(File(path), scale: ratio),
          width: (tile * ratio).round(),
          allowUpscaling: true,
        ),
        fit: BoxFit.none,
        alignment: Alignment.topLeft,
        repeat: ImageRepeat.repeat,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else {
      image = Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 4096,
        cacheHeight: 4096,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    // The image is faint and the colour under it is not: what makes a page
    // opaque enough to stand over the one below is this box, not the image.
    return ColoredBox(
      color: scheme.surface,
      child: Opacity(
        opacity: opacity.clamp(0.0, 0.6),
        child: blur == 0
            ? image
            : ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: blur,
                  sigmaY: blur,
                  tileMode: ui.TileMode.clamp,
                ),
                child: image,
              ),
      ),
    );
  }
}

/// Every platform's own page transition, with the page given the app's
/// background for as long as it is moving.
///
/// A page here is transparent, so two of them over each other during a
/// transition are two sets of rows drawn on the same pixels — the arriving
/// page's over the leaving page's, for the length of the animation. Handing
/// each page the background makes it the complete surface it looks like at
/// rest, and the arriving page covers the one below as it comes in.
///
/// A page at rest gives it back: the background is drawn once behind the whole
/// app, and drawing it again in every page's own box would cost a layer per
/// route to show the same thing.
///
/// And either kind fades in place of moving when the app moves less — see
/// [_MotionAware].
abstract final class AppPageTransitions {
  /// For a theme whose pages are opaque: the platform's own transitions.
  static final plain = _wrap((builder) => _MotionAware(builder));

  /// For a theme whose pages are transparent.
  static final backgrounded = _wrap(
    (builder) => _Backgrounded(_MotionAware(builder)),
  );

  static PageTransitionsTheme _wrap(
    PageTransitionsBuilder Function(PageTransitionsBuilder) wrap,
  ) => PageTransitionsTheme(
    builders: {
      for (final MapEntry(key: platform, value: builder)
          in const PageTransitionsTheme().builders.entries)
        platform: wrap(builder),
    },
  );
}

/// The platform's transition, or a fade in its place when the app moves less.
///
/// The platform's builder is still the one that builds the page, only held
/// still: it is also what carries the back gesture, and a swipe back is how a
/// page is left on iOS whether or not it slides. Its gesture drives the route's
/// own animation, which is what the fade reads, so the page fades under the
/// finger instead of following it.
final class _MotionAware extends PageTransitionsBuilder {
  const _MotionAware(this._inner);

  final PageTransitionsBuilder _inner;

  @override
  Duration get transitionDuration => _inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _inner.delegatedTransition == null ? null : _delegated;

  /// The page below moving aside for the one arriving, which it does not when
  /// the app moves less. A tear-off, so every read of [delegatedTransition]
  /// is the same value — the navigator compares two routes' by equality.
  Widget? _delegated(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (context.reduceMotion) return child;
    return _inner.delegatedTransition!(
      context,
      animation,
      secondaryAnimation,
      allowSnapshotting,
      child,
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!context.reduceMotion) {
      return _inner.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FadeTransition(
      opacity: animation,
      child: _inner.buildTransitions(
        route,
        context,
        kAlwaysCompleteAnimation,
        kAlwaysDismissedAnimation,
        child,
      ),
    );
  }
}

/// Delegates to the platform's own transition, with the page wrapped.
final class _Backgrounded extends PageTransitionsBuilder {
  const _Backgrounded(this._inner);

  final PageTransitionsBuilder _inner;

  @override
  Duration get transitionDuration => _inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      AnimatedBuilder(
        // This route's own animation, not the one above it: a page is given
        // the background while *it* is moving. A page under an arriving one
        // gives it back, and is meant to be seen there — it is what the
        // arriving page has not covered yet.
        animation: animation,
        // Passed through, not built here: this is rebuilt every frame of the
        // transition and the page under it is not.
        child: child,
        builder: (context, child) => AppBackground(
          // Below 1 rather than "animating": a back gesture drives the route
          // by hand, and a controller being dragged keeps whatever status it
          // had, so the truth is where the value is, not what the status says.
          //
          // TODO(flicker): dropping the copy on the last frame of the
          // transition is visible on a device. The copy is fitted to the page's
          // own box, which is still moving when it is dropped, so it does not
          // land on the same pixels as the background behind the app that takes
          // over from it.
          visible: animation.value < 1,
          child: child!,
        ),
      ),
    );
  }
}
