import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/menu/base.dart';
import 'package:server_box/data/model/app/menu/container.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/store.dart';

import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/view/widget/two_line_text.dart';

class ContainerPage extends StatefulWidget {
  final Spi spi;
  const ContainerPage({required this.spi, super.key});

  @override
  State<ContainerPage> createState() => _ContainerPageState();
}

class _ContainerPageState extends State<ContainerPage> {
  final _textController = TextEditingController();
  late final _container = ContainerProvider(
    client: widget.spi.server?.value.client,
    userName: widget.spi.user,
    hostId: widget.spi.id,
    context: context,
  );
  late Size _size;

  @override
  void dispose() {
    super.dispose();
    _textController.dispose();
    _container.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _size = MediaQuery.of(context).size;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _container,
      builder: (_, __) => Consumer<ContainerProvider>(
        builder: (_, ___, __) {
          return Scaffold(
            appBar: CustomAppBar(
              centerTitle: true,
              title: TwoLineText(up: l10n.container, down: widget.spi.name),
              actions: [
                IconButton(
                  onPressed: () =>
                      context.showLoadingDialog(fn: () => _container.refresh()),
                  icon: const Icon(Icons.refresh),
                )
              ],
            ),
            body: _buildMain(),
            floatingActionButton: _container.error == null ? _buildFAB() : null,
          );
        },
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () async => await _showAddFAB(),
      child: const Icon(Icons.add),
    );
  }

