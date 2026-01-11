import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/menu/base.dart';
import 'package:server_box/data/model/app/menu/container.dart';
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

class _ContainerPageState extends ConsumerState<ContainerPage> {
  final _textController = TextEditingController();
  late final ContainerNotifierProvider _provider;

  @override
  void dispose() {
    super.dispose();
    _textController.dispose();
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
    final errors = ref.watch(_provider.select((p) => p.errors));

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildMain()),
      floatingActionButton: errors.isEmpty ? _buildFAB() : null,
    );
  }

  CustomAppBar _buildAppBar() {
    return CustomAppBar(
      centerTitle: true,
      title: TwoLineText(up: l10n.container, down: widget.args.spi.name),
      actions: [
        IconButton(
          onPressed: () => context.showLoadingDialog(fn: () => _containerNotifier.refresh()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(onPressed: () async => await _showAddFAB(), child: const Icon(Icons.add));
  }

  Widget _buildMain() {
    final containerState = _containerState;

    if (containerState.errors.isNotEmpty && containerState.items == null) {
      return SizedBox.expand(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.error, size: 37),
            UIs.height13,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 23),
              child: Text(containerState.errors.map((e) => e.toString()).join('\n')),
            ),
            const Spacer(),
            UIs.height13,
            _buildSettingsBtns,
          ],
        ).paddingSymmetric(horizontal: 13),
      );
    }
    if (containerState.items == null || containerState.images == null) {
      return UIs.centerLoading;
    }

    return AutoMultiList(
      children: <Widget>[
        _buildLoading(containerState),
        _buildVersion(containerState),
        _buildPs(containerState),
        _buildImage(containerState),
        _buildEmptyStateMessage(containerState),
        _buildPruneBtns,
        _buildSettingsBtns,
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
    return ExpandTile(
      leading: const Icon(MingCute.clapperboard_line),
      title: Text(l10n.imagesList),
      subtitle: Text(l10n.dockerImagesFmt(containerState.images?.length ?? 'null'), style: UIs.textGrey),
      initiallyExpanded: (containerState.images?.length ?? 0) <= 3,
      children: containerState.images?.map(_buildImageItem).toList() ?? [],
    ).cardx;
  }

  Widget _buildImageItem(ContainerImg e) {
    final repoSplited = e.repository?.split('/');
    final title = repoSplited?.lastOrNull ?? e.repository;
    repoSplited?.removeLast();
    final reg = repoSplited?.join('/');
    return ListTile(
      title: Text(title ?? l10n.unknown, style: UIs.text15),
      subtitle: Text('${reg ?? ''} - ${e.tag} - ${e.sizeMB}', style: UIs.text13Grey),
      trailing: Btn.icon(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.delete),
        onTap: () => _showImageRmDialog(e),
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
          Text(containerState.runLog ?? '...'),
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
          children: [Text(containerState.type.name.capitalize), Text(containerState.version ?? l10n.unknown)],
        ),
      ),
    );
  }

  Widget _buildPs(ContainerState containerState) {
    final items = containerState.items;
    if (items == null) return UIs.placeholder;
    final running = items.where((e) => e.status.isRunning).length;
    final stopped = items.length - running;
    final subtitle = stopped > 0
        ? l10n.dockerStatusRunningAndStoppedFmt(running, stopped)
        : l10n.dockerStatusRunningFmt(running);
    return ExpandTile(
      leading: const Icon(OctIcons.container, size: 22),
      title: Text(l10n.container),
      subtitle: Text(subtitle, style: UIs.textGrey),
      initiallyExpanded: items.length < 7,
      children: items.map(_buildPsItem).toList(),
    ).cardx;
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
              const SizedBox(height: 3),
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
        final width = cons.maxWidth / 2 - 41;
        return Column(
          children: [
            UIs.height13,
            Row(
              children: [
                _buildPsItemStatsItem('CPU', item.cpu, Icons.memory, width: width),
                UIs.width13,
                _buildPsItemStatsItem('Net', item.net, Icons.network_cell, width: width),
              ],
            ),
            Row(
              children: [
                _buildPsItemStatsItem('Mem', item.mem, Icons.settings_input_component, width: width),
                UIs.width13,
                _buildPsItemStatsItem('Disk', item.disk, Icons.storage, width: width),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPsItemStatsItem(String title, String? value, IconData icon, {required double width}) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey),
              UIs.width7,
              Text(value ?? l10n.unknown, style: UIs.text11Grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoreBtn(ContainerPs dItem) {
    return PopupMenu(
      items: ContainerMenu.items(dItem.status.isRunning).map((e) => PopMenu.build(e, e.icon, e.toStr)).toList(),
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

  Widget get _buildPruneBtns {
    final len = _PruneTypes.values.length;
    if (len == 0) return UIs.placeholder;
    return ExpandTile(
      leading: const Icon(Icons.delete),
      title: Text(l10n.prune),
      children: _PruneTypes.values.map(_buildPruneBtn).toList(),
    ).cardx;
  }

  Widget _buildPruneBtn(_PruneTypes type) {
    final title = type.name.capitalize;
    final containerNotifier = _containerNotifier;
    return ListTile(
      onTap: () async {
        await _showPruneDialog(
          title: title,
          message: type.tip,
          onConfirm: switch (type) {
            _PruneTypes.images => containerNotifier.pruneImages,
            _PruneTypes.containers => containerNotifier.pruneContainers,
            _PruneTypes.volumes => containerNotifier.pruneVolumes,
            _PruneTypes.system => containerNotifier.pruneSystem,
          },
        );
      },
      title: Text(title),
      trailing: const Icon(Icons.keyboard_arrow_right),
    );
  }

  Widget get _buildSettingsBtns {
    final len = _SettingsMenuItems.values.length;
    if (len == 0) return UIs.placeholder;
    final containerState = _containerState;

    return ExpandTile(
      leading: const Icon(Icons.settings),
      title: Text(libL10n.setting),
      initiallyExpanded: containerState.errors.isNotEmpty,
      children: _SettingsMenuItems.values.map((item) => _buildSettingTile(item, containerState)).toList(),
    ).cardx;
  }

  Widget _buildSettingTile(_SettingsMenuItems item, ContainerState containerState) {
    final String title;
    switch (item) {
      case _SettingsMenuItems.editDockerHost:
        title = '${libL10n.edit} DOCKER_HOST';
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
          case _SettingsMenuItems.editDockerHost:
            _showEditHostDialog();
            break;
          case _SettingsMenuItems.switchProvider:
            ref
                .read(_provider.notifier)
                .setType(
                  containerState.type == ContainerType.docker ? ContainerType.podman : ContainerType.docker,
                );
            break;
        }
      },
      title: Text(title),
      trailing: const Icon(Icons.keyboard_arrow_right),
    );
  }
}
