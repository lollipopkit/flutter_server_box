import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/utils/ui.dart';
import '../../data/model/docker/ps.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/provider/docker.dart';
import '../../data/provider/server.dart';
import '../../data/res/error.dart';
import '../../data/res/font_style.dart';
import '../../data/res/menu.dart';
import '../../data/res/url.dart';
import '../../data/store/docker.dart';
import '../../locator.dart';
import '../widget/center_loading.dart';
import '../widget/dropdown_menu.dart';
import '../widget/round_rect_card.dart';
import '../widget/two_line_text.dart';
import '../widget/url_text.dart';

class DockerManagePage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const DockerManagePage(this.spi, {Key? key}) : super(key: key);

  @override
  State<DockerManagePage> createState() => _DockerManagePageState();
}

class _DockerManagePageState extends State<DockerManagePage> {
  final _docker = locator<DockerProvider>();
  final _textController = TextEditingController();
  late S _s;

  @override
  void dispose() {
    super.dispose();
    _docker.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  void initState() {
    super.initState();
    final client = locator<ServerProvider>()
        .servers
        .firstWhere((element) => element.spi == widget.spi)
        .client;
    if (client == null) {
      showSnackBar(context, Text(_s.noClient));
      Navigator.of(context).pop();
      return;
    }
    _docker.init(client, widget.spi.user, onPwdRequest, widget.spi.id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DockerProvider>(builder: (_, ___, __) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: TwoLineText(up: 'Docker', down: widget.spi.name),
          actions: [
            IconButton(
              onPressed: () => _docker.refresh(),
              icon: const Icon(Icons.refresh),
            )
          ],
        ),
        body: _buildMain(),
        floatingActionButton: _buildFAB(),
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
      context,
      _s.newContainer,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
                labelText: _s.dockerImage, hintText: 'ubuntu:22.10'),
            controller: imageCtrl,
            autocorrect: false,
          ),
          TextField(
            keyboardType: TextInputType.text,
            controller: nameCtrl,
            decoration: InputDecoration(
                labelText: _s.dockerContainerName, hintText: 'ubuntu22'),
            autocorrect: false,
          ),
          TextField(
            keyboardType: TextInputType.text,
            controller: argsCtrl,
            decoration: InputDecoration(
                labelText: _s.extraArgs,
                hintText: '-p 2222:22 -v ~/.xxx/:/xxx'),
            autocorrect: false,
          ),
        ],
      ),
      [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
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
      context,
      _s.preview,
      Text(cmd),
      [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final result = await _docker.run(cmd);
            if (result != null) {
              showSnackBar(context, Text(getErrMsg(result) ?? _s.unknownError));
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

  String? getErrMsg(DockerErr err) {
    switch (err.type) {
      default:
        return err.message;
    }
  }

  void onSubmitted() {
    if (_textController.text == '') {
      showRoundDialog(context, _s.attention, Text(_s.fieldMustNotEmpty), [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s.ok),
        ),
      ]);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<String> onPwdRequest() async {
    if (!mounted) return '';
    await showRoundDialog(
      context,
      widget.spi.user,
      TextField(
        controller: _textController,
        keyboardType: TextInputType.visiblePassword,
        obscureText: true,
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          labelText: _s.pwd,
        ),
      ),
      [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () => onSubmitted(),
          child: Text(
            _s.ok,
            style: const TextStyle(color: Colors.red),
          ),
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
            _buildErr(_docker.error!),
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
      _docker.refresh();
      return centerLoading;
    }

    return ListView(
      padding: const EdgeInsets.all(7),
      children: [
        _buildLoading(),
        _buildVersion(
            _docker.edition ?? _s.unknown, _docker.version ?? _s.unknown),
        _buildPsItems(),
        _buildImages(),
        _buildEditHost(),
      ].map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildImages() {
    if (_docker.images == null) {
      return const SizedBox();
    }
    return ExpansionTile(
      title: Text(_s.imagesList),
      subtitle: Text(
        _s.dockerImagesFmt(_docker.images!.length),
        style: grey,
      ),
      children: _docker.images!
          .map(
            (e) => ListTile(
              title: Text(e.repo),
              subtitle: Text('${e.tag} - ${e.size}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  showRoundDialog(
                    context,
                    _s.attention,
                    Text(_s.sureDelete(e.repo)),
                    [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(_s.cancel),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          final result = await _docker.run(
                            'docker rmi ${e.id} -f',
                          );
                          if (result != null) {
                            showSnackBar(
                              context,
                              Text(getErrMsg(result) ?? _s.unknownError),
                            );
                          }
                        },
                        child: Text(
                          _s.ok,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildLoading() {
    if (!_docker.isBusy) return const SizedBox();
    final haveLog = _docker.runLog != null;
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          const Center(
            child: CircularProgressIndicator(),
          ),
          haveLog ? const SizedBox(height: 17) : const SizedBox(),
          haveLog ? Text(_docker.runLog!) : const SizedBox()
        ],
      ),
    );
  }

  Widget _buildEditHost() {
    if (_docker.items!.isNotEmpty || _docker.images!.isNotEmpty) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
      child: Column(
        children: [
          Text(
            _s.dockerEmptyRunningItems,
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () => _showEditHostDialog(),
            child: Text(_s.dockerEditHost),
          )
        ],
      ),
    );
  }

  Future<void> _showEditHostDialog() async {
    await showRoundDialog(
      context,
      _s.dockerEditHost,
      TextField(
        maxLines: 1,
        autocorrect: false,
        controller:
            TextEditingController(text: 'unix:///run/user/1000/docker.sock'),
        onSubmitted: (value) {
          locator<DockerStore>().setDockerHost(widget.spi.id, value.trim());
          _docker.refresh();
          Navigator.of(context).pop();
        },
      ),
      [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s.cancel),
        ),
      ],
    );
  }

  Widget _buildErr(DockerErr err) {
    var errStr = '';
    switch (err.type) {
      case DockerErrType.noClient:
        errStr = _s.noClient;
        break;
      case DockerErrType.notInstalled:
        errStr = _s.dockerNotInstalled;
        break;
      case DockerErrType.invalidVersion:
        errStr = _s.invalidVersion;
        break;
      default:
        errStr = err.message ?? _s.unknown;
    }
    return Text(errStr);
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
          text: _s.invalidVersionHelp(issueUrl),
          replace: 'Github',
        );
      default:
        return Text(_s.unknownError);
    }
  }

  Widget _buildVersion(String edition, String version) {
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(edition), Text(version)],
      ),
    );
  }

  Widget _buildPsItems() {
    return ExpansionTile(
      title: Text(_s.containerStatus),
      subtitle: Text(_buildSubtitle(_docker.items!), style: grey),
      children: _docker.items!.map(
        (item) {
          return ListTile(
            title: Text(item.name),
            subtitle: Text('${item.image} - ${item.status}'),
            trailing: _buildMoreBtn(item, _docker.isBusy),
          );
        },
      ).toList(),
    );
  }

  Widget _buildMoreBtn(DockerPsItem dItem, bool busy) {
    final item = dItem.running ? DockerMenuItems.stop : DockerMenuItems.start;
    return buildPopuopMenu(
      items: [
        PopupMenuItem<DropdownBtnItem>(
          value: item,
          child: item.build(_s),
        ),
        PopupMenuItem<DropdownBtnItem>(
          value: DockerMenuItems.rm,
          child: DockerMenuItems.rm.build(_s),
        ),
      ],
      onSelected: (value) {
        if (busy) {
          showSnackBar(context, Text(_s.isBusy));
          return;
        }
        final item = value as DropdownBtnItem;
        switch (item) {
          case DockerMenuItems.rm:
            showRoundDialog(
              context,
              _s.attention,
              Text(_s.sureDelete(dItem.name)),
              [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _docker.delete(dItem.containerId);
                  },
                  child: Text(_s.ok),
                )
              ],
            );
            break;
          case DockerMenuItems.start:
            _docker.start(dItem.containerId);
            break;
          case DockerMenuItems.stop:
            _docker.stop(dItem.containerId);
            break;
        }
      },
    );
  }

  String _buildSubtitle(List<DockerPsItem> running) {
    final runningCount = running.where((element) => element.running).length;
    final stoped = running.length - runningCount;
    if (stoped == 0) {
      return _s.dockerStatusRunningFmt(runningCount);
    }
    return _s.dockerStatusRunningAndStoppedFmt(runningCount, stoped);
  }
}
