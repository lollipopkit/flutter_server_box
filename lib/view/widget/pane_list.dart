import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/store.dart';

/// A list column beside what it opens, bound to the two settings that govern
/// every one of them: whether to allow a second column at all, and how wide
/// the list is.
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
    return Stores.setting.forceSinglePane.listenable().listenVal((single) {
      return Stores.setting.paneListWidth.listenable().listenVal((width) {
        return AdaptiveSideList(
          enabled: !single && hasContent,
          sideWidth: width,
          onSideWidthChanged: Stores.setting.paneListWidth.put,
          sideBuilder: sideBuilder,
          builder: builder,
        );
      });
    });
  }
}
