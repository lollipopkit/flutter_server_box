import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/app/menu_item.dart';
import 'package:toolbox/data/model/docker/ps.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/docker.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/url.dart';
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
  late MediaQueryData _media;
  late S s;

  @override
  void dispose() {
    super.dispose();
    _docker.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
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
    _docker.init(client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: 'Docker', down: widget.spi.name),
      ),
      body: _buildMain(),
    );
  }

  Widget _buildMain() {
    return Consumer<DockerProvider>(builder: (_, docker, __) {
      final running = docker.items;
      if (docker.error != null && running == null) {
        return SizedBox.expand(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 37,),
            const SizedBox(height: 27),
            Text(docker.error!),
            const SizedBox(height: 27),
            Padding(padding: const EdgeInsets.all(17), child: _buildSolution(docker.error!),)
          ],
        ),);
      }
      if (running == null) {
        _docker.refresh();
        return centerLoading;
      }
      return ListView(
        padding: const EdgeInsets.all(7),
        children: [
          _buildVersion(
              docker.edition ?? s.unknown, docker.version ?? s.unknown),
          _buildPsItems(running, docker)
        ].map((e) => RoundRectCard(e)).toList(),
      );
    });
  }

  Widget _buildSolution(String err) {
    switch (err) {
      case 'docker not found':
        return UrlText(
          text: s.installDockerWithUrl,
          replace: s.install,
        );
      case 'no client':
        return Text(s.waitConnection);
      case 'invalid version':
        return UrlText(text: s.invalidVersionHelp(issueUrl), replace: 'Github',);
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
    return DropdownButtonHideUnderline(
      child: DropdownButton2(
        customButton: const Padding(
          padding: EdgeInsets.only(left: 7),
          child: Icon(
            Icons.more_vert,
            size: 17,
          ),
        ),
        customItemsHeight: 8,
        items: [
          DropdownMenuItem<MenuItem>(
            value: item,
            child: item.build,
          ),
          DropdownMenuItem<MenuItem>(
            value: DockerMenuItems.rm,
            child: DockerMenuItems.rm.build,
          ),
        ],
        onChanged: (value) {
          final item = value as MenuItem;
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
        itemHeight: 37,
        itemPadding: const EdgeInsets.only(left: 17, right: 17),
        dropdownWidth: 133,
        dropdownDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
        ),
        dropdownElevation: 8,
        offset: const Offset(0, 8),
      ),
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
