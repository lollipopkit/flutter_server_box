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
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
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
    _provider = containerProvider(
      widget.args.spi.ssh?.user ?? '',
      widget.args.spi.id,
      context,
    );
    _tabCtrl.addListener(_onContainerTabChanged);
    _initAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshContainerTab(_ContainerTabs.ps));
      // Started beside the list rather than before it: `system df` walks the
      // whole image store, and the two numbers it feeds are not worth holding
      // the page for.
      unawaited(_containerNotifier.refreshDiskUsage());
    });
  }

  @override
  Widget build(BuildContext context) => _buildPage();
}

extension _ContainerPageWidgets on _ContainerPageState {
  Widget _buildPage() {
    // Read once here: everything below runs inside this element's build, and
    // the tab-driven parts are rebuilt by a ListenableBuilder that must not
    // reach for `ref` of its own.
    final containerState = _containerState;
    final busy = _containerActionsBusy;

    return Scaffold(
      appBar: _buildAppBar(busy),
      body: SafeArea(child: _buildMain(containerState)),
    );
  }

  CustomAppBar _buildAppBar(bool busy) {
    return CustomAppBar(
      title: TwoLineText(up: libL10n.container, down: widget.args.spi.name),
      actions: [
        ListenableBuilder(
          listenable: _tabCtrl,
          builder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildBarActions(busy),
          ),
        ),
      ],
    );
  }

  /// What is done *to* the runtime, for the tab that is showing.
  ///
  /// Add lives here rather than in a floating button: the button covered the
  /// last card in a two-column grid, and on this page it is one of four
  /// actions that belong together rather than the page's single purpose.
  List<Widget> _buildBarActions(bool busy) {
    final tab = _ContainerTabs.values[_tabCtrl.index];
    return switch (tab) {
      _ContainerTabs.ps => [
        _barBtn(
          key: const ValueKey('prune-containers-button'),
          icon: Icons.cleaning_services_outlined,
          tooltip: '${libL10n.prune} ${libL10n.container}',
          onTap: busy
              ? null
              : () => _showPruneDialog(
                  title: libL10n.container,
                  onConfirm: _containerNotifier.pruneContainers,
                ),
        ),
        _barBtn(
          key: const ValueKey('refresh-containers-button'),
          icon: Icons.refresh,
          tooltip: libL10n.refresh,
          onTap: busy ? null : () => _refreshResourcesAndUsage(_ContainerTabs.ps),
        ),
        _barBtn(
          key: const ValueKey('add-container-button'),
          icon: Icons.add,
          tooltip: libL10n.add,
          emphasized: true,
          onTap: busy ? null : () => _showAddFAB(),
        ),
      ],
      _ContainerTabs.images => [
        _barBtn(
          key: const ValueKey('prune-images-button'),
          icon: Icons.cleaning_services_outlined,
          tooltip: '${libL10n.prune} ${l10n.image}',
          onTap: busy ? null : _showImagePruneDialog,
        ),
        _barBtn(
          key: const ValueKey('refresh-images-button'),
          icon: Icons.refresh,
          tooltip: libL10n.refresh,
          onTap: busy
              ? null
              : () => _refreshResourcesAndUsage(_ContainerTabs.images),
        ),
      ],
      _ContainerTabs.settings => const [],
    };
  }

  Widget _barBtn({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool emphasized = false,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 18,
        color: emphasized ? context.theme.colorScheme.primary : null,
      ),
    );
  }

  Widget _buildMain(ContainerState containerState) {
    return Column(
      children: [
        _buildLoading(containerState),
        ContainerGutter(
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: ContainerRuntimeHeader(
              type: containerState.type,
              version: containerState.version,
              summary: _summaryLine(containerState, compact: false),
              compactSummary: _summaryLine(containerState, compact: true),
              selector: _buildSelector,
            ),
          ),
        ),
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

  /// `3 running · 1 stopped · 12 images · 809 MB`.
  ///
  /// A total that has not been measured is left out rather than printed as a
  /// zero: `system df` answers after the list does, and a zero that means
  /// "not asked yet" is the one number worth never showing.
  String _summaryLine(ContainerState containerState, {required bool compact}) {
    final items = containerState.items;
    final running = items?.where((e) => e.status.isRunning).length;
    final stopped = items?.where((e) => e.status.isStopped).length;
    final unknown = items
        ?.where((e) => e.status == ContainerStatus.unknown)
        .length;
    final imageCount =
        containerState.diskUsage?.imageCount ?? containerState.images?.length;
    final reclaimable = containerState.diskUsage?.reclaimableBytes;

    return [
      // The version is the title's neighbour on one line, and folds into this
      // one when the header stacks.
      if (compact) containerState.version ?? libL10n.unknown,
      if (running != null) '$running ${libL10n.running}',
      if (stopped != null && stopped > 0) '$stopped ${libL10n.stopped}',
      if (unknown != null && unknown > 0) '$unknown ${libL10n.unknown}',
      // Dropped when the line folds: the least urgent two, and the two the
      // Image tab says again.
      if (!compact && imageCount != null) '$imageCount ${l10n.image}',
      if (!compact && reclaimable != null)
        '${reclaimable.bytes2Str} ${l10n.containerReclaimable}',
    ].join(' · ');
  }

  Widget _buildSelector(bool expand) {
    return ListenableBuilder(
      listenable: _tabCtrl,
      builder: (_, _) => SegmentedTabs<_ContainerTabs>(
        expand: expand,
        segments: _ContainerTabs.values
            .map((tab) => SegmentedTab(value: tab, label: tab.i18n))
            .toList(growable: false),
        selected: _ContainerTabs.values[_tabCtrl.index],
        onSelected: (tab) => _tabCtrl.animateTo(tab.index),
      ),
    );
  }

  Widget _buildPsTab(ContainerState containerState) {
    if (containerState.items == null) {
      return _buildResourceLoadState(containerState, _ContainerTabs.ps);
    }
    return ContainerItemsView(
      items: containerState.items!,
      trailingBuilder: _buildMoreBtn,
      emptyState: _buildEmptyStateMessage(containerState),
      onQuickAction: _containerActionsBusy ? null : _onTapMoreBtn,
    );
  }

  Widget _buildImagesTab(ContainerState containerState) {
    if (containerState.images == null) {
      return _buildResourceLoadState(containerState, _ContainerTabs.images);
    }
    return ContainerImagesView(
      images: containerState.images!,
      trailingBuilder: _buildImageMoreBtn,
    );
  }

  /// A manual refresh takes the disk usage with it: it is the one moment the
  /// user has asked for current numbers, and the overview's two slots are as
  /// stale as the list was.
  Future<void> _refreshResourcesAndUsage(_ContainerTabs tab) async {
    unawaited(_containerNotifier.refreshDiskUsage());
    await _refreshContainerTab(tab, showLoading: true);
  }

  Widget _buildResourceLoadState(
    ContainerState containerState,
    _ContainerTabs tab,
  ) {
    final error = switch (tab) {
      _ContainerTabs.ps => containerState.containersError,
      _ContainerTabs.images => containerState.imagesError,
      _ContainerTabs.settings => null,
    };
    if (error == null) return UIs.centerLoading;
    return PageIssueView(
      title: error.title,
      explain: error.solution,
      // The runtime's own words, kept out of the headline: it is what makes a
      // "not installed" that is really a `DOCKER_HOST` problem diagnosable,
      // and it is noise for anyone who only wanted to know why the list is
      // empty.
      detail: error.message,
      icon: error.type == ContainerErrType.notInstalled
          ? Icons.help_outline
          : Icons.error_outline,
      onRetry: _containerActionsBusy
          ? null
          : () => _refreshContainerTab(tab, showLoading: true),
    );
  }

  Widget _buildSettingsTab(ContainerState containerState) {
    return PageColumns(
      children: <Widget>[
        CardX(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._SettingsMenuItems.values.map(
                (item) => _buildSettingTile(item, containerState),
              ),
              ..._PruneTypes.values.map(_buildPruneTile),
            ],
          ),
        ),
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
    return IgnorePointer(
      ignoring: _containerActionsBusy,
      child: PopupMenu<ImageMenu>(
        items: ImageMenu.items
            .map((e) => PopMenu.build(e, e.icon, e.toStr))
            .toList(),
        onSelected: (item) => _onTapImageMenu(item, image),
      ),
    );
  }

  Widget _buildLoading(ContainerState containerState) {
    if (containerState.runLog == null) return UIs.placeholder;
    return ContainerRunLogView(log: containerState.runLog!);
  }

  Widget _buildMoreBtn(ContainerPs dItem) {
    return IgnorePointer(
      ignoring: _containerActionsBusy,
      child: PopupMenu(
        items: ContainerMenu.items(
          dItem.status,
        ).map((e) => PopMenu.build(e, e.icon, e.toStr)).toList(),
        onSelected: (item) => _onTapMoreBtn(item, dItem),
      ),
    );
  }

  Widget _buildPruneTile(_PruneTypes type) {
    final title = type.label;
    final containerNotifier = _containerNotifier;
    return ListTile(
      visualDensity: VisualDensity.compact,
      key: ValueKey('container-setting-prune-${type.name}'),
      leading: Icon(type.icon),
      onTap: _containerActionsBusy
          ? null
          : () async {
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
      visualDensity: VisualDensity.compact,
      key: ValueKey('container-setting-${item.name}'),
      leading: Icon(item.icon),
      onTap: _containerActionsBusy
          ? null
          : () {
              switch (item) {
                case _SettingsMenuItems.editContainerHost:
                  _showEditHostDialog();
                  break;
                case _SettingsMenuItems.switchProvider:
                  final changed = ref
                      .read(_provider.notifier)
                      .setType(
                        containerState.type == ContainerType.docker
                            ? ContainerType.podman
                            : ContainerType.docker,
                      );
                  if (changed) {
                    unawaited(_refreshContainerTab(_lastResourceTab));
                  }
                  break;
              }
            },
      title: Text(title),
      trailing: const Icon(Icons.keyboard_arrow_right),
    );
  }
}

