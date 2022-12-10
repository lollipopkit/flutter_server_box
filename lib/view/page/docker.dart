import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/app/menu_item.dart';
import 'package:toolbox/data/model/docker/ps.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/docker.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/error.dart';
import 'package:toolbox/data/res/url.dart';
import 'package:toolbox/data/store/docker.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/center_loading.dart';
import 'package:toolbox/view/widget/two_line_text.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:toolbox/view/widget/url_text.dart';

class DockerManagePage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const DockerManagePage(this.spi, {Key? key}) : super(key: key);

  @override
  State<DockerManagePage> createState() => _DockerManagePageState();
}

class _DockerManagePageState extends State<DockerManagePage> {
  final _docker = locator<DockerProvider>();
  final greyTextStyle = const TextStyle(color: Colors.grey);
  final textController = TextEditingController();
  late S s;

  @override
  void dispose() {
    super.dispose();
    _docker.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    s = S.of(context);
  }

  @override
  void initState() {
    super.initState();
    final client = locator<ServerProvider>()
        .servers
        .firstWhere((element) => element.info == widget.spi)
        .client;
    if (client == null) {
      showSnackBar(context, Text(s.noClient));
      Navigator.of(context).pop();
      return;
    }
    _docker.init(client, widget.spi.user, onPwdRequest, widget.spi.id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DockerProvider>(builder: (_, docker, __) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: TwoLineText(up: 'Docker', down: widget.spi.name),
          actions: [
            IconButton(
                onPressed: () => docker.refresh(),
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: _buildMain(docker),
        floatingActionButton: _buildFAB(docker),
      );
    });
  }

  Widget _buildFAB(DockerProvider docker) {
    final c = TextEditingController();
    return FloatingActionButton(
      onPressed: () {
        showRoundDialog(
          context,
          s.cmd,
          TextField(
            keyboardType: TextInputType.multiline,
            maxLines: 7,
            controller: c,
            autocorrect: false,
          ),
          [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final result = await docker.run(c.text.trim());
                if (result != null) {
                  showSnackBar(
                      context, Text(getErrMsg(result) ?? s.unknownError));
                }
              },
              child: Text(s.run),
            )
          ],
        );
      },
      child: const Icon(Icons.code),
    );
  }

  String? getErrMsg(DockerErr err) {
    switch (err.type) {
      case DockerErrType.cmdNoPrefix:
        return s.dockerCmdPrefixErr;
      default:
        return null;
    }
  }

  void onSubmitted() {
    if (textController.text == '') {
      showRoundDialog(context, s.attention, Text(s.fieldMustNotEmpty), [
        TextButton(
            onPressed: () => Navigator.of(context).pop(), child: Text(s.ok)),
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
          controller: textController,
          keyboardType: TextInputType.visiblePassword,
          obscureText: true,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            labelText: s.pwd,
          ),
        ),
        [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text(s.cancel)),
          TextButton(
              onPressed: () => onSubmitted(),
              child: Text(
                s.ok,
                style: const TextStyle(color: Colors.red),
              )),
        ]);
    return textController.text.trim();
  }

  Widget _buildMain(DockerProvider docker) {
    final running = docker.items;
    if (docker.error != null && running == null) {
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
            _buildErr(docker.error!),
            const SizedBox(height: 27),
            Padding(
              padding: const EdgeInsets.all(17),
              child: _buildSolution(docker.error!),
            )
          ],
        ),
      );
    }
    if (running == null) {
      _docker.refresh();
      return centerLoading;
    }

    return ListView(
      padding: const EdgeInsets.all(7),
      children: [
        _buildVersion(docker.edition ?? s.unknown, docker.version ?? s.unknown),
        _buildPsItems(running, docker),
        _buildEditHost(running, docker),
        _buildRunLog(docker),
      ].map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildRunLog(DockerProvider docker) {
    if (docker.runLog == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Text(docker.runLog!, maxLines: 1,),
    );
  }

  Widget _buildEditHost(List<DockerPsItem> running, DockerProvider docker) {
    if (running.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
        child: Column(
          children: [
            Text(
              s.dockerEmptyRunningItems,
              textAlign: TextAlign.center,
            ),
            TextButton(
                onPressed: () => _showEditHostDialog(docker),
                child: Text(s.dockerEditHost))
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Future<void> _showEditHostDialog(DockerProvider docker) async {
    await showRoundDialog(
      context,
      s.dockerEditHost,
      TextField(
        maxLines: 1,
        autocorrect: false,
        controller:
            TextEditingController(text: 'unix:///run/user/1000/docker.sock'),
        onSubmitted: (value) {
          locator<DockerStore>().setDockerHost(widget.spi.id, value.trim());
          docker.refresh();
          Navigator.of(context).pop();
        },
      ),
      [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.cancel)),
      ],
    );
  }

  Widget _buildErr(DockerErr err) {
    var errStr = '';
    switch (err.type) {
      case DockerErrType.noClient:
        errStr = s.noClient;
        break;
      case DockerErrType.notInstalled:
        errStr = s.dockerNotInstalled;
        break;
      case DockerErrType.invalidVersion:
        errStr = s.invalidVersion;
        break;
      default:
        errStr = err.message ?? s.unknown;
    }
    return Text(errStr);
  }

  Widget _buildSolution(DockerErr err) {
    switch (err.type) {
      case DockerErrType.notInstalled:
        return UrlText(
          text: s.installDockerWithUrl,
          replace: s.install,
        );
      case DockerErrType.noClient:
        return Text(s.waitConnection);
      case DockerErrType.invalidVersion:
        return UrlText(
          text: s.invalidVersionHelp(issueUrl),
          replace: 'Github',
        );
      default:
        return Text(s.unknownError);
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

  Widget _buildPsItems(List<DockerPsItem> running, DockerProvider docker) {
    return ExpansionTile(
      title: Text(s.containerStatus),
      subtitle: Text(_buildSubtitle(running), style: greyTextStyle),
      children: running.map((item) {
        return ListTile(
          title: Text(item.image),
          subtitle: Text(item.status),
          trailing: docker.isBusy
              ? const CircularProgressIndicator()
              : _buildMoreBtn(item.running, item.containerId),
        );
      }).toList(),
    );
  }

  Widget _buildMoreBtn(bool running, String containerId) {
    final item = running ? DockerMenuItems.stop : DockerMenuItems.start;
    return buildPopuopMenu(
      items: [
        PopupMenuItem<DropdownBtnItem>(
          value: item,
          child: item.build,
        ),
        PopupMenuItem<DropdownBtnItem>(
          value: DockerMenuItems.rm,
          child: DockerMenuItems.rm.build,
        ),
      ],
      onSelected: (value) {
        final item = value as DropdownBtnItem;
        switch (item) {
          case DockerMenuItems.rm:
            _docker.delete(containerId);
            break;
          case DockerMenuItems.start:
            _docker.start(containerId);
            break;
          case DockerMenuItems.stop:
            _docker.stop(containerId);
            break;
        }
      },
    );
  }

  String _buildSubtitle(List<DockerPsItem> running) {
    final runningCount = running.where((element) => element.running).length;
    final stoped = running.length - runningCount;
    if (stoped == 0) {
      return s.dockerStatusRunningFmt(runningCount);
    }
    return s.dockerStatusRunningAndStoppedFmt(runningCount, stoped);
  }
}
