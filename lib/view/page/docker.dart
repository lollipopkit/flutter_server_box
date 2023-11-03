import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/model/docker/image.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/expand_tile.dart';
import 'package:toolbox/view/widget/input_field.dart';

import '../../data/model/docker/ps.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/provider/docker.dart';
import '../../data/model/app/error.dart';
import '../../data/model/app/menu.dart';
import '../../data/res/ui.dart';
import '../../data/res/url.dart';
import '../widget/custom_appbar.dart';
import '../widget/popup_menu.dart';
import '../widget/cardx.dart';
import '../widget/two_line_text.dart';
import '../widget/url_text.dart';

class DockerManagePage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const DockerManagePage({required this.spi, Key? key}) : super(key: key);

  @override
  State<DockerManagePage> createState() => _DockerManagePageState();
}

class _DockerManagePageState extends State<DockerManagePage> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    Pros.docker.clear();
    _textController.dispose();
  }

  @override
  void initState() {
    super.initState();
    final client = widget.spi.server?.client;
    if (client == null) {
      return;
    }
    Pros.docker
      ..init(
        client,
        widget.spi.user,
        (user) async => await context.showPwdDialog(user),
        widget.spi.id,
        context,
      )
      ..refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DockerProvider>(builder: (_, ___, __) {
      return Scaffold(
        appBar: CustomAppBar(
          centerTitle: true,
          title: TwoLineText(up: 'Docker', down: widget.spi.name),
          actions: [
            IconButton(
              onPressed: () async {
                context.showLoadingDialog();
                await Pros.docker.refresh();
                context.pop();
              },
              icon: const Icon(Icons.refresh),
            )
          ],
        ),
        body: _buildMain(),
        floatingActionButton: Pros.docker.error == null ? _buildFAB() : null,
      );
    });
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () async => await _showAddFAB(),
      child: const Icon(Icons.add),
    );
  }

  Future<void> _showAddFAB() async {
    final imageCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final argsCtrl = TextEditingController();
    await context.showRoundDialog(
      title: Text(l10n.newContainer),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            autoFocus: true,
            type: TextInputType.text,
            label: l10n.image,
            hint: 'xxx:1.1',
            controller: imageCtrl,
          ),
          Input(
            type: TextInputType.text,
            controller: nameCtrl,
            label: l10n.containerName,
            hint: 'xxx',
          ),
          Input(
            type: TextInputType.text,
            controller: argsCtrl,
            label: l10n.extraArgs,
            hint: '-p 2222:22 -v ~/.xxx/:/xxx',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            await _showAddCmdPreview(
              _buildAddCmd(
                imageCtrl.text.trim(),
                nameCtrl.text.trim(),
                argsCtrl.text.trim(),
              ),
            );
          },
          child: Text(l10n.ok),
        )
      ],
    );
  }

  Future<void> _showAddCmdPreview(String cmd) async {
    await context.showRoundDialog(
      title: Text(l10n.preview),
      child: Text(cmd),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            context.showLoadingDialog();
            final result = await Pros.docker.run(cmd);
            context.pop();
            if (result != null) {
              context.showSnackBar(result.message ?? l10n.unknownError);
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
      return 'docker run -itd $suffix';
    }
    return 'docker run -itd --name $name $suffix';
  }

  Widget _buildMain() {
    if (Pros.docker.error != null && Pros.docker.items == null) {
      return SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              size: 37,
            ),
            const SizedBox(height: 27),
            Text(Pros.docker.error?.message ?? l10n.unknownError),
            const SizedBox(height: 27),
            Padding(
              padding: const EdgeInsets.all(17),
              child: _buildSolution(Pros.docker.error!),
            )
          ],
        ),
      );
    }
    if (Pros.docker.items == null || Pros.docker.images == null) {
      return UIs.centerLoading;
    }

    final items = <Widget>[
      _buildLoading(),
      _buildVersion(),
      _buildPs(),
      _buildImage(),
      _buildEditHost(),
    ].map((e) => CardX(e));
    return ListView(
      padding: const EdgeInsets.all(7),
      children: items.toList(),
    );
  }

  Widget _buildImage() {
    return ExpandTile(
      title: Text(l10n.imagesList),
      subtitle: Text(
        l10n.dockerImagesFmt(Pros.docker.images!.length),
        style: UIs.textGrey,
      ),
      children: Pros.docker.images?.map(_buildImageItem).toList() ?? [],
    );
  }

  Widget _buildImageItem(DockerImage e) {
    return ListTile(
      title: Text(e.repo),
      subtitle: Text('${e.tag} - ${e.size}', style: UIs.textGrey),
      trailing: IconButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        icon: const Icon(Icons.delete),
        onPressed: () => _showImageRmDialog(e),
      ),
    );
  }

  void _showImageRmDialog(DockerImage e) {
    context.showRoundDialog(
      title: Text(l10n.attention),
      child: Text(l10n.askContinue('${l10n.delete} Image(${e.repo})')),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            final result = await Pros.docker.run(
              'docker rmi ${e.id} -f',
            );
            if (result != null) {
              context.showSnackBar(result.message ?? l10n.unknownError);
            }
          },
          child: Text(l10n.ok, style: UIs.textRed),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    if (Pros.docker.runLog == null) return UIs.placeholder;
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          const Center(
            child: CircularProgressIndicator(),
          ),
          UIs.height13,
          Text(Pros.docker.runLog ?? '...'),
        ],
      ),
    );
  }

  Widget _buildSolution(DockerErr err) {
    switch (err.type) {
      case DockerErrType.notInstalled:
        return UrlText(
          text: l10n.installDockerWithUrl,
          replace: l10n.install,
        );
      case DockerErrType.noClient:
        return Text(l10n.waitConnection);
      case DockerErrType.invalidVersion:
        return UrlText(
          text: l10n.invalidVersionHelp(Urls.appHelp),
          replace: 'Github',
        );
      case DockerErrType.parseImages:
        return const Text('Parse images error');
      case DockerErrType.parsePsItem:
        return const Text('Parse ps item error');
      case DockerErrType.parseStats:
        return const Text('Parse stats error');
      case DockerErrType.unknown:
        return const Text('Unknown error');
      case DockerErrType.cmdNoPrefix:
        return const Text('Cmd no prefix');
      case DockerErrType.segmentsNotMatch:
        return const Text('Segments not match');
    }
  }

  Widget _buildVersion() {
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(Pros.docker.edition ?? l10n.unknown),
          Text(Pros.docker.version ?? l10n.unknown),
        ],
      ),
    );
  }

  Widget _buildPs() {
    final items = Pros.docker.items;
    if (items == null) return UIs.placeholder;
    return ExpandTile(
      title: Text(l10n.containerStatus),
      subtitle: Text(
        _buildPsCardSubtitle(items),
        style: UIs.textGrey,
      ),
      initiallyExpanded: items.length <= 7,
      children: items.map(_buildPsItem).toList(),
    );
  }

  Widget _buildPsItem(DockerPsItem item) {
    return ListTile(
      title: Text(item.image),
      subtitle: Text(
        '${item.name} - ${item.status}',
        style: UIs.textSize13Grey,
      ),
      trailing: _buildMoreBtn(item),
    );
  }

  Widget _buildMoreBtn(DockerPsItem dItem) {
    return PopupMenu(
      items: DockerMenuType.items(dItem.running).map((e) => e.widget).toList(),
      onSelected: (DockerMenuType item) async {
        switch (item) {
          case DockerMenuType.rm:
            context.showRoundDialog(
              title: Text(l10n.attention),
              child: Text(l10n.askContinue(
                '${l10n.delete} Container(${dItem.name})',
              )),
              actions: [
                TextButton(
                  onPressed: () async {
                    context.pop();
                    context.showLoadingDialog();
                    await Pros.docker.delete(dItem.containerId);
                    context.pop();
                  },
                  child: Text(l10n.ok),
                )
              ],
            );
            break;
          case DockerMenuType.start:
            context.showLoadingDialog();
            await Pros.docker.start(dItem.containerId);
            context.pop();
            break;
          case DockerMenuType.stop:
            context.showLoadingDialog();
            await Pros.docker.stop(dItem.containerId);
            context.pop();
            break;
          case DockerMenuType.restart:
            context.showLoadingDialog();
            await Pros.docker.restart(dItem.containerId);
            context.pop();
            break;
          case DockerMenuType.logs:
            AppRoute.ssh(
              spi: widget.spi,
              initCmd: 'docker logs -f --tail 100 ${dItem.containerId}',
            ).go(context);
            break;
          case DockerMenuType.terminal:
            AppRoute.ssh(
              spi: widget.spi,
              initCmd: 'docker exec -it ${dItem.containerId} sh',
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
      },
    );
  }

  String _buildPsCardSubtitle(List<DockerPsItem> running) {
    final runningCount = running.where((element) => element.running).length;
    final stoped = running.length - runningCount;
    if (stoped == 0) {
      return l10n.dockerStatusRunningFmt(runningCount);
    }
    return l10n.dockerStatusRunningAndStoppedFmt(runningCount, stoped);
  }

  Widget _buildEditHost() {
    final children = <Widget>[];
    if (Pros.docker.items!.isEmpty && Pros.docker.images!.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
        child: Text(
          l10n.dockerEmptyRunningItems,
          textAlign: TextAlign.center,
        ),
      ));
    }
    children.add(
      TextButton(
        onPressed: _showEditHostDialog,
        child: Text(l10n.dockerEditHost),
      ),
    );
    return Column(
      children: children,
    );
  }

  Future<void> _showEditHostDialog() async {
    final id = widget.spi.id;
    final host = Stores.docker.fetch(id) ?? 'unix:///run/user/1000/docker.sock';
    final ctrl = TextEditingController(text: host);
    await context.showRoundDialog(
      title: Text(l10n.dockerEditHost),
      child: Input(
        maxLines: 1,
        controller: ctrl,
        onSubmitted: _onSaveDockerHost,
      ),
      actions: [
        TextButton(
          onPressed: () => _onSaveDockerHost(ctrl.text),
          child: Text(l10n.ok),
        ),
      ],
    );
  }

  void _onSaveDockerHost(String val) {
    context.pop();
    Stores.docker.put(widget.spi.id, val.trim());
    Pros.docker.refresh();
  }
}
