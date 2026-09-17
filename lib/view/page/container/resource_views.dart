import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/menu/container.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/container/type.dart';

typedef ContainerItemTrailingBuilder = Widget Function(ContainerPs item);
typedef ContainerImageTrailingBuilder = Widget Function(ContainerImg image);
typedef ContainerQuickActionHandler =
    void Function(ContainerMenu action, ContainerPs item);

/// Displays the output of a running container command without allowing a long
/// log to consume the page's remaining layout space.
class ContainerRunLogView extends StatelessWidget {
  final String log;

  const ContainerRunLogView({required this.log, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: CircularProgressIndicator()),
          UIs.height13,
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              key: const ValueKey('container-run-log-scroll'),
              reverse: true,
              child: SizedBox(
                width: double.infinity,
                child: Text(log),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The container list: one card holding every compose project and every
/// container, as a table where the columns fit and as stacked rows where they
/// do not.
///
/// A table rather than cards because the question this page is opened with is
/// which container is busy, and that is answered by reading one column down
/// the page rather than by reading each container in turn.
class ContainerItemsView extends StatelessWidget {
  final List<ContainerPs> items;
  final ContainerItemTrailingBuilder trailingBuilder;
  final Widget? emptyState;

  /// Quick actions offered on a container that is not running, where its
  /// absent metrics leave the stacked row half empty. The table has no room
  /// for them and shows a dash per column instead.
  final ContainerQuickActionHandler? onQuickAction;

  const ContainerItemsView({
    required this.items,
    required this.trailingBuilder,
    this.emptyState,
    this.onQuickAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _ResourceList(
        children: [
          emptyState ??
              _EmptyResourceCard(
                icon: OctIcons.container,
                message: context.libL10n.empty,
              ),
        ],
      );
    }

    return _ResourceList(
      children: [
        _ContainerTable(
          groups: _groupContainers(items),
          showGroupHeaders: true,
          trailingBuilder: trailingBuilder,
          onQuickAction: onQuickAction,
        ),
      ],
    );
  }
}

/// The image list, laid out like the container table beside it: one card, a
/// column header where the columns fit, and no rule between rows.
///
/// Still built lazily rather than as one Column — an image store with two
/// hundred entries in it is normal, and only the rows on screen are worth
/// building.
///
/// The runtime summary above it belongs to the page rather than to this view:
/// it is the same header on every tab. See [ContainerRuntimeHeader].
class ContainerImagesView extends StatelessWidget {
  final List<ContainerImg> images;
  final ContainerImageTrailingBuilder trailingBuilder;

  const ContainerImagesView({
    required this.images,
    required this.trailingBuilder,
    super.key,
  });

  /// Below this the size and age columns leave the reference nothing, and the
  /// age folds under it instead.
  static const wideWidth = 620.0;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return _ResourceList(
        children: [
          _EmptyResourceCard(
            icon: MingCute.clapperboard_line,
            message: context.libL10n.empty,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = constraints.maxWidth >= wideWidth;
        final headerCount = wide ? 1 : 0;
        return _ResourceBuilderList(
          itemCount: images.length + headerCount,
          itemBuilder: (context, index) => _ImageRowCardSegment(
            index: index,
            itemCount: images.length + headerCount,
            child: wide && index == 0
                ? const _ImageColumnHeader()
                : _ContainerImageRow(
                    index: index - headerCount,
                    image: images[index - headerCount],
                    trailing: trailingBuilder(images[index - headerCount]),
                    wide: wide,
                  ),
          ),
        );
      },
    );
  }
}

/// Configures the scope of an image prune command.
class ContainerImagePruneOptionsView extends StatelessWidget {
  final int danglingCount;
  final int? unusedTaggedCount;
  final bool allUnused;
  final ValueChanged<bool> onAllUnusedChanged;
  final String commandPreview;

  const ContainerImagePruneOptionsView({
    required this.danglingCount,
    required this.unusedTaggedCount,
    required this.allUnused,
    required this.onAllUnusedChanged,
    required this.commandPreview,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _PruneCountBadge(
              key: const ValueKey('image-prune-dangling-count'),
              label: context.l10n.dangling,
              value: '$danglingCount',
            ),
            _PruneCountBadge(
              key: const ValueKey('image-prune-unused-tagged-count'),
              label: context.l10n.unusedTaggedImages,
              value: unusedTaggedCount?.toString() ?? libL10n.unknown,
            ),
          ],
        ),
        UIs.height7,
        _PruneScopeTile(
          key: const ValueKey('image-prune-dangling-option'),
          selected: !allUnused,
          title: context.l10n.pruneDanglingImages,
          subtitle: context.l10n.pruneDanglingImagesTip,
          onTap: () => onAllUnusedChanged(false),
        ),
        _PruneScopeTile(
          key: const ValueKey('image-prune-all-unused-option'),
          selected: allUnused,
          title: context.l10n.pruneUnusedImages,
          subtitle: context.l10n.pruneUnusedImagesTip,
          onTap: () => onAllUnusedChanged(true),
        ),
        UIs.height7,
        _PruneCommandPreview(command: commandPreview),
        UIs.height7,
        Text(
          context.l10n.pruneForceSshTip,
          style: UIs.text11.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Configures the optional scope of a system prune command.
class ContainerSystemPruneOptionsView extends StatelessWidget {
  final bool allUnusedImages;
  final bool includeVolumes;
  final ValueChanged<bool> onAllUnusedImagesChanged;
  final ValueChanged<bool> onIncludeVolumesChanged;
  final String commandPreview;

  const ContainerSystemPruneOptionsView({
    required this.allUnusedImages,
    required this.includeVolumes,
    required this.onAllUnusedImagesChanged,
    required this.onIncludeVolumesChanged,
    required this.commandPreview,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.dockerPruneTip, style: UIs.text13Grey),
        UIs.height7,
        SwitchListTile(
          key: const ValueKey('system-prune-all-images-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text('${context.l10n.pruneUnusedImages} (-a)'),
          subtitle: Text(context.l10n.pruneUnusedImagesTip),
          value: allUnusedImages,
          onChanged: onAllUnusedImagesChanged,
        ),
        SwitchListTile(
          key: const ValueKey('system-prune-volumes-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text('${context.l10n.pruneVolumes} (--volumes)'),
          subtitle: Text(context.l10n.includeUnusedVolumesTip),
          value: includeVolumes,
          onChanged: onIncludeVolumesChanged,
        ),
        UIs.height7,
        _PruneCommandPreview(command: commandPreview),
        UIs.height7,
        Text(context.l10n.pruneForceSshTip, style: UIs.text11Grey),
      ],
    );
  }
}

class _PruneScopeTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PruneScopeTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return ListTile(
      selected: selected,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _PruneCountBadge extends StatelessWidget {
  final String label;
  final String value;

  const _PruneCountBadge({
    required this.label,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: UIs.text11.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _PruneCommandPreview extends StatelessWidget {
  final String command;

  const _PruneCommandPreview({required this.command});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.pruneCommandPreview, style: UIs.text13Grey),
        UIs.height7,
        Container(
          key: const ValueKey('prune-command-preview'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            command,
            style: UIs.text13.copyWith(
              color: scheme.onSurface,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps the list off the window edges, and off a 27-inch monitor's middle.
double _gutter(double maxWidth) =>
    maxWidth > 1226 ? (maxWidth - 1200) / 2 : 13.0;

/// The same gutter as the lists below it, for chrome that has to line up with
/// them — the runtime summary and the tab selector.
class ContainerGutter extends StatelessWidget {
  final Widget child;

  const ContainerGutter({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _gutter(constraints.maxWidth),
        ),
        child: child,
      ),
    );
  }
}

class _ResourceList extends StatelessWidget {
  final List<Widget> children;

  const _ResourceList({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final horizontal = _gutter(constraints.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 13, horizontal, 96),
          children: children,
        );
      },
    );
  }
}

class _ResourceBuilderList extends StatelessWidget {
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  const _ResourceBuilderList({
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final horizontal = _gutter(constraints.maxWidth);
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(horizontal, 13, horizontal, 96),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

class _ImageRowCardSegment extends StatelessWidget {
  final int index;
  final int itemCount;
  final Widget child;

  const _ImageRowCardSegment({
    required this.index,
    required this.itemCount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final first = index == 0;
    final last = index == itemCount - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, first ? 4 : 0, 4, last ? 4 : 0),
      child: Material(
        color: context.theme.cardTheme.color ??
            context.theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(
          top: first ? const Radius.circular(13) : Radius.zero,
          bottom: last ? const Radius.circular(13) : Radius.zero,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// One number in [ContainerSummaryCard].
/// The runtime and its totals, above whatever tab is showing: one line where
/// there is room, two where there is not.
///
/// Not a card. It labels the table under it and the bar over it, and a card
/// here read as a third thing to get past before reaching the list the page
/// exists for.
///
/// The title is the runtime rather than the page. The bar already says
/// Container, and what the icon, the version and the counts all belong to is
/// Docker.
class ContainerRuntimeHeader extends StatelessWidget {
  final ContainerType type;
  final String? version;

  /// `3 running · 1 stopped · 12 images · 809 MB`, assembled by the page,
  /// which is what knows which of those it has.
  final String summary;

  /// What survives when the line has to fold. Narrow drops the totals that do
  /// not fit rather than wrapping them onto a third line.
  final String compactSummary;

  /// Container / Image / Settings. Built here rather than passed in, because
  /// only this widget knows whether the line folded — and a selector sharing a
  /// line sizes to its labels while one with a row to itself spreads across
  /// it.
  final Widget Function(bool expand) selector;

  const ContainerRuntimeHeader({
    required this.type,
    required this.version,
    required this.summary,
    required this.compactSummary,
    required this.selector,
    super.key,
  });

  /// Below this the line cannot hold the counts and the selector at once.
  static const wideWidth = 620.0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final icon = Icon(_runtimeIcon(type), size: 19, color: scheme.primary);
    final title = Text(
      type.name.capitalize,
      style: const TextStyle(fontWeight: FontWeight.w500),
    );

    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < wideWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        Text(
                          compactSummary,
                          key: const ValueKey('container-runtime-summary'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UIs.text11Grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              UIs.height13,
              selector(true),
            ],
          );
        }

        return Row(
          children: [
            icon,
            const SizedBox(width: 9),
            title,
            const SizedBox(width: 9),
            Text(version ?? libL10n.unknown, style: _monoGrey(12)),
            const SizedBox(width: 9),
            Container(width: 1, height: 15, color: _hairlineOf(context)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                summary,
                key: const ValueKey('container-runtime-summary'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: UIs.textGrey.color),
              ),
            ),
            const SizedBox(width: 9),
            selector(false),
          ],
        );
      },
    );
  }
}

Color _hairlineOf(BuildContext context) =>
    context.theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

class _ContainerGroup {
  final String? project;
  final List<ContainerPs> items;

  const _ContainerGroup({required this.project, required this.items});
}

List<_ContainerGroup> _groupContainers(List<ContainerPs> items) {
  final grouped = <String?, List<ContainerPs>>{};
  for (final item in items) {
    grouped.putIfAbsent(item.project, () => []).add(item);
  }
  final keys = grouped.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      final lowerCmp = a.toLowerCase().compareTo(b.toLowerCase());
      if (lowerCmp != 0) return lowerCmp;
      return a.compareTo(b);
    });
  return keys
      .map((key) {
        final groupItems = grouped[key]!..sort(_compareContainerItems);
        return _ContainerGroup(project: key, items: groupItems);
      })
      .toList(growable: false);
}

int _compareContainerItems(ContainerPs a, ContainerPs b) {
  for (final fields in [
    (a.name, b.name),
    (a.id, b.id),
    (a.image, b.image),
    (a.rawStatus, b.rawStatus),
  ]) {
    final comparison = _compareContainerText(fields.$1, fields.$2);
    if (comparison != 0) return comparison;
  }
  return 0;
}

int _compareContainerText(String? a, String? b) {
  final aValue = a?.trim() ?? '';
  final bValue = b?.trim() ?? '';
  final lowerComparison = aValue.toLowerCase().compareTo(bValue.toLowerCase());
  if (lowerComparison != 0) return lowerComparison;
  return aValue.compareTo(bValue);
}

/// Lays containers out as a grid of cards, or as rows in one card when the
/// column is too narrow for a card to hold its metrics.
/// The column widths the header and every row share.
///
/// Sharing them is the whole point: this is a table rather than a list of
/// cards so that a column of percentages can be read straight down without
/// reading any of the names beside them.
const _kColCpu = 84.0;
const _kColMem = 84.0;
const _kColNet = 104.0;
const _kColDisk = 104.0;
const _kColUptime = 88.0;
const _kColMenu = 24.0;
const _kColGap = 13.0;

/// Below this the fixed columns leave the name nothing to live in, and the
/// table gives way to one stacked row per container.
const _kTableWideWidth = 780.0;

Widget _tableLine({
  required Widget name,
  required Widget cpu,
  required Widget mem,
  required Widget net,
  required Widget disk,
  required Widget uptime,
  required Widget menu,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: name),
      const SizedBox(width: _kColGap),
      SizedBox(width: _kColCpu, child: cpu),
      const SizedBox(width: _kColGap),
      SizedBox(width: _kColMem, child: mem),
      const SizedBox(width: _kColGap),
      SizedBox(width: _kColNet, child: net),
      const SizedBox(width: _kColGap),
      SizedBox(width: _kColDisk, child: disk),
      const SizedBox(width: _kColGap),
      SizedBox(width: _kColUptime, child: uptime),
      const SizedBox(width: _kColGap),
      SizedBox(width: _kColMenu, child: menu),
    ],
  );
}

/// Every container on the server in one card: a column header, a bar per
/// compose project, and a line per container.
class _ContainerTable extends StatefulWidget {
  final List<_ContainerGroup> groups;
  final bool showGroupHeaders;
  final ContainerItemTrailingBuilder trailingBuilder;
  final ContainerQuickActionHandler? onQuickAction;

  const _ContainerTable({
    required this.groups,
    required this.showGroupHeaders,
    required this.trailingBuilder,
    required this.onQuickAction,
  });

  @override
  State<_ContainerTable> createState() => _ContainerTableState();
}

class _ContainerTableState extends State<_ContainerTable> {
  /// Folded projects, so the default is open. A page whose every group had to
  /// be opened before it said anything was a page that said nothing.
  final _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = constraints.maxWidth >= _kTableWideWidth;
        final children = <Widget>[];
        if (wide) children.add(_buildColumnHeader(context));

        for (final group in widget.groups) {
          final key = group.project;
          final headed =
              widget.showGroupHeaders &&
              (widget.groups.length > 1 || key != null);
          final collapsed = key != null && _collapsed.contains(key);

          if (headed) {
            children.add(
              _ContainerGroupHeader(
                project: key ?? context.l10n.dockerProjectOther,
                items: group.items,
                collapsible: key != null,
                expanded: !collapsed,
                onToggle: key == null
                    ? null
                    : () => setState(() {
                        if (!_collapsed.remove(key)) _collapsed.add(key);
                      }),
              ),
            );
          }
          children.add(
            _Collapsible(
              collapsed: collapsed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in group.items)
                    wide
                        ? _ContainerTableRow(
                            item: item,
                            trailing: widget.trailingBuilder(item),
                          )
                        : _ContainerRow(
                            item: item,
                            trailing: widget.trailingBuilder(item),
                            onQuickAction: widget.onQuickAction,
                          ),
                ],
              ),
            ),
          );
        }

        return CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }

  Widget _buildColumnHeader(BuildContext context) {
    Widget label(String text, {bool trailing = true}) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: trailing ? TextAlign.end : TextAlign.start,
      style: UIs.text11Grey,
    );

    return Container(
      key: const ValueKey('container-table-header'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _hairlineOf(context))),
      ),
      child: _tableLine(
        name: label(libL10n.name, trailing: false),
        cpu: label('CPU'),
        mem: label('Mem'),
        net: label('Net ↓ / ↑'),
        disk: label('Disk R / W'),
        uptime: label(libL10n.uptime),
        menu: const SizedBox.shrink(),
      ),
    );
  }
}

