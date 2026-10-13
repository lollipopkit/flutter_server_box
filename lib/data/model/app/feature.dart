import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// A feature that is shipped while still being finished, and so may carry a
/// mark saying so.
///
/// The one place that says which features are in beta. Every tab, settings
/// page, card, function row and page that reaches one asks it — through
/// [beta] or [mark] — rather than drawing a `BetaTag` of its own, so a
/// feature leaving beta is one line here rather than a hunt for every mark.
enum Feature {
  remoteDesktop,
  agent,
  benchmark,
  virt,
  workspace,
  webApps,
  bmc,
  wakeOnLan,
  portForward,
  linux;

  /// Whether the feature is still in beta.
  bool get beta => switch (this) {
    remoteDesktop ||
    agent ||
    benchmark ||
    virt ||
    workspace ||
    webApps ||
    bmc ||
    wakeOnLan ||
    portForward ||
    linux => true,
  };

  /// The `BetaTag` for this feature, or null once it is out of beta.
  ///
  /// [height], [tip] and [opacity] are the caller's: how big the mark is and
  /// whether it explains itself depend on where it is drawn, not on the
  /// feature.
  Widget? mark({
    double height = BetaTag.title,
    String? tip,
    double opacity = 1,
  }) => beta ? BetaTag(height: height, tip: tip, opacity: opacity) : null;
}
