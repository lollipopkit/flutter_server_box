import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/menu/base.dart';
import 'package:server_box/data/model/app/menu/container.dart';
import 'package:server_box/data/model/app/menu/image.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

part 'actions.dart';
part 'types.dart';

class ContainerPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;
  const ContainerPage({required this.args, super.key});

  @override
  ConsumerState<ContainerPage> createState() => _ContainerPageState();

  static const route = AppRouteArg(page: ContainerPage.new, path: '/container');
}

class _ContainerPageState extends ConsumerState<ContainerPage>
    with SingleTickerProviderStateMixin {
  late final ContainerNotifierProvider _provider;
  late final _tabCtrl = TabController(
    length: _ContainerTabs.values.length,
    vsync: this,
  );
  Timer? _autoRefreshTimer;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final serverState = ref.read(serverProvider(widget.args.spi.id));
    _provider = containerProvider(
      serverState.client,
      widget.args.spi.user,
      widget.args.spi.id,
      context,
    );
    _initAutoRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final err = ref.watch(_provider.select((p) => p.error));

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildMain()),
      floatingActionButton: err == null ? _buildFAB() : null,
    );
  }

  CustomAppBar _buildAppBar() {
    return CustomAppBar(
      centerTitle: true,
      title: TwoLineText(up: libL10n.container, down: widget.args.spi.name),
      bottom: TabBar(
        controller: _tabCtrl,
        dividerHeight: 0,
        tabAlignment: TabAlignment.center,
        isScrollable: true,
        tabs: _ContainerTabs.values
            .map((e) => Tab(text: e.i18n))
            .toList(growable: false),
      ),
      actions: [
        IconButton(
          onPressed: () =>
              context.showLoadingDialog(fn: () => _containerNotifier.refresh()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return ListenableBuilder(
      listenable: _tabCtrl,
      builder: (_, _) {
        if (_tabCtrl.index != _ContainerTabs.ps.index) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton(
          onPressed: () => _showAddFAB(),
          child: const Icon(Icons.add),
        );
      },
    );
  }

  Widget _buildMain() {
    final containerState = _containerState;

    if (containerState.error != null && containerState.items == null) {
      return SizedBox.expand(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.error, size: 37),
            UIs.height13,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 23),
              child: Text(containerState.error.toString()),
            ),
            const Spacer(),
            UIs.height13,
            _buildSettingsCard(containerState),
          ],
        ).paddingSymmetric(horizontal: 13),
      );
    }
    if (containerState.items == null || containerState.images == null) {
      return UIs.centerLoading;
    }

    return Column(
      children: [
        _buildLoading(containerState),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildPsTab(containerState),
              _buildImagesTab(containerState),
              _buildPruneTab(containerState),
              _buildSettingsTab(containerState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPsTab(ContainerState containerState) {
    return AutoMultiList(
      children: <Widget>[
        _buildVersion(containerState),
        _buildPs(containerState),
        _buildEmptyStateMessage(containerState),
      ],
    );
  }

  Widget _buildImagesTab(ContainerState containerState) {
    return AutoMultiList(
      children: <Widget>[
        _buildImage(containerState),
      ],
    );
  }

  Widget _buildPruneTab(ContainerState containerState) {
    return AutoMultiList(
      children: <Widget>[
        _buildPruneCard(),
      ],
    );
  }

  Widget _buildSettingsTab(ContainerState containerState) {
    return AutoMultiList(
      children: <Widget>[
        _buildSettingsCard(containerState),
      ],
    );
  }

  Widget _buildEmptyStateMessage(ContainerState containerState) {
    final emptyImgs = containerState.images?.isEmpty ?? true;
    final emptyPs = containerState.items?.isEmpty ?? true;
    if (emptyPs && emptyImgs && containerState.runLog == null) {
      return CardX(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 17, 17, 7),
          child: SimpleMarkdown(data: l10n.dockerEmptyRunningItems),
        ),
      );
    }
    return UIs.placeholder;
  }

  Widget _buildImage(ContainerState containerState) {
    final images = containerState.images ?? [];
    final unused = images.where((e) => e.isUnused).length;
    final summary = unused > 0
        ? '${l10n.dockerImagesFmt(images.length)} · $unused ${l10n.unused}'
        : l10n.dockerImagesFmt(images.length);
    return ExpandTile(
      leading: const Icon(MingCute.clapperboard_line),
      title: Text(summary),
      initiallyExpanded: images.length <= 3,
      children: images.map(_buildImageItem).toList(),
    ).cardx;
  }

  Widget _buildImageItem(ContainerImg e) {
    final repoSplited = e.repository?.split('/');
    final title = repoSplited?.lastOrNull ?? e.repository;
    repoSplited?.removeLast();
    final reg = repoSplited?.join('/');
    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(title ?? l10n.unknown, style: UIs.text15)),
          if (e.isDangling) _buildImageBadge(l10n.dangling),
          if (e.isUnused && !e.isDangling) _buildImageBadge(l10n.unused),
        ],
      ),
      subtitle: Text(
        '${reg ?? ''} - ${e.tag ?? l10n.unknown} - ${e.sizeMB ?? l10n.unknown}',
        style: UIs.text13Grey,
      ),
      trailing: PopupMenu<ImageMenu>(
        items: ImageMenu.items
            .map((e) => PopMenu.build(e, e.icon, e.toStr))
            .toList(),
        onSelected: (item) => _onTapImageMenu(item, e),
      ),
    );
  }

  Widget _buildImageBadge(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 7),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: UIs.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: UIs.text11.copyWith(
          color: UIs.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoading(ContainerState containerState) {
    if (containerState.runLog == null) return UIs.placeholder;
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          const Center(child: CircularProgressIndicator()),
          UIs.height13,
          Text(containerState.runLog!),
        ],
      ),
    );
  }

  Widget _buildVersion(ContainerState containerState) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(containerState.type.name.capitalize),
            Text(containerState.version ?? l10n.unknown),
          ],
        ),
      ),
    );
  }

  Widget _buildPs(ContainerState containerState) {
    final items = containerState.items;
    if (items == null) return UIs.placeholder;
    final running = items.where((e) => e.status.isRunning).length;
    final stopped = items.length - running;
    final summary = stopped > 0
        ? l10n.dockerStatusRunningAndStoppedFmt(running, stopped)
        : l10n.dockerStatusRunningFmt(running);
    return ExpandTile(
      leading: const Icon(OctIcons.container, size: 22),
      title: Text(summary),
      initiallyExpanded: items.length < 7,
      children: _buildGroupedPsItems(items),
    ).cardx;
  }

  List<Widget> _buildGroupedPsItems(List<ContainerPs> items) {
    final grouped = <String?, List<ContainerPs>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.project, () => []).add(item);
    }
    if (grouped.length <= 1 && grouped[null] != null) {
      return items.map(_buildPsItem).toList();
    }
    final result = <Widget>[];
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        final lowerCmp = a.toLowerCase().compareTo(b.toLowerCase());
        if (lowerCmp != 0) return lowerCmp;
        return a.compareTo(b);
      });
    for (final key in keys) {
      if (result.isNotEmpty) result.add(const Divider(height: 1));
      final groupItems = grouped[key]!;
      result.add(
        _buildPsGroupHeader(key ?? l10n.dockerProjectOther, groupItems),
      );
      result.addAll(groupItems.map(_buildPsItem));
    }
    return result;
  }

  Widget _buildPsGroupHeader(String title, List<ContainerPs> groupItems) {
    final project = groupItems.firstOrNull?.project;
    final hasWorkingDir = groupItems.any(
      (e) => e.workingDir?.isNotEmpty ?? false,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 7, 7, 0),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 15, color: Colors.grey),
          UIs.width7,
          Expanded(
            child: Text(title, style: UIs.text13Grey),
          ),
          if (project != null)
            PopupMenu(
              items: ContainerGroupMenu.items(
                anyRunning: groupItems.any((e) => e.status.isRunning),
                anyStopped: groupItems.any((e) => !e.status.isRunning),
              )
                  .where((e) => e != ContainerGroupMenu.logs || hasWorkingDir)
                  .map((e) => PopMenu.build(e, e.icon, e.toStr))
                  .toList(),
              onSelected: (item) => _onTapGroupMenu(item, groupItems),
            ),
        ],
      ),
    );
  }

  void _onTapGroupMenu(ContainerGroupMenu item, List<ContainerPs> groupItems) {
    final runningIds = groupItems
        .where((e) => e.status.isRunning)
        .map((e) => e.id)
        .whereType<String>()
        .toList();
    final stoppedIds = groupItems
        .where((e) => !e.status.isRunning)
        .map((e) => e.id)
        .whereType<String>()
        .toList();
    switch (item) {
      case ContainerGroupMenu.start:
        if (stoppedIds.isEmpty) {
          context.showSnackBar(libL10n.empty);
          return;
        }
        _execContainerAction(() => _containerNotifier.startAll(stoppedIds));
        break;
      case ContainerGroupMenu.stop:
        if (runningIds.isEmpty) {
          context.showSnackBar(libL10n.empty);
          return;
        }
        _execContainerAction(() => _containerNotifier.stopAll(runningIds));
        break;
      case ContainerGroupMenu.restart:
        if (runningIds.isEmpty) {
          context.showSnackBar(libL10n.empty);
          return;
        }
        _execContainerAction(() => _containerNotifier.restartAll(runningIds));
        break;
      case ContainerGroupMenu.logs:
        final project = groupItems.firstOrNull?.project;
        if (project == null) return;
        final workingDir = _mostCommonWorkingDir(groupItems);
        if (workingDir == null) return;
        _openMergedLogs(project, workingDir);
        break;
    }
  }

  String? _mostCommonWorkingDir(List<ContainerPs> groupItems) {
    final counts = <String, int>{};
    for (final e in groupItems) {
      final dir = e.workingDir;
      if (dir == null || dir.isEmpty) continue;
      counts[dir] = (counts[dir] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    ).key;
  }

  Widget _buildPsItem(ContainerPs item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.name ?? l10n.unknown, style: UIs.text15),
              _buildMoreBtn(item),
            ],
          ),
          Text(
            '${item.image ?? l10n.unknown} - ${switch (item) {
              final PodmanPs ps => ps.status.displayName,
              final DockerPs ps => ps.state ?? ps.status.displayName,
            }}',
            style: UIs.text13Grey,
          ),
          _buildPsItemStats(item),
        ],
      ),
    );
  }

  Widget _buildPsItemStats(ContainerPs item) {
    if (item.cpu == null || item.mem == null) return UIs.placeholder;
    return LayoutBuilder(
      builder: (_, cons) {
        final width = cons.maxWidth / 2 - 6.5;
        return Column(
          children: [
            UIs.height13,
            Row(
              children: [
                _buildPsItemStatsItem(
                  'CPU',
                  item.cpu,
                  Icons.memory,
                  width: width,
                ),
                UIs.width13,
                _buildPsItemStatsItem(
                  'Net',
                  item.net,
                  Icons.network_cell,
                  width: width,
                ),
              ],
            ),
            Row(
              children: [
                _buildPsItemStatsItem(
                  'Mem',
                  item.mem,
                  Icons.settings_input_component,
                  width: width,
                ),
                UIs.width13,
                _buildPsItemStatsItem(
                  'Disk',
                  item.disk,
                  Icons.storage,
                  width: width,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPsItemStatsItem(
    String title,
    String? value,
    IconData icon, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.grey),
              UIs.width7,
              Expanded(
                child: Text(
                  value ?? l10n.unknown,
                  style: UIs.text11Grey,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoreBtn(ContainerPs dItem) {
    return PopupMenu(
      items: ContainerMenu.items(
        dItem.status.isRunning,
      ).map((e) => PopMenu.build(e, e.icon, e.toStr)).toList(),
      onSelected: (item) => _onTapMoreBtn(item, dItem),
    );
  }

  String _buildAddCmd(String image, String name, String args) {
    var suffix = '';
    if (args.isEmpty) {
      suffix = image;
    } else {
      suffix = '$args $image';
    }
    if (name.isEmpty) {
      return 'run -itd $suffix';
    }
    return 'run -itd --name $name $suffix';
  }

  Widget _buildPruneCard() {
    return CardX(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(
              libL10n.prune,
              style: UIs.text15,
            ),
            subtitle: Text(l10n.dockerPruneTip, style: UIs.text13Grey),
          ),
          const Divider(height: 1),
          ..._PruneTypes.values.map(_buildPruneBtn),
        ],
      ),
    );
  }

  Widget _buildPruneBtn(_PruneTypes type) {
    final title = type.label;
    final containerNotifier = _containerNotifier;
    return ListTile(
      onTap: () async {
        if (type == _PruneTypes.images) {
          await _showImagePruneDialog();
          return;
        }
        await _showPruneDialog(
          title: title,
          message: type.tip,
          onConfirm: switch (type) {
            _PruneTypes.containers => containerNotifier.pruneContainers,
            _PruneTypes.volumes => containerNotifier.pruneVolumes,
            _PruneTypes.system => containerNotifier.pruneSystem,
            _PruneTypes.images => () => containerNotifier.pruneImages(),
          },
        );
      },
      title: Text(title),
      trailing: const Icon(Icons.keyboard_arrow_right),
    );
  }

  Widget _buildSettingsCard(ContainerState containerState) {
    return CardX(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(libL10n.setting, style: UIs.text15),
          ),
          const Divider(height: 1),
          ..._SettingsMenuItems.values
              .map((item) => _buildSettingTile(item, containerState)),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    _SettingsMenuItems item,
    ContainerState containerState,
  ) {
    final String title;
    switch (item) {
      case _SettingsMenuItems.editContainerHost:
        final hostVariable = containerState.type == ContainerType.podman
            ? 'CONTAINER_HOST'
            : 'DOCKER_HOST';
        title = '${libL10n.edit} $hostVariable';
        break;
      case _SettingsMenuItems.switchProvider:
        title = containerState.type == ContainerType.podman
            ? l10n.switchTo('Docker')
            : l10n.switchTo('Podman');
        break;
    }
    return ListTile(
      onTap: () {
        switch (item) {
          case _SettingsMenuItems.editContainerHost:
            _showEditHostDialog();
            break;
          case _SettingsMenuItems.switchProvider:
            ref
                .read(_provider.notifier)
                .setType(
                  containerState.type == ContainerType.docker
                      ? ContainerType.podman
                      : ContainerType.docker,
                );
            break;
        }
      },
      title: Text(title),
      trailing: const Icon(Icons.keyboard_arrow_right),
    );
  }
}
