import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/store.dart';

/// How wide the list is in every list-beside-content layout in the app.
///
/// [SbPaneList] binds it to [AdaptivePanes.surface]; [PaneSettings.listen]
/// binds it to anything else — the server list, whose detail is a route and
/// so uses [AdaptivePanes.detail] instead.
///
/// The server list, the terminal and file rails and the agent's history all
/// want exactly this, and each used to spell it out — which is three places to
/// change a default in and two places to forget.
///
/// There used to be a second setting here, for forcing one column however wide
/// the window was. The layouts already collapse to one column when there is no
/// room for two, so it only ever answered a question nobody was asking on a
/// window narrow enough for it to matter.
abstract final class PaneSettings {
  /// Listened to rather than read once.
  ///
  /// It is changed elsewhere — by dragging a divider on another tab — and
  /// every page that shows one of these columns is kept alive behind the
  /// others, so a value read at build time is a value from whenever that page
  /// was last on screen.
  static Widget listen(Widget Function(double width) builder) {
    return Stores.setting.paneListWidth.listenable().listenVal(builder);
  }

  /// Both numbers at once, for a layout that can fold as well as resize.
  ///
  /// Listened to for the same reason as the width: the other tabs holding one
  /// of these columns are alive behind this one and have to hear that it
  /// folded, or each would keep whatever it was built with.
  static Widget listenAll(Widget Function(double width, bool collapsed) builder) {
    return Stores.setting.paneListWidth.listenable().listenVal(
      (width) => Stores.setting.paneListCollapsed.listenable().listenVal(
        (collapsed) => builder(width, collapsed),
      ),
    );
  }

  /// Where a drag ends. Writing it notifies every listener above.
  static void saveWidth(double width) =>
      Stores.setting.paneListWidth.put(width);

  static void saveCollapsed(bool collapsed) =>
      Stores.setting.paneListCollapsed.put(collapsed);
}

class SbPaneList extends StatelessWidget {
  const SbPaneList({
    super.key,
    required this.sideBuilder,
    required this.builder,
    this.hasContent = true,
  });

  /// The list.
  final WidgetBuilder sideBuilder;

  /// The surface it opens things on, told whether the list is beside it.
  final Widget Function(BuildContext context, bool split) builder;

  /// Whether there is anything open for the list to sit beside.
  ///
  /// False folds the column away: reserving one next to an empty surface is
  /// width spent on nothing, and the controls that would have been in it are
  /// still reachable from the page itself.
  final bool hasContent;

  @override
  Widget build(BuildContext context) {
    return PaneSettings.listenAll(
      (width, collapsed) => AdaptivePanes.surface(
        enabled: hasContent,
        listWidth: width,
        onListWidthChanged: PaneSettings.saveWidth,
        collapsed: collapsed,
        onCollapsedChanged: PaneSettings.saveCollapsed,
        // `fold` and `open` are what fl_lib already has for this pair. Neither
        // is a word chosen for a sidebar, and adding two strings in twelve
        // languages to say the same thing more exactly is not worth it.
        collapseTooltip: libL10n.fold,
        expandTooltip: libL10n.open,
        listBuilder: (ctx, _) => sideBuilder(ctx),
        surfaceBuilder: builder,
      ),
    );
  }
}