/// Folds a group's rows away over the same 200ms its chevron turns in.
///
/// The rows stay built while folded — this animates the height they are given
/// rather than whether they exist, which is what keeps the fold smooth in both
/// directions and is what an ExpansionTile does too. [ClipRect] is what stops
/// the half-height rows painting past the card's edge on the way.
class _Collapsible extends StatelessWidget {
  final bool collapsed;
  final Widget child;

  const _Collapsible({required this.collapsed, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: collapsed ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

class _ContainerGroupHeader extends StatelessWidget {
  final String project;
  final List<ContainerPs> items;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;

  const _ContainerGroupHeader({
    required this.project,
    required this.items,
    required this.collapsible,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final running = items.where((e) => e.status.isRunning).length;
    final stopped = items.where((e) => e.status.isStopped).length;
    final unknown = items
        .where((e) => e.status == ContainerStatus.unknown)
        .length;
    final summary = [
      if (running > 0) '$running ${context.libL10n.running}',
      if (stopped > 0) '$stopped ${context.libL10n.stopped}',
      if (unknown > 0) '$unknown ${libL10n.unknown}',
    ].join(' · ');

    final bar = Container(
      key: ValueKey('container-group-header-$project'),
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.folder_open, size: 15, color: UIs.textGrey.color),
          UIs.width7,
          // One Expanded holding both labels, rather than a Flexible label
          // beside a Spacer: those two share the free space one to one, which
          // left the buttons stranded half way across the bar.
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    project,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                UIs.width7,
                Flexible(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UIs.text11Grey,
                  ),
                ),
              ],
            ),
          ),
          if (collapsible)
            AnimatedRotation(
              key: ValueKey('container-group-arrow-$project'),
              turns: expanded ? 0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_less,
                size: 15,
                color: UIs.textGrey.color,
              ),
            ),
        ],
      ),
    );

    if (!collapsible) return bar;
    return InkWell(onTap: onToggle, child: bar);
  }
}

