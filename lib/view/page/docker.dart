import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/model/docker/image.dart';
import 'package:toolbox/view/page/ssh_term.dart';
import 'package:toolbox/view/widget/input_field.dart';

import '../../core/utils/ui.dart';
import '../../data/model/docker/ps.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/provider/docker.dart';
import '../../data/provider/server.dart';
import '../../data/model/app/error.dart';
import '../../data/model/app/menu.dart';
import '../../data/res/ui.dart';
import '../../data/res/url.dart';
import '../../data/store/docker.dart';
import '../../locator.dart';
import '../widget/custom_appbar.dart';
import '../widget/popup_menu.dart';
import '../widget/round_rect_card.dart';
import '../widget/two_line_text.dart';
import '../widget/url_text.dart';

class DockerManagePage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const DockerManagePage({required this.spi, Key? key}) : super(key: key);

  @override
  State<DockerManagePage> createState() => _DockerManagePageState();
}

class _DockerManagePageState extends State<DockerManagePage> {
  final _docker = locator<DockerProvider>();
  final _store = locator<DockerStore>();
  final _textController = TextEditingController();
  late S _s;

  @override
  void dispose() {
    super.dispose();
    _docker.clear();
    _textController.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  void initState() {
    super.initState();
    final client = locator<ServerProvider>().servers[widget.spi.id]?.client;
    if (client == null) {
      return;
    }
    _docker.init(client, widget.spi.user, onPwdRequest, widget.spi.id);
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
                showLoadingDialog(context);
                await _docker.refresh();
                context.pop();
              },
              icon: const Icon(Icons.refresh),
            )
          ],
        ),
        body: _buildMain(),
        floatingActionButton: _docker.error == null ? _buildFAB() : null,
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
    await showRoundDialog(
      context: context,
      title: Text(_s.newContainer),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            autoFocus: true,
            type: TextInputType.text,
            label: _s.image,
            hint: 'xxx:1.1',
            controller: imageCtrl,
          ),
          Input(
            type: TextInputType.text,
            controller: nameCtrl,
            label: _s.containerName,
            hint: 'xxx',
          ),
          Input(
            type: TextInputType.text,
            controller: argsCtrl,
            label: _s.extraArgs,
            hint: '-p 2222:22 -v ~/.xxx/:/xxx',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(_s.cancel),
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
          child: Text(_s.ok),
        )
      ],
    );
  }

  Future<void> _showAddCmdPreview(String cmd) async {
    await showRoundDialog(
      context: context,
      title: Text(_s.preview),
      child: Text(cmd),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            showLoadingDialog(context);
            final result = await _docker.run(cmd);
            context.pop();
            if (result != null) {
              showSnackBar(context, Text(result.message ?? _s.unknownError));
            }
          },
          child: Text(_s.run),
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

  void onSubmitted() {
    context.pop();
    if (_textController.text == '') {
      showRoundDialog(
        context: context,
        title: Text(_s.attention),
        child: Text(_s.fieldMustNotEmpty),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(_s.ok),
          ),
        ],
      );
      return;
    }
  }

  Future<String> onPwdRequest() async {
    if (!mounted) return '';
    await showRoundDialog(
      context: context,
      title: Text(widget.spi.user),
      child: Input(
        controller: _textController,
        type: TextInputType.visiblePassword,
        obscureText: true,
        onSubmitted: (_) => onSubmitted(),
        label: _s.pwd,
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.pop();
            context.pop();
          },
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: onSubmitted,
          child: Text(_s.ok, style: textRed),
        ),
      ],
    );
    return _textController.text.trim();
  }

  Widget _buildMain() {
    if (_docker.error != null && _docker.items == null) {
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
            Text(_docker.error?.message ?? _s.unknownError),
            const SizedBox(height: 27),
            Padding(
              padding: const EdgeInsets.all(17),
              child: _buildSolution(_docker.error!),
            )
          ],
        ),
      );
    }
    if (_docker.items == null || _docker.images == null) {
      Future.delayed(const Duration(milliseconds: 37), () {
        if (mounted) {
          _docker.refresh();
        }
      });
      return centerLoading;
    }

    final items = <Widget>[
      _buildLoading(),
      _buildVersion(),
      _buildPs(),
      _buildImage(),
      _buildEditHost(),
    ].map((e) => RoundRectCard(e));
    return ListView(
      padding: const EdgeInsets.all(7),
      children: items.toList(),
    );
  }

  Widget _buildImage() {
    final items = <Widget>[
      ListTile(
        title: Text(_s.imagesList),
        subtitle: Text(
          _s.dockerImagesFmt(_docker.images!.length),
          style: grey,
        ),
      ),
    ];
    items.addAll(_docker.images!.map(_buildImageItem));
    return Column(children: items);
  }

  Widget _buildImageItem(DockerImage e) {
    return ListTile(
      title: Text(e.repo),
      subtitle: Text('${e.tag} - ${e.size}', style: grey),
      trailing: IconButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        icon: const Icon(Icons.delete),
        onPressed: () => _showImageRmDialog(e),
      ),
    );
  }

  void _showImageRmDialog(DockerImage e) {
    showRoundDialog(
      context: context,
      title: Text(_s.attention),
      child: Text(_s.sureDelete(e.repo)),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            final result = await _docker.run(
              'docker rmi ${e.id} -f',
            );
            if (result != null) {
              showSnackBar(
                context,
                Text(result.message ?? _s.unknownError),
              );
            }
          },
          child: Text(_s.ok, style: textRed),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    if (_docker.runLog == null) return placeholder;
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          const Center(
            child: CircularProgressIndicator(),
          ),
          height13,
          Text(_docker.runLog ?? '...'),
        ],
      ),
    );
  }

  Widget _buildSolution(DockerErr err) {
    switch (err.type) {
      case DockerErrType.notInstalled:
        return UrlText(
          text: _s.installDockerWithUrl,
          replace: _s.install,
        );
      case DockerErrType.noClient:
        return Text(_s.waitConnection);
      case DockerErrType.invalidVersion:
        return UrlText(
          text: _s.invalidVersionHelp(appHelpUrl),
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
          Text(_docker.edition ?? _s.unknown),
          Text(_docker.version ?? _s.unknown),
        ],
      ),
    );
  }

  Widget _buildPs() {
    final items = <Widget>[
      ListTile(
        title: Text(_s.containerStatus),
        subtitle: Text(_buildPsCardSubtitle(_docker.items!), style: grey),
      ),
    ];
    items.addAll(_docker.items!.map(_buildPsItem));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  Widget _buildPsItem(DockerPsItem item) {
    return ListTile(
      title: Text(item.image),
      subtitle: Text(
        '${item.name} - ${item.status}',
        style: textSize13Grey,
      ),
      trailing: _buildMoreBtn(item),
    );
  }

  Widget _buildMoreBtn(DockerPsItem dItem) {
    return PopupMenu(
      items: DockerMenuType.items(dItem.running)
          .map(
            (e) => e.build(_s),
          )
          .toList(),
      onSelected: (DockerMenuType item) async {
        switch (item) {
          case DockerMenuType.rm:
            showRoundDialog(
              context: context,
              title: Text(_s.attention),
              child: Text(_s.sureDelete(dItem.name)),
              actions: [
                TextButton(
                  onPressed: () async {
                    context.pop();
                    showLoadingDialog(context);
                    await _docker.delete(dItem.containerId);
                    context.pop();
                  },
                  child: Text(_s.ok),
                )
              ],
            );
            break;
          case DockerMenuType.start:
            showLoadingDialog(context);
            await _docker.start(dItem.containerId);
            context.pop();
            break;
          case DockerMenuType.stop:
            showLoadingDialog(context);
            await _docker.stop(dItem.containerId);
            context.pop();
            break;
          case DockerMenuType.restart:
            showLoadingDialog(context);
            await _docker.restart(dItem.containerId);
            context.pop();
            break;
          case DockerMenuType.logs:
            AppRoute(
              SSHPage(
                spi: widget.spi,
                initCmd: 'docker logs -f --tail 100 ${dItem.containerId}',
              ),
              'Docker logs',
            ).go(context);
            break;
          case DockerMenuType.terminal:
            AppRoute(
              SSHPage(
                spi: widget.spi,
                initCmd: 'docker exec -it ${dItem.containerId} sh',
              ),
              'Docker terminal',
            ).go(context);
            break;
          case DockerMenuType.stats:
            showRoundDialog(
              context: context,
              title: Text(_s.stats),
              child: Text(
                'CPU: ${dItem.cpu}\n'
                'Mem: ${dItem.mem}\n'
                'Net: ${dItem.net}\n'
                'Block: ${dItem.disk}',
              ),
              actions: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(_s.ok),
                ),
              ],
            );
            break;
        }
      },
    );
  }

  String _buildPsCardSubtitle(List<DockerPsItem> running) {
    final runningCount = running.where((element) => element.running).length;
    final stoped = running.length - runningCount;
    if (stoped == 0) {
      return _s.dockerStatusRunningFmt(runningCount);
    }
    return _s.dockerStatusRunningAndStoppedFmt(runningCount, stoped);
  }

  Widget _buildEditHost() {
    final children = <Widget>[];
    if (_docker.items!.isEmpty && _docker.images!.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
        child: Text(
          _s.dockerEmptyRunningItems,
          textAlign: TextAlign.center,
        ),
      ));
    }
    children.add(
      TextButton(
        onPressed: _showEditHostDialog,
        child: Text(_s.dockerEditHost),
      ),
    );
    return Column(
      children: children,
    );
  }

  Future<void> _showEditHostDialog() async {
    final id = widget.spi.id;
    final host = _store.fetch(id) ?? 'unix:///run/user/1000/docker.sock';
    final ctrl = TextEditingController(text: host);
    await showRoundDialog(
      context: context,
      title: Text(_s.dockerEditHost),
      child: Input(
        maxLines: 1,
        controller: ctrl,
        onSubmitted: _onSaveDockerHost,
      ),
      actions: [
        TextButton(
          onPressed: () => _onSaveDockerHost(ctrl.text),
          child: Text(_s.ok),
        ),
      ],
    );
  }

  void _onSaveDockerHost(String val) {
    context.pop();
    _store.put(widget.spi.id, val.trim());
    _docker.refresh();
  }
}
