import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:server_box/view/page/container/resource_views.dart';
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
  var _lastTabIndex = _ContainerTabs.ps.index;
  var _lastResourceTab = _ContainerTabs.ps;
  Timer? _autoRefreshTimer;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabCtrl.removeListener(_onContainerTabChanged);
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
    _tabCtrl.addListener(_onContainerTabChanged);
    _initAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshContainerTab(_ContainerTabs.ps));
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = ref.watch(
      _provider.select((state) => state.items != null),
    );

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildMain()),
      floatingActionButton: hasItems ? _buildFAB() : null,
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
          onPressed: _containerActionsBusy ? null : () => _showAddFAB(),
          child: const Icon(Icons.add),
        );
      },
    );
  }

  Widget _buildMain() {
    final containerState = _containerState;

    return Column(
      children: [
        _buildLoading(containerState),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildPsTab(containerState),
              _buildImagesTab(containerState),
              _buildSettingsTab(containerState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPsTab(ContainerState containerState) {
    if (containerState.items == null) {
      return _buildResourceLoadState(containerState, _ContainerTabs.ps);
    }
    return ContainerItemsView(
      items: containerState.items!,
      type: containerState.type,
      version: containerState.version,
      trailingBuilder: _buildMoreBtn,
      groupTrailingBuilder: _buildGroupMoreBtn,
      emptyState: _buildEmptyStateMessage(containerState),
      summaryAction: _buildResourceActions(
        pruneAction: _buildPruneAction(
          key: const ValueKey('prune-containers-button'),
          label: '${libL10n.prune} ${libL10n.container}',
          onPressed: _containerActionsBusy
              ? null
              : () => _showPruneDialog(
                  title: libL10n.container,
                  onConfirm: _containerNotifier.pruneContainers,
                ),
        ),
        refreshKey: const ValueKey('refresh-containers-button'),
        onRefresh: containerState.isBusy
            ? null
            : () => _refreshContainerTab(
                _ContainerTabs.ps,
                showLoading: true,
              ),
      ),
    );
  }

  Widget _buildImagesTab(ContainerState containerState) {
    if (containerState.images == null) {
      return _buildResourceLoadState(containerState, _ContainerTabs.images);
    }
    return ContainerImagesView(
      images: containerState.images!,
      type: containerState.type,
      version: containerState.version,
      trailingBuilder: _buildImageMoreBtn,
      summaryAction: _buildResourceActions(
        pruneAction: _buildPruneAction(
          key: const ValueKey('prune-images-button'),
          label: '${libL10n.prune} ${l10n.image}',
          onPressed: _containerActionsBusy ? null : _showImagePruneDialog,
        ),
        refreshKey: const ValueKey('refresh-images-button'),
        onRefresh: containerState.isBusy
            ? null
            : () => _refreshContainerTab(
                _ContainerTabs.images,
                showLoading: true,
              ),
      ),
    );
  }

  Widget _buildResourceLoadState(
    ContainerState containerState,
    _ContainerTabs tab,
  ) {
    final error = containerState.error;
    if (error == null) return UIs.centerLoading;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(23),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 37),
            UIs.height13,
            Text(error.toString(), textAlign: TextAlign.center),
            UIs.height13,
            OutlinedButton.icon(
              onPressed: containerState.isBusy
                  ? null
                  : () => _refreshContainerTab(tab, showLoading: true),
              icon: const Icon(Icons.refresh),
              label: Text(libL10n.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceActions({
    required Widget pruneAction,
    required Key refreshKey,
    required VoidCallback? onRefresh,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pruneAction,
        IconButton(
          key: refreshKey,
          tooltip: libL10n.refresh,
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildPruneAction({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: label,
      onPressed: onPressed,
      icon: const Icon(Icons.cleaning_services_outlined),
    );
  }

  Widget _buildSettingsTab(ContainerState containerState) {
    return AutoMultiList(
      children: <Widget>[
        ..._SettingsMenuItems.values.map(
          (item) => _buildSettingCard(item, containerState),
        ),
        ..._PruneTypes.values.map(_buildPruneCard),
      ],
    );
  }

  Widget? _buildEmptyStateMessage(ContainerState containerState) {
    final emptyPs = containerState.items?.isEmpty ?? true;
    if (emptyPs && containerState.runLog == null) {
      return CardX(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 17, 17, 7),
          child: SimpleMarkdown(data: l10n.dockerEmptyRunningItems),
        ),
      );
    }
    return null;
  }

  Widget _buildImageMoreBtn(ContainerImg image) {
    if (_containerActionsBusy) return _buildDisabledMoreBtn();
    return PopupMenu<ImageMenu>(
      items: ImageMenu.items
          .map((e) => PopMenu.build(e, e.icon, e.toStr))
          .toList(),
      onSelected: (item) => _onTapImageMenu(item, image),
    );
  }

  Widget _buildLoading(ContainerState containerState) {
    if (containerState.runLog == null) return UIs.placeholder;
    return ContainerRunLogView(log: containerState.runLog!);
  }

  Widget? _buildGroupMoreBtn(List<ContainerPs> groupItems) {
    final project = groupItems.firstOrNull?.project;
    if (project == null) return null;
    if (_containerActionsBusy) return _buildDisabledMoreBtn();
    final hasWorkingDir = groupItems.any(
      (e) => e.workingDir?.isNotEmpty ?? false,
    );
    return PopupMenu(
      items: ContainerGroupMenu.items(
        anyRunning: groupItems.any((e) => e.status.isRunning),
        anyStopped: groupItems.any((e) => e.status.isStopped),
      )
          .where((e) => e != ContainerGroupMenu.logs || hasWorkingDir)
          .map((e) => PopMenu.build(e, e.icon, e.toStr))
          .toList(),
      onSelected: (item) => _onTapGroupMenu(item, groupItems),
    );
  }

  void _onTapGroupMenu(ContainerGroupMenu item, List<ContainerPs> groupItems) {
    final runningIds = groupItems
        .where((e) => e.status.isRunning)
        .map((e) => e.id)
        .whereType<String>()
        .toList();
    final stoppedIds = groupItems
        .where((e) => e.status.isStopped)
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

  Widget _buildMoreBtn(ContainerPs dItem) {
    if (_containerActionsBusy) return _buildDisabledMoreBtn();
    return PopupMenu(
      items: ContainerMenu.items(
        dItem.status,
      ).map((e) => PopMenu.build(e, e.icon, e.toStr)).toList(),
      onSelected: (item) => _onTapMoreBtn(item, dItem),
    );
  }

  Widget _buildDisabledMoreBtn() {
    return const IconButton(onPressed: null, icon: Icon(Icons.more_vert));
  }

  Widget _buildPruneCard(_PruneTypes type) {
    final title = type.label;
    final containerNotifier = _containerNotifier;
    return CardX(
      child: ListTile(
        key: ValueKey('container-setting-prune-${type.name}'),
        leading: Icon(type.icon),
        onTap: _containerActionsBusy ? null : () async {
          switch (type) {
            case _PruneTypes.volumes:
              await _showPruneDialog(
                title: title,
                onConfirm: containerNotifier.pruneVolumes,
              );
              break;
            case _PruneTypes.unusedData:
              await _showSystemPruneDialog();
              break;
          }
        },
        title: Text(title),
        trailing: const Icon(Icons.keyboard_arrow_right),
      ),
    );
  }

  Widget _buildSettingCard(
    _SettingsMenuItems item,
    ContainerState containerState,
  ) {
    return CardX(
      child: _buildSettingTile(item, containerState),
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
      key: ValueKey('container-setting-${item.name}'),
      leading: Icon(item.icon),
      onTap: _containerActionsBusy ? null : () {
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
            unawaited(_refreshContainerTab(_lastResourceTab));
            break;
        }
      },
      title: Text(title),
      trailing: const Icon(Icons.keyboard_arrow_right),
    );
  }
}