/// One container as a table line, its numbers under the header's columns.
class _ContainerTableRow extends StatelessWidget {
  final ContainerPs item;
  final Widget trailing;

  const _ContainerTableRow({required this.item, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final id = item.id ?? item.name ?? 'unknown';
    final running = item.status.isRunning;
    final data = _ContainerResourceData.from(item);
    final badge = _stateBadge(item);

    return Padding(
      key: ValueKey('container-table-row-$id'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: _tableLine(
        name: Row(
          children: [
            _StatusDot(running: running),
            const SizedBox(width: 9),
            Flexible(
              flex: 2,
              child: Text(
                item.name ?? libL10n.unknown,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: running ? null : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              flex: 3,
              child: Text(
                item.ports == null
                    ? (item.image ?? libL10n.unknown)
                    : '${item.image ?? libL10n.unknown} · ${item.ports}',
                key: ValueKey('container-identity-$id'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _monoGrey(11),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 9),
              _StateBadge(
                key: ValueKey('container-state-badge-$id'),
                label: badge,
              ),
            ],
          ],
        ),
        cpu: _PercentCell(
          key: ValueKey('container-metric-$id-cpu'),
          percent: data.cpuPercent,
        ),
        mem: _PercentCell(
          key: ValueKey('container-metric-$id-memory'),
          percent: data.memoryPercent,
        ),
        net: _PairCell(
          key: ValueKey('container-metric-$id-network'),
          values: data.network,
        ),
        disk: _PairCell(
          key: ValueKey('container-metric-$id-disk'),
          values: data.disk,
        ),
        uptime: Text(
          _uptimeLabel(item),
          key: ValueKey('container-status-$id'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        menu: trailing,
      ),
    );
  }
}

/// The same container stacked, for a column too narrow for the table: the
/// four metrics become one line, and the actions a stopped one needs take the
/// place of the numbers it has none of.
class _ContainerRow extends StatelessWidget {
  final ContainerPs item;
  final Widget trailing;
  final ContainerQuickActionHandler? onQuickAction;

  const _ContainerRow({
    required this.item,
    required this.trailing,
    required this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final id = item.id ?? item.name ?? 'unknown';
    final running = item.status.isRunning;
    final metrics = running
        ? _ContainerResourceData.from(item).compactLine()
        : null;

    // The menu button is 38pt tall against a 20pt name, so leaving it inside
    // the first line made the line 38 and pushed the name 9pt down — the row
    // then had 18 above its text and 9 below it. Keeping it in the outer row,
    // top-aligned, lets its own tap padding overlap the row's instead of
    // adding to it, and the column's padding is what spaces the text.
    return Row(
      key: ValueKey('container-row-$id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 9, 0, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusDot(running: running),
                    UIs.width7,
                    Expanded(
                      child: Text(
                        item.name ?? libL10n.unknown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: running ? null : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.ports == null
                      ? (item.image ?? libL10n.unknown)
                      : '${item.image ?? libL10n.unknown} · ${item.ports}',
                  key: ValueKey('container-identity-$id'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _monoGrey(11),
                ),
                if (metrics != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    metrics,
                    key: ValueKey('container-metrics-line-$id'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ] else if (!running) ...[
                  const SizedBox(height: 5),
                  _ContainerQuickActions(
                    item: item,
                    onQuickAction: onQuickAction,
                    includeRemove: false,
                  ),
                ],
              ],
            ),
          ),
        ),
        UIs.width7,
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _uptimeLabel(item),
                key: ValueKey('container-status-$id'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UIs.text11Grey.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool running;

  const _StatusDot({required this.running});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: running ? scheme.primary : scheme.outline,
      ),
    );
  }
}

/// `Exited (0)` beside the name of a container that is not running, where the
/// table has taken its lifecycle text away to make the Uptime column line up.
class _StateBadge extends StatelessWidget {
  final String label;

  const _StateBadge({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.text11Grey,
      ),
    );
  }
}

/// Start / Logs, offered where a stopped container's metrics would be.
///
/// Remove is left off: it is the one action here that cannot be undone, and
/// it would sit a chip's width from Start.
class _ContainerQuickActions extends StatelessWidget {
  final ContainerPs item;
  final ContainerQuickActionHandler? onQuickAction;
  final bool includeRemove;

  const _ContainerQuickActions({
    required this.item,
    required this.onQuickAction,
    required this.includeRemove,
  });

  @override
  Widget build(BuildContext context) {
    final handler = onQuickAction;
    if (handler == null) return UIs.placeholder;

    final scheme = context.theme.colorScheme;
    final offered = ContainerMenu.items(item.status);
    final actions = [
      if (offered.contains(ContainerMenu.start)) ContainerMenu.start,
      if (offered.contains(ContainerMenu.logs)) ContainerMenu.logs,
      if (includeRemove && offered.contains(ContainerMenu.rm)) ContainerMenu.rm,
    ];
    if (actions.isEmpty) return UIs.placeholder;

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final action in actions)
          ActionChip(
            key: ValueKey(
              'container-quick-${action.name}-${item.id ?? item.name}',
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Icon(
              action.icon,
              size: 15,
              color: action == ContainerMenu.rm ? scheme.error : null,
            ),
            label: Text(action.toStr),
            labelStyle: TextStyle(
              fontSize: 12,
              color: action == ContainerMenu.rm ? scheme.error : null,
            ),
            backgroundColor: action == ContainerMenu.start
                ? scheme.primaryContainer
                : null,
            side: action == ContainerMenu.start ? BorderSide.none : null,
            onPressed: () => handler(action, item),
          ),
      ],
    );
  }
}

/// `Up 11 days` → `11 d`, `Exited (0) 2 days ago` → `2 d ago`.
///
/// Both runtimes write this in English whatever the server's locale is, so
/// matching the unit word is safe. Anything unrecognised is returned as the
/// runtime wrote it: a status this cannot shorten is still a status worth
/// reading.
String _uptimeLabel(ContainerPs item) {
  final raw = _statusLabel(item).trim();
  final match = RegExp(
    r'(\d+)\s+(second|minute|hour|day|week|month|year)s?(\s+ago)?',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return raw;
  const units = {
    'second': 's',
    'minute': 'm',
    'hour': 'h',
    'day': 'd',
    'week': 'w',
    'month': 'mo',
    'year': 'y',
  };
  final unit = units[match.group(2)!.toLowerCase()];
  if (unit == null) return raw;
  return '${match.group(1)} $unit${match.group(3) == null ? '' : ' ago'}';
}

/// The lifecycle half of a stopped container's status, with the time part
/// [_uptimeLabel] moved to its own column removed.
String? _stateBadge(ContainerPs item) {
  if (item.status.isRunning) return null;
  final raw = _statusLabel(item).trim();
  final match = RegExp(
    r'\s*\d+\s+(second|minute|hour|day|week|month|year)s?(\s+ago)?\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return raw.isEmpty ? null : raw;
  final prefix = raw.substring(0, match.start).trim();
  return prefix.isEmpty ? null : prefix;
}

TextStyle _monoGrey(double size) => TextStyle(
  fontFamily: 'monospace',
  fontSize: size,
  color: UIs.textGrey.color,
);

class _ContainerResourceData {
  final double? cpuPercent;
  final double? memoryPercent;
  final _MetricPair? network;
  final _MetricPair? disk;

  const _ContainerResourceData({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.network,
    required this.disk,
  });

  factory _ContainerResourceData.from(ContainerPs item) {
    return _ContainerResourceData(
      cpuPercent: _parsePercent(item.cpu),
      memoryPercent: _parseUsagePercent(item.mem),
      network: _parseMetricPair(item.net),
      disk: _parseMetricPair(item.disk),
    );
  }

  bool get isNotEmpty =>
      cpuPercent != null ||
      memoryPercent != null ||
      network != null ||
      disk != null;

  /// The metrics as one line, for a row too narrow to give each of them a
  /// column. Null when nothing was measured.
  ///
  /// Disk is left out. It is the least urgent of the four and the only one
  /// whose two values are both large enough to push the line past a phone's
  /// width, which turned every row's last metric into an ellipsis.
  String? compactLine() {
    final parts = [
      if (cpuPercent case final value?) 'CPU ${value.toStringAsFixed(1)}%',
      if (memoryPercent case final value?) 'Mem ${value.toStringAsFixed(1)}%',
      if (network case final values?)
        '↓ ${values.first}${values.second == null ? '' : ' ↑ ${values.second}'}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _MetricPair {
  final String first;
  final String? second;

  const _MetricPair({required this.first, required this.second});
}

/// Four cells across the foot of a card: CPU and memory as a percentage over
/// a bar, network and disk as their two counters.
///
/// A bar rather than the ring this used to draw. At two cards to a row the
/// ring was the widest thing on the card and the least readable: a percentage
/// is a number, and the only comparison worth making is against the other
/// containers in the column, which a left-aligned bar gives and a centred ring
/// does not.
/// A percentage over its own bar, right-aligned under the column header.
///
/// The bar is the comparison: the number says what this container is doing,
/// and the bars down the column say which one to look at.
class _PercentCell extends StatelessWidget {
  final double? percent;

  const _PercentCell({required this.percent, super.key});

  @override
  Widget build(BuildContext context) {
    final value = percent;
    if (value == null) return const _MetricDash();

    final scheme = context.theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${value.toStringAsFixed(1)}%',
          maxLines: 1,
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: scheme.surfaceContainerHighest,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Two counters stacked, the second in grey: down over up, read over written.
class _PairCell extends StatelessWidget {
  final _MetricPair? values;

  const _PairCell({required this.values, super.key});

  @override
  Widget build(BuildContext context) {
    final pair = values;
    if (pair == null) return const _MetricDash();

    final scheme = context.theme.colorScheme;
    TextStyle style(Color? color) => TextStyle(
      fontSize: 12,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pair.first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: style(scheme.onSurfaceVariant),
        ),
        if (pair.second case final second?)
          Text(
            second,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: style(UIs.textGrey.color),
          ),
      ],
    );
  }
}

/// Not measured. A dash rather than a blank, so the column still reads as a
/// column, and rather than a zero, which would be a measurement.
class _MetricDash extends StatelessWidget {
  const _MetricDash();

  @override
  Widget build(BuildContext context) {
    return Text('—', textAlign: TextAlign.end, style: UIs.textGrey);
  }
}

/// Image columns, sized the way the container table's are and for the same
/// reason: a size is worth comparing down the page, and it can only be
/// compared if it starts in the same place on every row.
const _kColImgSize = 88.0;
const _kColImgCreated = 140.0;

Widget _imageLine({
  required Widget name,
  required Widget size,
  required Widget created,
  required Widget menu,
  required bool wide,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: name),
      const SizedBox(width: _kColGap),
      SizedBox(width: _kColImgSize, child: size),
      if (wide) ...[
        const SizedBox(width: _kColGap),
        SizedBox(width: _kColImgCreated, child: created),
      ],
      const SizedBox(width: _kColGap),
      SizedBox(width: _kColMenu, child: menu),
    ],
  );
}

class _ImageColumnHeader extends StatelessWidget {
  const _ImageColumnHeader();

  @override
  Widget build(BuildContext context) {
    Widget label(String text, {bool trailing = true}) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: trailing ? TextAlign.end : TextAlign.start,
      style: UIs.text11Grey,
    );

    return Container(
      key: const ValueKey('image-table-header'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _hairlineOf(context))),
      ),
      child: _imageLine(
        wide: true,
        name: label(libL10n.name, trailing: false),
        size: label(libL10n.size),
        created: label(libL10n.time),
        menu: const SizedBox.shrink(),
      ),
    );
  }
}

/// One image: its reference and id, with size and age in their own columns
/// where there is room and folded under the name where there is not.
///
/// No leading icon. Every row of this list would carry the same one, and what
/// distinguishes a row — being unused, being dangling — is already a badge
/// beside the name.
class _ContainerImageRow extends StatelessWidget {
  final int index;
  final ContainerImg image;
  final Widget trailing;
  final bool wide;

  const _ContainerImageRow({
    required this.index,
    required this.image,
    required this.trailing,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final id = image.id ?? _imageReference(image);
    final created = _imageCreatedLabel(image, Localizations.localeOf(context));
    final shortId = _shortId(image.id) ?? libL10n.unknown;
    final unused = image.isUnused;

    final sizeText = Text(
      image.sizeMB ?? '—',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 13,
        color: unused ? UIs.textGrey.color : null,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    // The menu sits in the outer row so its tap padding overlaps the row's
    // rather than adding to it — the same reason the container row does it.
    return KeyedSubtree(
      key: ValueKey('image-row-${wide ? 'wide' : 'compact'}-$index-$id'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 9, 5, 9),
        child: _imageLine(
          wide: wide,
          name: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _imageReference(image),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: unused ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  if (image.isDangling) ...[
                    UIs.width7,
                    _ImageBadge(label: context.l10n.dangling),
                  ] else if (unused) ...[
                    UIs.width7,
                    _ImageBadge(label: context.l10n.unused),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                wide || created == null ? shortId : '$shortId · $created',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _monoGrey(11),
              ),
            ],
          ),
          size: sizeText,
          created: Text(
            created ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: UIs.text11Grey.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          menu: trailing,
        ),
      ),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  final String label;

  const _ImageBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: UIs.text11.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}

class _EmptyResourceCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyResourceCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 30),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            UIs.height13,
            Text(message, textAlign: TextAlign.center, style: UIs.text13Grey),
          ],
        ),
      ),
    );
  }
}

