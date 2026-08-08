import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/view/widget/percent_circle.dart';

typedef ContainerItemTrailingBuilder = Widget Function(ContainerPs item);
typedef ContainerGroupTrailingBuilder = Widget? Function(
  List<ContainerPs> items,
);
typedef ContainerImageTrailingBuilder = Widget Function(ContainerImg image);

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

/// Responsive container list used by [ContainerPage].
///
/// The view intentionally owns presentation only. Container actions are
/// supplied by the page so the existing provider and confirmation flow stay
/// unchanged.
class ContainerItemsView extends StatelessWidget {
  final List<ContainerPs> items;
  final ContainerType type;
  final String? version;
  final ContainerItemTrailingBuilder trailingBuilder;
  final ContainerGroupTrailingBuilder groupTrailingBuilder;
  final Widget? emptyState;
  final Widget? summaryAction;

  const ContainerItemsView({
    required this.items,
    required this.type,
    required this.version,
    required this.trailingBuilder,
    required this.groupTrailingBuilder,
    this.emptyState,
    this.summaryAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _groupContainers(items);
    final running = items.where((e) => e.status.isRunning).length;
    final stopped = items.where((e) => e.status.isStopped).length;
    final unknown = items
        .where((e) => e.status == ContainerStatus.unknown)
        .length;
    return _ResourceList(
      children: [
        _RuntimeSummaryCard(
          icon: _runtimeIcon(type),
          title: type.name.capitalize,
          subtitle: version ?? context.l10n.unknown,
          action: summaryAction,
          badges: [
            _SummaryBadge(
              label: '$running ${context.libL10n.running}',
              emphasized: running > 0,
            ),
            if (stopped > 0)
              _SummaryBadge(
                label: '$stopped ${context.libL10n.stopped}',
              ),
            if (unknown > 0)
              _SummaryBadge(
                label: '$unknown ${context.l10n.unknown}',
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          emptyState ??
              _EmptyResourceCard(
                icon: OctIcons.container,
                message: context.libL10n.empty,
              )
        else
          for (var index = 0; index < groups.length; index++) ...[
            _ContainerGroupCard(
              key: ValueKey(
                groups[index].project == null
                    ? 'container-group-standalone'
                    : 'container-group-compose:${groups[index].project}',
              ),
              group: groups[index],
              showHeader: groups.length > 1 || groups[index].project != null,
              trailingBuilder: trailingBuilder,
              groupTrailingBuilder: groupTrailingBuilder,
            ),
            if (index != groups.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// Responsive image list used by [ContainerPage].
class ContainerImagesView extends StatelessWidget {
  final List<ContainerImg> images;
  final ContainerType type;
  final String? version;
  final ContainerImageTrailingBuilder trailingBuilder;
  final Widget? summaryAction;

  const ContainerImagesView({
    required this.images,
    required this.type,
    required this.version,
    required this.trailingBuilder,
    this.summaryAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final unused = images.where((e) => e.isUnused).length;
    final summary = _RuntimeSummaryCard(
      icon: MingCute.clapperboard_line,
      title: type.name.capitalize,
      subtitle: version ?? context.l10n.unknown,
      action: summaryAction,
      badges: [
        _SummaryBadge(
          label: context.l10n.dockerImagesFmt(images.length),
          emphasized: images.isNotEmpty,
        ),
        if (unused > 0)
          _SummaryBadge(label: '$unused ${context.l10n.unused}'),
      ],
    );

    if (images.isEmpty) {
      return _ResourceList(
        children: [
          summary,
          const SizedBox(height: 10),
          _EmptyResourceCard(
            icon: MingCute.clapperboard_line,
            message: context.libL10n.empty,
          ),
        ],
      );
    }

    return _ResourceBuilderList(
      itemCount: images.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return summary;
        if (index == 1) return const SizedBox(height: 10);
        final imageIndex = index - 2;
        return _ImageRowCardSegment(
          index: imageIndex,
          itemCount: images.length,
          child: _ContainerImageRow(
            index: imageIndex,
            image: images[imageIndex],
            trailing: trailingBuilder(images[imageIndex]),
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
              value: unusedTaggedCount?.toString() ?? context.l10n.unknown,
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

class _ResourceList extends StatelessWidget {
  final List<Widget> children;

  const _ResourceList({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final horizontal = constraints.maxWidth > 1226
            ? (constraints.maxWidth - 1200) / 2
            : 13.0;
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
        final horizontal = constraints.maxWidth > 1226
            ? (constraints.maxWidth - 1200) / 2
            : 13.0;
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
        child: Column(
          children: [
            child,
            if (!last) const Divider(height: 1, indent: 15, endIndent: 15),
          ],
        ),
      ),
    );
  }
}

class _RuntimeSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> badges;
  final Widget? action;

  const _RuntimeSummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badges,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 21, color: scheme.onPrimaryContainer),
        ),
        UIs.width13,
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.titleMedium,
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UIs.text13Grey,
              ),
            ],
          ),
        ),
      ],
    );

    return CardX(
      child: LayoutBuilder(
        builder: (_, constraints) {
          final badgeWrap = Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.end,
            children: badges,
          );
          if (constraints.maxWidth < 520) {
            return Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  UIs.height13,
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: badgeWrap,
                        ),
                      ),
                      if (action != null) ...[
                        UIs.width7,
                        action!,
                      ],
                    ],
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(child: identity),
                UIs.width13,
                badgeWrap,
                if (action != null) ...[
                  UIs.width7,
                  action!,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final bool emphasized;

  const _SummaryBadge({required this.label, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final color = emphasized
        ? scheme.primaryContainer.withValues(alpha: 0.7)
        : scheme.surfaceContainerHighest;
    final textColor = emphasized
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: UIs.text11.copyWith(color: textColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}

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
      .map((key) => _ContainerGroup(project: key, items: grouped[key]!))
      .toList(growable: false);
}

class _ContainerGroupCard extends StatefulWidget {
  final _ContainerGroup group;
  final bool showHeader;
  final ContainerItemTrailingBuilder trailingBuilder;
  final ContainerGroupTrailingBuilder groupTrailingBuilder;

  const _ContainerGroupCard({
    required this.group,
    required this.showHeader,
    required this.trailingBuilder,
    required this.groupTrailingBuilder,
    super.key,
  });

  @override
  State<_ContainerGroupCard> createState() => _ContainerGroupCardState();
}

class _ContainerGroupCardState extends State<_ContainerGroupCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final collapsible = widget.showHeader && group.project != null;
    final showItems = !collapsible || _expanded;
    final groupTrailing = widget.groupTrailingBuilder(group.items);
    return CardX(
      child: Column(
        children: [
          if (widget.showHeader) ...[
            _ContainerGroupHeader(
              project: group.project ?? context.l10n.dockerProjectOther,
              items: group.items,
              trailing: groupTrailing,
              collapsible: collapsible,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
            if (showItems) const Divider(height: 1),
          ],
          if (showItems)
            for (var index = 0; index < group.items.length; index++) ...[
              _ContainerItemRow(
                index: index,
                item: group.items[index],
                trailing: widget.trailingBuilder(group.items[index]),
              ),
              if (index != group.items.length - 1)
                const Divider(height: 1, indent: 15, endIndent: 15),
            ],
        ],
      ),
    );
  }
}

class _ContainerGroupHeader extends StatelessWidget {
  final String project;
  final List<ContainerPs> items;
  final Widget? trailing;
  final bool collapsible;
  final bool expanded;
  final VoidCallback onToggle;

  const _ContainerGroupHeader({
    required this.project,
    required this.items,
    required this.trailing,
    required this.collapsible,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final running = items.where((e) => e.status.isRunning).length;
    final stopped = items.where((e) => e.status.isStopped).length;
    final unknown = items
        .where((e) => e.status == ContainerStatus.unknown)
        .length;
    final summary = [
      '$running ${context.libL10n.running}',
      if (stopped > 0) '$stopped ${context.libL10n.stopped}',
      if (unknown > 0) '$unknown ${context.l10n.unknown}',
    ].join(' · ');
    return ListTile(
      key: ValueKey('container-group-header-$project'),
      contentPadding: const EdgeInsets.only(left: 15, right: 5),
      leading: Icon(
        Icons.folder_outlined,
        size: 18,
        color: context.theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        project,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.theme.textTheme.titleSmall,
      ),
      subtitle: Text(summary, style: UIs.text11Grey),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailing,
          if (collapsible)
            AnimatedRotation(
              key: ValueKey('container-group-arrow-$project'),
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more),
            ),
        ],
      ),
      onTap: collapsible ? onToggle : null,
    );
  }
}

class _ContainerItemRow extends StatelessWidget {
  final int index;
  final ContainerPs item;
  final Widget trailing;

  const _ContainerItemRow({
    required this.index,
    required this.item,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final id = item.id ?? item.name ?? 'unknown';
    final resources = _ContainerResourceData.from(item);
    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = constraints.maxWidth >= 1040;
        return KeyedSubtree(
          key: ValueKey(
            'container-row-${wide ? 'wide' : 'compact'}-$index-$id',
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 5, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, wide: wide),
                if (resources.isNotEmpty) ...[
                  UIs.height13,
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _ContainerResourcePanel(
                      id: id,
                      data: resources,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, {required bool wide}) {
    return Row(
      children: [
        _StatusIcon(running: item.status.isRunning),
        UIs.width13,
        Expanded(child: _ContainerIdentity(item: item)),
        UIs.width7,
        SizedBox(
          width: wide ? 128 : 100,
          child: Text(
            _statusLabel(item),
            key: ValueKey('container-status-${item.id ?? item.name}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: UIs.text13Grey,
          ),
        ),
        trailing,
      ],
    );
  }
}

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
}

class _MetricPair {
  final String first;
  final String? second;

  const _MetricPair({required this.first, required this.second});
}

class _ContainerResourcePanel extends StatelessWidget {
  final String id;
  final _ContainerResourceData data;

  const _ContainerResourcePanel({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final slots = <Widget?>[
      data.cpuPercent == null
          ? null
          : _ResourceMetricSlot(
              key: ValueKey('container-resource-circle-$id-cpu'),
              label: 'CPU',
              child: PercentCircle(
                percent: data.cpuPercent!,
                centerText: '${data.cpuPercent!.toStringAsFixed(1)}%',
              ),
            ),
      data.memoryPercent == null
          ? null
          : _ResourceMetricSlot(
              key: ValueKey('container-resource-circle-$id-memory'),
              label: 'MEM',
              child: PercentCircle(
                percent: data.memoryPercent!,
                centerText: '${data.memoryPercent!.toStringAsFixed(1)}%',
              ),
            ),
      data.network == null
          ? null
          : _ResourceMetricSlot(
              key: ValueKey('container-resource-module-$id-network'),
              label: 'NET',
              child: _ResourcePairValues(
                firstLabel: '↓',
                secondLabel: '↑',
                values: data.network!,
              ),
            ),
      data.disk == null
          ? null
          : _ResourceMetricSlot(
              key: ValueKey('container-resource-module-$id-disk'),
              label: 'DISK',
              child: _ResourcePairValues(
                firstLabel: context.l10n.read,
                secondLabel: context.l10n.write,
                values: data.disk!,
              ),
            ),
    ];
    return Align(
      key: ValueKey('container-resource-panel-$id'),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: slots
              .map(
                (slot) => Expanded(
                  child: Center(child: slot ?? const SizedBox.shrink()),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ResourceMetricSlot extends StatelessWidget {
  final String label;
  final Widget child;

  const _ResourceMetricSlot({
    required this.label,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 70,
          child: Center(child: child),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 13,
          child: Center(
            child: Text(
              label,
              style: UIs.text11Grey,
              strutStyle: const StrutStyle(
                fontSize: 11,
                height: 1,
                forceStrutHeight: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResourcePairValues extends StatelessWidget {
  final String firstLabel;
  final String secondLabel;
  final _MetricPair values;

  const _ResourcePairValues({
    required this.firstLabel,
    required this.secondLabel,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ResourcePairValue(label: firstLabel, value: values.first),
        if (values.second != null) ...[
          const SizedBox(height: 3),
          _ResourcePairValue(label: secondLabel, value: values.second!),
        ],
      ],
    );
  }
}

class _ResourcePairValue extends StatelessWidget {
  final String label;
  final String value;

  const _ResourcePairValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label:\n$value',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: UIs.text11Grey,
    );
  }
}

class _ContainerIdentity extends StatelessWidget {
  final ContainerPs item;

  const _ContainerIdentity({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name ?? context.l10n.unknown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text15,
        ),
        const SizedBox(height: 2),
        Text(
          item.image ?? context.l10n.unknown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text13Grey,
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool running;

  const _StatusIcon({required this.running});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Icon(
      running ? Icons.play_circle_outline : Icons.stop_circle_outlined,
      size: 20,
      color: running ? scheme.primary : scheme.onSurfaceVariant,
    );
  }
}

class _ContainerImageRow extends StatelessWidget {
  final int index;
  final ContainerImg image;
  final Widget trailing;

  const _ContainerImageRow({
    required this.index,
    required this.image,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final id = image.id ?? _imageReference(image);
    final createdLabel = _imageCreatedLabel(
      image,
      Localizations.localeOf(context),
    );
    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = constraints.maxWidth >= 760;
        return KeyedSubtree(
          key: ValueKey(
            'image-row-${wide ? 'wide' : 'compact'}-$index-$id',
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 5, 12),
            child: Row(
              children: [
                Icon(
                  image.isDangling
                      ? Icons.broken_image_outlined
                      : Icons.image_outlined,
                  size: 20,
                  color: image.isUnused
                      ? context.theme.colorScheme.onSurfaceVariant
                      : context.theme.colorScheme.primary,
                ),
                UIs.width13,
                Expanded(child: _ImageIdentity(image: image, wide: wide)),
                SizedBox(
                  width: 82,
                  child: Text(
                    image.sizeMB ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: UIs.text13,
                  ),
                ),
                if (wide) ...[
                  UIs.width13,
                  SizedBox(
                    width: 180,
                    child: Text(
                      createdLabel ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: UIs.text11Grey,
                    ),
                  ),
                ],
                trailing,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImageIdentity extends StatelessWidget {
  final ContainerImg image;
  final bool wide;

  const _ImageIdentity({required this.image, required this.wide});

  @override
  Widget build(BuildContext context) {
    final id = _shortId(image.id) ?? context.l10n.unknown;
    final createdLabel = _imageCreatedLabel(
      image,
      Localizations.localeOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                _imageReference(image),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UIs.text15,
              ),
            ),
            if (image.isDangling) ...[
              UIs.width7,
              _ImageBadge(label: context.l10n.dangling),
            ] else if (image.isUnused) ...[
              UIs.width7,
              _ImageBadge(label: context.l10n.unused),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text13Grey,
        ),
        if (!wide && createdLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            createdLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: UIs.text11Grey,
          ),
        ],
      ],
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
  final match = RegExp(r'(\d+(?:\.\d+)?|\.\d+)\s*%').firstMatch(raw);
  final value = double.tryParse(match?.group(1) ?? '');
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

double? _parseUsagePercent(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(RegExp(r'\s*/\s*'));
  if (parts.length < 2) return null;
  final used = _parseByteSize(parts[0]);
  final total = _parseByteSize(parts[1]);
  if (used == null || total == null || total <= 0) return null;
  return used / total * 100;
}

double? _parseByteSize(String raw) {
  final match = RegExp(
    r'(\d+(?:\.\d+)?|\.\d+)\s*([kmgtpe]?i?b)?',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null || !value.isFinite) return null;
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
  final first = _extractMetricValue(parts.first);
  if (first == null) return null;
  final second = parts.length > 1 ? _extractMetricValue(parts[1]) : null;
  return _MetricPair(first: first, second: second);
}

String? _extractMetricValue(String raw) {
  final match = RegExp(
    r'(\d+(?:\.\d+)?|\.\d+)\s*[kmgtpe]?i?b',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match != null) {
    return match.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
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
