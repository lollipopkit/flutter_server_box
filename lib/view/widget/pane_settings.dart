import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/store.dart';

/// The two settings that govern every list-beside-content layout in the app:
/// whether to allow a second column at all, and how wide the list is.
///
/// [SbPaneList] binds them to [AdaptiveSideList]; [PaneSettings.listen] binds
/// them to anything else — the server list, whose detail is a route and so
/// uses [AdaptivePanes] instead.
///
/// The server list, the terminal and file rails and the agent's history all
/// want exactly this, and each used to spell it out — which is three places to
/// change a default in and two places to forget.
///
/// Both settings are listened to, not read once. They are changed elsewhere —
/// the width by dragging the divider on another tab, the switch on the
/// settings page — and these pages are all kept alive behind each other, so a
/// value read at build time is a value from whenever that page was last on
/// screen.
abstract final class PaneSettings {
  /// Both settings, listened to rather than read.
  ///
  /// They are changed elsewhere — the width by dragging a divider on another
  /// tab, the switch on the settings page — and every page that shows one of
  /// these columns is kept alive behind the others, so a value read at build
  /// time is a value from whenever that page was last on screen.
  static Widget listen(
    Widget Function(bool single, double width) builder,
  ) {
    return Stores.setting.forceSinglePane.listenable().listenVal((single) {
      return Stores.setting.paneListWidth.listenable().listenVal(
        (width) => builder(single, width),
      );
    });
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
      (single, width) => AdaptiveSideList(
        enabled: !single && hasContent,
        sideWidth: width,
        onSideWidthChanged: PaneSettings.saveWidth,
        sideBuilder: sideBuilder,
        builder: builder,
      ),
    );
  }
}