IconData _runtimeIcon(ContainerType type) => switch (type) {
  ContainerType.docker => IonIcons.logo_docker,
  ContainerType.podman => OctIcons.container,
};

String _statusLabel(ContainerPs item) {
  final raw = item.rawStatus?.trim();
  return raw == null || raw.isEmpty ? item.status.displayName : raw;
}

double? _parsePercent(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(RegExp(r'\s*/\s*'));
  if (parts.isEmpty || parts.length > 2) return null;
  final value = _parsePercentValue(parts.first);
  if (value == null || !value.isFinite || value < 0) return null;
  if (parts.length == 2 && _parsePercentValue(parts[1], labeled: true) == null) {
    return null;
  }
  return value.clamp(0, 100).toDouble();
}

double? _parsePercentValue(String raw, {bool labeled = false}) {
  final prefix = labeled ? r'[^\d.-]*' : '';
  final match = RegExp(
    '^\\s*$prefix(-?(?:\\d+(?:\\.\\d+)?|\\.\\d+))\\s*%\\s*\$',
  ).firstMatch(raw);
  final value = double.tryParse(match?.group(1) ?? '');
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

double? _parseUsagePercent(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(RegExp(r'\s*/\s*'));
  if (parts.length != 2) return null;
  final used = _parseByteSize(parts[0]);
  final total = _parseByteSize(parts[1]);
  if (used == null || total == null || total <= 0) return null;
  return (used / total * 100).clamp(0, 100).toDouble();
}

double? _parseByteSize(String raw) {
  final match = RegExp(
    r'^\s*(-?(?:\d+(?:\.\d+)?|\.\d+))\s*([kmgtpe]?i?b)?\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null || !value.isFinite || value < 0) return null;
  final unit = (match.group(2) ?? 'b').toLowerCase();
  final multiplier = switch (unit) {
    'kb' => 1000.0,
    'kib' => 1024.0,
    'mb' => 1000.0 * 1000,
    'mib' => 1024.0 * 1024,
    'gb' => 1000.0 * 1000 * 1000,
    'gib' => 1024.0 * 1024 * 1024,
    'tb' => 1000.0 * 1000 * 1000 * 1000,
    'tib' => 1024.0 * 1024 * 1024 * 1024,
    'pb' => 1000.0 * 1000 * 1000 * 1000 * 1000,
    'pib' => 1024.0 * 1024 * 1024 * 1024 * 1024,
    'eb' => 1000.0 * 1000 * 1000 * 1000 * 1000 * 1000,
    'eib' => 1024.0 * 1024 * 1024 * 1024 * 1024 * 1024,
    _ => 1.0,
  };
  return value * multiplier;
}

_MetricPair? _parseMetricPair(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw.split(RegExp(r'\s*/\s*'));
  if (parts.length != 2) return null;
  final first = _extractMetricValue(parts.first);
  final second = _extractMetricValue(parts[1]);
  if (first == null || second == null) return null;
  return _MetricPair(first: first, second: second);
}

String? _extractMetricValue(String raw) {
  final match = RegExp(
    r'^\s*[^\d.-]*((-?(?:\d+(?:\.\d+)?|\.\d+))\s*[kmgtpe]?i?b)\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match != null) {
    final value = double.tryParse(match.group(2)!);
    if (value == null || !value.isFinite || value < 0) return null;
    return match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  return null;
}

String _imageReference(ContainerImg image) {
  final repository = image.repository?.trim();
  final tag = image.tag?.trim();
  final noRepository = repository == null ||
      repository.isEmpty ||
      repository == '<none>';
  final noTag = tag == null || tag.isEmpty || tag == '<none>';
  if (noRepository) return _shortId(image.id) ?? '<none>';
  if (noTag) return repository;
  return '$repository:$tag';
}

String? _shortId(String? id) {
  if (id == null || id.isEmpty) return null;
  final normalized = id.startsWith('sha256:') ? id.substring(7) : id;
  if (normalized.length <= 12) return normalized;
  return normalized.substring(0, 12);
}

String? _imageCreatedLabel(ContainerImg image, Locale locale) => switch (image) {
  final DockerImg img => img.createdAt.trim().isEmpty ? null : img.createdAt,
  final PodmanImg img => _formatUnixDate(img.created, locale),
  _ => null,
};

String? _formatUnixDate(int? seconds, Locale locale) {
  if (seconds == null || seconds <= 0) return null;
  final date = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
  return DateFormat.yMd(locale.toLanguageTag()).format(date);
}
