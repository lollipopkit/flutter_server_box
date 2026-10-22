import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/view/widget/group_title.dart';

/// How wide a section's content grows: past it a row is too long to read.
const monitorContentWidth = 980.0;

/// The space either side of a section's content in [width]: centred, and
/// never under the window's own margin. The head uses it too, so its title
/// starts where the content does.
double monitorSide(double width) => math.max(13.0, (width - monitorContentWidth) / 2);

/// The head of a section beside the rail: what it is and for which servers,
/// with its actions at the far end.
class MonitorPaneHeader extends StatelessWidget implements PreferredSizeWidget {
  const MonitorPaneHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
    this.search,
    this.searchHint,
  });

  final String title;
  final String subtitle;
  final List<BarAction> actions;
  final InlineSearchController? search;
  final String? searchHint;

  static const height = 64.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: UIs.text12Grey),
            ],
          ),
        ),
        for (final action in actions) action.button(),
      ],
    );
    return WindowControlsInset(
      safeArea: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, cons) {
            // The title over the cards' edge; the actions a little past it,
            // where a button's own padding puts its glyph in line.
            final side = monitorSide(cons.maxWidth);
            return Padding(
              padding: EdgeInsets.fromLTRB(side + 5, 7, side - 5, 3),
              child: switch (search) {
                final search? => InlineSearchBar(controller: search, hint: searchHint, child: row),
                null => row,
              },
            );
          },
        ),
      ),
    );
  }
}

/// A section's scrolling content: centred, and no wider than
/// [monitorContentWidth].
class MonitorList extends StatelessWidget {
  const MonitorList({super.key, required this.children, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = LayoutBuilder(
      builder: (context, cons) {
        final side = monitorSide(cons.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(side, 3, side, 27),
          children: children,
        );
      },
    );
    return switch (onRefresh) {
      final refresh? => RefreshIndicator(onRefresh: refresh, child: list),
      null => list,
    };
  }
}

/// A named group of rows in one card, as the settings and the server editor
/// draw theirs: [empty] in their place when there are none.
class MonitorGroup extends StatelessWidget {
  const MonitorGroup({
    super.key,
    required this.title,
    required this.children,
    this.right,
    this.empty,
    this.footer,
  });

  final String title;
  final List<Widget> children;

  /// At the end of the heading's rule: a count, a state.
  final String? right;

  /// What the card says with no rows.
  final String? empty;

  /// Under the card: what the group does and does not do.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const Divider(height: 1, indent: 17, endIndent: 17),
        children[i],
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(title, right: right),
        if (rows.isNotEmpty)
          CardX(child: Column(children: rows))
        else if (empty case final empty?)
          CardX(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
              child: Text(empty, style: UIs.textGrey),
            ),
          ),
        if (footer case final footer?)
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 7, 5, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: UIs.textGrey.color),
                UIs.width7,
                Expanded(child: Text(footer, style: UIs.text12Grey)),
              ],
            ),
          ),
      ],
    );
  }
}

/// One row of a [MonitorGroup]: a mark, what it is, and what can be done.
class MonitorRow extends StatelessWidget {
  const MonitorRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.bold = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// For a row not seen yet.
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 17, right: 9),
      minLeadingWidth: 23,
      leading: SizedBox(width: 23, child: Center(child: leading)),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w600 : FontWeight.w500),
      ),
      subtitle: subtitle == null || subtitle!.isEmpty
          ? null
          : Text(subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis, style: UIs.text12Grey),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// A small coloured dot: a state at a glance.
class MonitorDot extends StatelessWidget {
  const MonitorDot(this.color, {super.key, this.tooltip, this.size = 9});

  final Color color;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return tooltip == null ? dot : Tooltip(message: tooltip!, child: dot);
  }
}

/// A short tag, tinted when it asks for attention.
class MonitorTag extends StatelessWidget {
  const MonitorTag(this.text, {super.key, this.color, this.icon, this.onTap});

  final String text;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color == null ? scheme.surfaceContainerHighest : fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
        ],
      ),
    );
    if (onTap == null) return tag;
    return InkWell(borderRadius: BorderRadius.circular(7), onTap: onTap, child: tag);
  }
}

/// A destructive action at the end of a row, with what it does as its
/// tooltip.
class MonitorRowAction extends StatelessWidget {
  const MonitorRowAction({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 19),
      tooltip: tooltip,
      color: Theme.of(context).colorScheme.error,
      onPressed: onPressed,
    );
  }
}

/// Whether the agent answers, as a colour.
Color monitorConnColor(ServerConn conn, ColorScheme scheme) => switch (conn) {
  ServerConn.failed => scheme.error,
  ServerConn.connected || ServerConn.loading || ServerConn.finished => Colors.green,
  _ => scheme.outline,
};