  Widget _buildMain() {
    if (_container.error != null && _container.items == null) {
      return SizedBox.expand(
        child: Column(
          children: [
            const Spacer(),
            const Icon(
              Icons.error,
              size: 37,
            ),
            UIs.height13,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 23),
              child: Text(_container.error.toString()),
            ),
            const Spacer(),
            _buildEditHost(),
            _buildSwitchProvider(),
            UIs.height13,
          ],
        ),
      );
    }
    if (_container.items == null || _container.images == null) {
      return UIs.centerLoading;
    }

    return ListView(
      padding: const EdgeInsets.only(left: 13, right: 13, top: 13, bottom: 37),
      children: <Widget>[
        _buildLoading(),
        _buildVersion(),
        _buildPs(),
        _buildImage(),
        _buildEditHost(),
        _buildSwitchProvider(),
      ],
    );
  }

  Widget _buildImage() {
    return CardX(
        child: ExpandTile(
      title: Text(l10n.imagesList),
      subtitle: Text(
        l10n.dockerImagesFmt(_container.images!.length),
        style: UIs.textGrey,
      ),
      initiallyExpanded: (_container.images?.length ?? 0) <= 3,
      children: _container.images?.map(_buildImageItem).toList() ?? [],
    ));
  }

  Widget _buildImageItem(ContainerImg e) {
    return ListTile(
      title: Text(e.repository ?? l10n.unknown),
      subtitle: Text('${e.tag} - ${e.sizeMB}', style: UIs.textGrey),
      trailing: IconButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        icon: const Icon(Icons.delete),
        onPressed: () => _showImageRmDialog(e),
      ),
    );
  }

  Widget _buildLoading() {
    if (_container.runLog == null) return UIs.placeholder;
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          const Center(
            child: CircularProgressIndicator(),
          ),
          UIs.height13,
          Text(_container.runLog ?? '...'),
        ],
      ),
    );
  }

  Widget _buildVersion() {
    return CardX(
        child: Padding(
      padding: const EdgeInsets.all(17),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_container.type.name.capitalize),
          Text(_container.version ?? l10n.unknown),
        ],
      ),
    ));
  }

  Widget _buildPs() {
    final items = _container.items;
    if (items == null) return UIs.placeholder;
    return Column(
      children: items.map(_buildPsItem).toList(),
    );
  }

  Widget _buildPsItem(ContainerPs item) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
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
                final PodmanPs ps => ps.running ? l10n.running : l10n.stopped,
                final DockerPs ps => ps.state,
              }}',
              style: UIs.text13Grey,
            ),
            _buildPsItemStats(item),
          ],
        ),
      ),
    );
  }

  Widget _buildPsItemStats(ContainerPs item) {
    if (item.cpu == null || item.mem == null) return UIs.placeholder;
    return Column(
      children: [
        UIs.height13,
        Row(
          children: [
            _buildPsItemStatsItem('CPU', item.cpu, Icons.memory),
            UIs.width13,
            _buildPsItemStatsItem('Net', item.net, Icons.network_cell),
          ],
        ),
        Row(
          children: [
            _buildPsItemStatsItem(
                'Mem', item.mem, Icons.settings_input_component),
            UIs.width13,
            _buildPsItemStatsItem('Disk', item.disk, Icons.storage),
          ],
        ),
      ],
    );
  }

  Widget _buildPsItemStatsItem(String title, String? value, IconData icon) {
    return SizedBox(
      width: _size.width / 2 - 41,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey),
              UIs.width7,
              Text(value ?? l10n.unknown, style: UIs.text11Grey),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMoreBtn(ContainerPs dItem) {
    return PopupMenu(
      items: ContainerMenu.items(dItem.running)
          .map((e) => PopMenu.build(e, e.icon, e.toStr))
          .toList(),
      onSelected: (item) => _onTapMoreBtn(item, dItem),
    );
  }

  // String _buildPsCardSubtitle(List<ContainerPs> running) {
  //   final runningCount = running.where((element) => element.running).length;
  //   final stoped = running.length - runningCount;
  //   if (stoped == 0) {
  //     return l10n.dockerStatusRunningFmt(runningCount);
  //   }
  //   return l10n.dockerStatusRunningAndStoppedFmt(runningCount, stoped);
  // }

  Widget _buildEditHost() {
    final children = <Widget>[];
    final emptyImgs = _container.images?.isEmpty ?? false;
    final emptyPs = _container.items?.isEmpty ?? false;
    if (emptyPs && emptyImgs) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
        child: SimpleMarkdown(data: l10n.dockerEmptyRunningItems),
      ));
    }
    children.add(
      TextButton(
        onPressed: _showEditHostDialog,
        child: Text('${libL10n.edit} DOCKER_HOST'),
      ),
    );
    return CardX(
        child: Column(
      children: children,
    ));
  }

  Widget _buildSwitchProvider() {
    late final Widget child;
    if (_container.type == ContainerType.podman) {
      child = TextButton(
        onPressed: () {
          _container.setType(ContainerType.docker);
        },
        child: Text(l10n.switchTo('Docker')),
      );
    } else {
      child = TextButton(
        onPressed: () {
          _container.setType(ContainerType.podman);
        },
        child: Text(l10n.switchTo('Podman')),
      );
    }
    return CardX(child: child);
  }

  Future<void> _showAddFAB() async {
    final imageCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final argsCtrl = TextEditingController();
    await context.showRoundDialog(
        title: l10n.newContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Input(
              autoFocus: true,
              type: TextInputType.text,
              label: l10n.image,
              hint: 'xxx:1.1',
              controller: imageCtrl,
              suggestion: false,
            ),
            Input(
              type: TextInputType.text,
              controller: nameCtrl,
              label: libL10n.name,
              hint: 'xxx',
              suggestion: false,
            ),
            Input(
              type: TextInputType.text,
              controller: argsCtrl,
              label: l10n.extraArgs,
              hint: '-p 2222:22 -v ~/.xxx/:/xxx',
              suggestion: false,
            ),
          ],
        ),
        actions: Btn.ok(onTap: () async {
          context.pop();
          await _showAddCmdPreview(
            _buildAddCmd(
              imageCtrl.text.trim(),
              nameCtrl.text.trim(),
              argsCtrl.text.trim(),
            ),
          );
        }).toList);
  }

  Future<void> _showAddCmdPreview(String cmd) async {
    await context.showRoundDialog(
      title: l10n.preview,
      child: Text(cmd),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();

            final (result, err) = await context.showLoadingDialog(
              fn: () => _container.run(cmd),
            );
            if (err != null || result != null) {
              final e = result?.message ?? err?.toString();
              context.showRoundDialog(
                title: libL10n.error,
                child: Text(e.toString()),
              );
            }
          },
          child: Text(l10n.run),
        )
      ],
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

  Future<void> _showEditHostDialog() async {
    final id = widget.spi.id;
    final host = Stores.container.fetch(id);
    final ctrl = TextEditingController(text: host);
    await context.showRoundDialog(
      title: libL10n.edit,
      child: Input(
        maxLines: 2,
        controller: ctrl,
        onSubmitted: _onSaveDockerHost,
        hint: 'unix:///run/user/1000/docker.sock',
        suggestion: false,
      ),
      actions: Btn.ok(onTap: () => _onSaveDockerHost(ctrl.text)).toList,
    );
  }

  void _onSaveDockerHost(String val) {
    context.pop();
    Stores.container.put(widget.spi.id, val.trim());
    _container.refresh();
  }

  void _showImageRmDialog(ContainerImg e) {
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.delete} Image(${e.repository})'),
      ),
      actions: Btn.ok(
        onTap: () async {
          context.pop();
          final result = await _container.run('rmi ${e.id} -f');
          if (result != null) {
            context.showSnackBar(result.message ?? 'null');
          }
        },
        red: true,
      ).toList,
    );
  }

  void _onTapMoreBtn(ContainerMenu item, ContainerPs dItem) async {
    final id = dItem.id;
    if (id == null) {
      context.showSnackBar('Id is null');
      return;
    }
    switch (item) {
      case ContainerMenu.rm:
        var force = false;
        context.showRoundDialog(
          title: libL10n.attention,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(libL10n.askContinue(
                '${libL10n.delete} Container(${dItem.name})',
              )),
              UIs.height13,
              Row(
                children: [
                  StatefulBuilder(builder: (_, setState) {
                    return Checkbox(
                      value: force,
                      onChanged: (val) => setState(
                        () => force = val ?? false,
                      ),
                    );
                  }),
                  Text(l10n.force),
                ],
              )
            ],
          ),
          actions: Btn.ok(onTap: () async {
            context.pop();

            final (result, err) = await context.showLoadingDialog(
              fn: () => _container.delete(id, force),
            );
            if (err != null || result != null) {
              final e = result?.message ?? err?.toString();
              context.showRoundDialog(
                title: libL10n.error,
                child: Text(e ?? 'null'),
              );
            }
          }).toList,
        );
        break;
      case ContainerMenu.start:
        final (result, err) = await context.showLoadingDialog(
          fn: () => _container.start(id),
        );
        if (err != null || result != null) {
          final e = result?.message ?? err?.toString();
          context.showRoundDialog(
            title: libL10n.error,
            child: Text(e ?? 'null'),
          );
        }
        break;
      case ContainerMenu.stop:
        final (result, err) = await context.showLoadingDialog(
          fn: () => _container.stop(id),
        );
        if (err != null || result != null) {
          final e = result?.message ?? err?.toString();
          context.showRoundDialog(
            title: libL10n.error,
            child: Text(e ?? 'null'),
          );
        }
        break;
      case ContainerMenu.restart:
        final (result, err) = await context.showLoadingDialog(
          fn: () => _container.restart(id),
        );
        if (err != null || result != null) {
          final e = result?.message ?? err?.toString();
          context.showRoundDialog(
            title: libL10n.error,
            child: Text(e ?? 'null'),
          );
        }
        break;
      case ContainerMenu.logs:
        AppRoutes.ssh(
          spi: widget.spi,
          initCmd: '${switch (_container.type) {
            ContainerType.podman => 'podman',
            ContainerType.docker => 'docker',
          }} logs -f --tail 100 ${dItem.id}',
        ).go(context);
        break;
      case ContainerMenu.terminal:
        AppRoutes.ssh(
          spi: widget.spi,
          initCmd: '${switch (_container.type) {
            ContainerType.podman => 'podman',
            ContainerType.docker => 'docker',
          }} exec -it ${dItem.id} sh',
        ).go(context);
        break;
      // case DockerMenuType.stats:
      //   showRoundDialog(
      //     context: context,
      //     title: Text(l10n.stats),
      //     child: Text(
      //       'CPU: ${dItem.cpu}\n'
      //       'Mem: ${dItem.mem}\n'
      //       'Net: ${dItem.net}\n'
      //       'Block: ${dItem.disk}',
      //     ),
      //     actions: [
      //       TextButton(
      //         onPressed: () => context.pop(),
      //         child: Text(l10n.ok),
      //       ),
      //     ],
      //   );
      //   break;
    }
  }

  void _initAutoRefresh() {
    if (Stores.setting.contaienrAutoRefresh.fetch()) {
      Timer.periodic(
        Duration(seconds: Stores.setting.serverStatusUpdateInterval.fetch()),
        (timer) {
          if (mounted) {
            _container.refresh(isAuto: true);
          } else {
            timer.cancel();
          }
        },
      );
    }
  }
}
