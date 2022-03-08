import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/docker/ps.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/docker.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/center_loading.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class DockerManagePage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const DockerManagePage(this.spi, {Key? key}) : super(key: key);

  @override
  State<DockerManagePage> createState() => _DockerManagePageState();
}

class _DockerManagePageState extends State<DockerManagePage> {
  final _docker = locator<DockerProvider>();
  final greyTextStyle = const TextStyle(color: Colors.grey);

  @override
  void dispose() {
    super.dispose();
    _docker.clear();
  }

  @override
  void initState() {
    super.initState();
    final client = locator<ServerProvider>()
        .servers
        .firstWhere((element) => element.info == widget.spi)
        .client;
    if (client == null) {
      showSnackBar(context, const Text('No client found'));
      Navigator.of(context).pop();
      return;
    }
    _docker.init(client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docker'),
      ),
      body: _buildMain(),
    );
  }

  Widget _buildMain() {
    return Consumer<DockerProvider>(builder: (_, docker, __) {
      final running = docker.running;
      if (docker.error != null && running == null) {
        return Center(
          child: Text(docker.error!),
        );
      }
      if (running == null) {
        _docker.refresh();
        return centerLoading;
      }
      return ListView(
        padding: const EdgeInsets.all(7),
        children:
            [_buildVersion(docker.edition ?? 'Unknown', docker.version ?? 'Unknown'), _buildPsItems(running)].map((e) => RoundRectCard(e)).toList(),
      );
    });
  }

  Widget _buildVersion(String edition, String version) {
    return Padding(padding: EdgeInsets.all(13), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(edition),
        Text(version)
      ],
    ),);
  }

  Widget _buildPsItems(List<DockerPsItem> running) {
    return ExpansionTile(
      title: const Text('Container Status'),
      subtitle: Text(_buildSubtitle(running), style: greyTextStyle),
      children: running.map((item) {
        return ListTile(
          title: Text(item.image),
          subtitle: Text(item.status),
          trailing: IconButton(
              onPressed: () {},
              icon: Icon(item.running ? Icons.stop : Icons.play_arrow)),
        );
      }).toList(),
    );
  }

  String _buildSubtitle(List<DockerPsItem> running) {
    final runningCount = running.where((element) => element.running).length;
    final stoped = running.length - runningCount;
    if (stoped == 0) {
      return '$runningCount container running.';
    }
    return '$runningCount running, $stoped stoped.';
  }
}
