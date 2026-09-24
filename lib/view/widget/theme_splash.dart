import 'dart:async';

import 'package:flutter/material.dart';

import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/view/widget/package_image.dart';

/// Covers the app with the active package's splash while it takes its first
/// frames, then fades out.
///
/// The package is read once, when this is built: the app's own starting state
/// is decided before `runApp`, so that reading is the theme the launch was
/// under, and choosing a preset later does not play the splash again.
///
/// What a native launch screen shows is the platform's, not a theme's — an
/// Android window background or an iOS storyboard is decided when the app is
/// built and can only change with the system's brightness. This is the half
/// that can follow a theme, and it starts as soon as Dart does.
class ThemeSplashGate extends StatefulWidget {
  const ThemeSplashGate({required this.child, super.key});

  final Widget child;

  static const _logoSize = 96.0;

  /// Which is all the splash does after its duration: it has already covered
  /// the launch, so the rest is getting out of the way.
  static const fadeDuration = Duration(milliseconds: 250);

  @override
  State<ThemeSplashGate> createState() => _ThemeSplashGateState();
}

class _ThemeSplashGateState extends State<ThemeSplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: ThemeSplashGate.fadeDuration,
    value: 1,
  );
  ThemePackage? _package;
  ThemeSplash? _splash;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final package = ThemePackages.activeTheme;
    final splash = package?.splash;
    if (splash == null) return;
    _package = package;
    _splash = splash;
    _timer = Timer(Duration(milliseconds: splash.duration), () {
      if (!mounted) return;
      _fade.reverse().whenComplete(() {
        if (mounted) setState(() => _splash = null);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splash = _splash;
    if (splash == null) return widget.child;
    final logo = _package?.splashLogoPath;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          // Touches land on the splash rather than on whatever is behind it,
          // which the user cannot see yet.
          child: AbsorbPointer(
            child: FadeTransition(
              opacity: _fade,
              child: ColoredBox(
                color: splash.resolve(Theme.of(context).colorScheme),
                child: logo == null
                    ? const SizedBox.shrink()
                    : Center(
                        child: PackageImage(
                          path: logo,
                          size: ThemeSplashGate._logoSize,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
