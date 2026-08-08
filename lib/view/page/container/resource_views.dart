import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/type.dart';

typedef ContainerItemTrailingBuilder = Widget Function(ContainerPs item);
typedef ContainerGroupTrailingBuilder = Widget? Function(
  List<ContainerPs> items,
);
typedef ContainerImageTrailingBuilder = Widget Function(ContainerImg image);

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

  const ContainerItemsView({
    required this.items,
    required this.type,
    required this.version,
    required this.trailingBuilder,
    required this.groupTrailingBuilder,
    this.emptyState,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _groupContainers(items);
    final running = items.where((e) => e.status.isRunning).length;
    final stopped = items.length - running;
    final hasStats = items.any(
      (e) => e.cpu != null || e.mem != null || e.net != null || e.disk != null,
    );

    return _ResourceList(
      children: [
        _RuntimeSummaryCard(
          icon: _runtimeIcon(type),
          title: type.name.capitalize,
          subtitle: version ?? context.l10n.unknown,
          badges: [
            _SummaryBadge(
              label: '$running ${context.libL10n.running}',
              emphasized: running > 0,
            ),
            if (stopped > 0)
              _SummaryBadge(
                label: '$stopped ${context.libL10n.stopped}',
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
              group: groups[index],
              showHeader: groups.length > 1 || groups[index].project != null,
              hasStats: hasStats,
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

  const ContainerImagesView({
    required this.images,
    required this.type,
    required this.version,
    required this.trailingBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final unused = images.where((e) => e.isUnused).length;

    return _ResourceList(
      children: [
        _RuntimeSummaryCard(
          icon: MingCute.clapperboard_line,
          title: type.name.capitalize,
          subtitle: version ?? context.l10n.unknown,
          badges: [
            _SummaryBadge(
              label: context.l10n.dockerImagesFmt(images.length),
              emphasized: images.isNotEmpty,
            ),
            if (unused > 0)
              _SummaryBadge(label: '$unused ${context.l10n.unused}'),
          ],
        ),
        const SizedBox(height: 10),
        if (images.isEmpty)
          _EmptyResourceCard(
            icon: MingCute.clapperboard_line,
            message: context.libL10n.empty,
          )
        else
          CardX(
            child: Column(
              children: [
                for (var index = 0; index < images.length; index++) ...[
                  _ContainerImageRow(
                    image: images[index],
                    trailing: trailingBuilder(images[index]),
                  ),
                  if (index != images.length - 1)
                    const Divider(height: 1, indent: 15, endIndent: 15),
                ],
              ],
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

class _RuntimeSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> badges;

  const _RuntimeSummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badges,
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
                  Align(alignment: Alignment.centerLeft, child: badgeWrap),
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

class _ContainerGroupCard extends StatelessWidget {
  final _ContainerGroup group;
  final bool showHeader;
  final bool hasStats;
  final ContainerItemTrailingBuilder trailingBuilder;
  final ContainerGroupTrailingBuilder groupTrailingBuilder;

  const _ContainerGroupCard({
    required this.group,
    required this.showHeader,
    required this.hasStats,
    required this.trailingBuilder,
    required this.groupTrailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final groupTrailing = groupTrailingBuilder(group.items);
    return CardX(
      child: Column(
        children: [
          if (showHeader) ...[
            _ContainerGroupHeader(
              project: group.project ?? context.l10n.dockerProjectOther,
              items: group.items,
              trailing: groupTrailing,
            ),
            const Divider(height: 1),
          ],
          for (var index = 0; index < group.items.length; index++) ...[
            _ContainerItemRow(
              item: group.items[index],
              hasStats: hasStats,
              trailing: trailingBuilder(group.items[index]),
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

  const _ContainerGroupHeader({
    required this.project,
    required this.items,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final running = items.where((e) => e.status.isRunning).length;
    final stopped = items.length - running;
    final summary = [
      '$running ${context.libL10n.running}',
      if (stopped > 0) '$stopped ${context.libL10n.stopped}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 11, 5, 11),
      child: Row(
        children: [
          Icon(
            Icons.folder_outlined,
            size: 18,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
          UIs.width13,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall,
                ),
                Text(summary, style: UIs.text11Grey),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ContainerItemRow extends StatelessWidget {
  final ContainerPs item;
  final bool hasStats;
  final Widget trailing;

  const _ContainerItemRow({
    required this.item,
    required this.hasStats,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final id = item.id ?? item.name ?? 'unknown';
    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = constraints.maxWidth >= 1040;
        return KeyedSubtree(
          key: ValueKey('container-row-${wide ? 'wide' : 'compact'}-$id'),
          child: wide ? _buildWide(context) : _buildCompact(context),
        );
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 5, 12),
      child: Row(
        children: [
          _StatusIcon(running: item.status.isRunning),
          UIs.width13,
          Expanded(child: _ContainerIdentity(item: item, showStatus: false)),
          if (hasStats) ...[
            _MetricColumn(label: 'CPU', value: item.cpu, width: 90),
            _MetricColumn(label: 'MEM', value: item.mem, width: 135),
            _MetricColumn(label: 'NET', value: item.net, width: 145),
            _MetricColumn(label: 'DISK', value: item.disk, width: 155),
          ],
          SizedBox(
            width: 112,
            child: Text(
              _statusLabel(item),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: UIs.text11Grey,
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 5, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _StatusIcon(running: item.status.isRunning),
              ),
              UIs.width13,
              Expanded(child: _ContainerIdentity(item: item)),
              trailing,
            ],
          ),
          if (hasStats && _hasItemStats(item)) ...[
            UIs.height13,
            Padding(
              padding: const EdgeInsets.only(left: 31, right: 10),
              child: _CompactMetricGrid(item: item),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContainerIdentity extends StatelessWidget {
  final ContainerPs item;
  final bool showStatus;

  const _ContainerIdentity({required this.item, this.showStatus = true});

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
        if (showStatus) ...[
          const SizedBox(height: 2),
          Text(
            _statusLabel(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: UIs.text11Grey,
          ),
        ],
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

class _MetricColumn extends StatelessWidget {
  final String label;
  final String? value;
  final double? width;

  const _MetricColumn({required this.label, required this.value, this.width});

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: UIs.text11Grey),
        const SizedBox(height: 2),
        Text(
          value ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: UIs.text13,
        ),
      ],
    );
    if (width == null) return child;
    return SizedBox(width: width, child: child);
  }
}

class _CompactMetricGrid extends StatelessWidget {
  final ContainerPs item;

  const _CompactMetricGrid({required this.item});

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String?)>[
      ('CPU', item.cpu),
      ('MEM', item.mem),
      ('NET', item.net),
      ('DISK', item.disk),
    ].where((e) => e.$2 != null).toList(growable: false);
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        const spacing = 13.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricColumn(label: metric.$1, value: metric.$2),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ContainerImageRow extends StatelessWidget {
  final ContainerImg image;
  final Widget trailing;

  const _ContainerImageRow({required this.image, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final id = image.id ?? _imageReference(image);
    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = constraints.maxWidth >= 760;
        return KeyedSubtree(
          key: ValueKey('image-row-${wide ? 'wide' : 'compact'}-$id'),
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
                      _imageCreatedLabel(image) ?? '—',
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
        if (!wide && _imageCreatedLabel(image) != null) ...[
          const SizedBox(height: 2),
          Text(
            _imageCreatedLabel(image)!,
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

bool _hasItemStats(ContainerPs item) =>
    item.cpu != null || item.mem != null || item.net != null || item.disk != null;

String _statusLabel(ContainerPs item) => switch (item) {
  final PodmanPs ps => ps.status.displayName,
  final DockerPs ps => ps.state ?? ps.status.displayName,
};

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

String? _imageCreatedLabel(ContainerImg image) => switch (image) {
  final DockerImg img => img.createdAt.trim().isEmpty ? null : img.createdAt,
  final PodmanImg img => _formatUnixDate(img.created),
  _ => null,
};

String? _formatUnixDate(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  final date = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
