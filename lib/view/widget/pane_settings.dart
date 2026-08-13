import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/store.dart';

/// How wide the list is in every list-beside-content layout in the app.
///
/// [SbPaneList] binds it to [AdaptiveSideList]; [PaneSettings.listen] binds it
/// to anything else — the server list, whose detail is a route and so uses
/// [AdaptivePanes] instead.
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

  /// Where a drag ends. Writing it notifies every listener above.
  static void saveWidth(double width) =>
      Stores.setting.paneListWidth.put(width);
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
    return PaneSettings.listen(
      (width) => AdaptiveSideList(
        enabled: hasContent,
        sideWidth: width,
        onSideWidthChanged: PaneSettings.saveWidth,
        sideBuilder: sideBuilder,
        builder: builder,
      ),
    );
  }
}
