import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/view/widget/dist_icon.dart';

/// The size of a mark in a side rail — the row's text, as `SideBarTile`
/// draws its own icons.
const kSideMarkSize = 17.0;

/// How a row in a side rail says what is going on with it: what goes before
/// its name, and the bar on its edge.
typedef RailRow = ({Widget? leading, bool live, Color? liveColor});

/// The one way every rail of servers and sessions — the server, terminal,
/// file and remote desktop tabs' — shows a row's state.
///
/// Where the server has a mark (`showDistMark`), the state is a dot on the
/// mark's corner, and the edge has no bar. Where it has none — marks off, or
/// a session on this device — there is nothing before the name, and the state
/// is the bar's colour.
///
/// [live] is a session behind the row, drawn with the ordinary colours —
/// accent when [selected], neutral otherwise — unless [color] says more. A row
/// with neither shows no state at all. [badge] stands in for the dot when the
/// caller has one that keeps itself up to date.
RailRow railRow({
  required String? serverId,
  bool live = false,
  Color? color,
  bool selected = false,
  Widget? badge,
}) {
  final mark = serverId == null
      ? null
      : distIcon(serverId, size: kSideMarkSize);
  final stated = live || color != null;
  if (mark == null) {
    return (leading: null, live: stated, liveColor: color);
  }
  return (
    leading: sideMark(
      mark: mark,
      badge:
          badge ??
          (stated ? SideMarkDot(color: color, selected: selected) : null),
    ),
    live: false,
    liveColor: null,
  );
}

/// A mark with a badge on its corner. The badge alone where there is no mark,
/// and nothing where there is neither.
Widget? sideMark({Widget? mark, Widget? badge}) {
  if (mark == null) return badge;
  if (badge == null) return mark;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Center(child: mark),
      Positioned(right: -2, bottom: -2, child: badge),
    ],
  );
}

/// A badge for [sideMark]'s corner: a dot, ringed in the colour behind it so
/// it stays a dot over whatever part of the mark it lands on.
class SideMarkDot extends StatelessWidget {
  const SideMarkDot({
    super.key,
    this.color,
    this.selected = false,
    this.ringed = true,
  });

  /// Null for the ordinary colours, the live bar's — see [railRow].
  final Color? color;

  final bool selected;

  /// Off for a dot drawn on its own rather than on a mark.
  final bool ringed;

  static const size = 7.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? (selected ? scheme.primary : scheme.outlineVariant),
        shape: BoxShape.circle,
      ),
    );
    if (!ringed) return dot;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
      child: Padding(padding: const EdgeInsets.all(1.5), child: dot),
    );
  }
}

/// A server in a side rail — the terminal, file, server and remote desktop
/// tabs' lists of machines, which are one list wherever it is drawn.
///
/// [state] is shown as [railRow] shows any row's.
class ServerSideTile extends StatelessWidget {
  const ServerSideTile({
    super.key,
    required this.spi,
    this.state,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onMenu,
  });

  final Spi spi;

  /// What is going on with the server, as a colour — whether it answers, on
  /// the server tab. Null for a list that says nothing about it.
  final Color? state;

  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ContextMenuOpener? onMenu;

  @override
  Widget build(BuildContext context) {
    final row = railRow(serverId: spi.id, color: state, selected: selected);
    return SideBarTile(
      title: spi.name,
      leading: row.leading,
      live: row.live,
      liveColor: row.liveColor,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      onMenu: onMenu,
    );
  }
}
