import 'package:flutter/widgets.dart';
import 'package:server_box/data/res/store.dart';

/// How big the text of the server pages is: what the system asks for, times
/// this app's own setting for these pages.
///
/// Times, not instead of. The setting used to *replace* the system's scale, so
/// on a phone with its text size turned down to 0.82 every other page was
/// drawn at 0.82 and the server list at 1 — a fifth larger than the bar over
/// it and the navigation under it, for a reader who had asked for smaller. It
/// went unnoticed for as long as it did because a desktop has no such setting
/// and the two agree there.
///
/// Around a whole page rather than given to a [Text]: a scaler handed to one
/// text replaces the ambient one for that text only, which is how a page ends
/// up with three sizes of the same style.
///
/// Not to be nested. The detail page is inside the tab's when it opens in
/// place and brings its own when it is pushed — see `_hosted`.
class ServerTextScale extends StatelessWidget {
  const ServerTextScale({super.key, required this.child});

  final Widget child;

  /// The same scale, for something that has to decide by it rather than draw
  /// with it — which shape a list takes, above the page that is scaled.
  static TextScaler of(BuildContext context) => _ServerTextScaler(
    MediaQuery.textScalerOf(context),
    Stores.setting.textFactor.fetch(),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Stores.setting.textFactor.listenable(),
      builder: (context, factor, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: _ServerTextScaler(
            MediaQuery.textScalerOf(context),
            factor,
          ),
        ),
        child: child!,
      ),
      child: child,
    );
  }
}

/// [system] and then [factor].
///
/// A class rather than `TextScaler.linear(system.scale(1) * factor)`: what the
/// system asks for is not a number everywhere. Android scales small text more
/// than large, and flattening that to one factor would undo it on exactly the
/// pages that have the most small text.
final class _ServerTextScaler extends TextScaler {
  const _ServerTextScaler(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  @override
  // The framework's own composing scaler answers this the same way; it is
  // abstract, so it has to be answered.
  // ignore: deprecated_member_use
  double get textScaleFactor => system.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _ServerTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}
