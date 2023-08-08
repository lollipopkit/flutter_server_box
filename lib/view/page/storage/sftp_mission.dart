import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/datetime.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/storage/local.dart';

import '../../../core/extension/numx.dart';
import '../../../core/utils/misc.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/sftp/req.dart';
import '../../../data/provider/sftp.dart';
import '../../../data/res/ui.dart';
import '../../widget/round_rect_card.dart';

class SftpMissionPage extends StatefulWidget {
  const SftpMissionPage({Key? key}) : super(key: key);

  @override
  _SftpMissionPageState createState() => _SftpMissionPageState();
}

class _SftpMissionPageState extends State<SftpMissionPage> {
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _s.mission,
          style: textSize18,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Consumer<SftpProvider>(builder: (__, pro, _) {
      if (pro.status.isEmpty) {
        return Center(
          child: Text(_s.noTask),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(11),
        itemCount: pro.status.length,
        itemBuilder: (context, index) {
          final status = pro.status[index];
          return _buildItem(status);
        },
      );
    });
  }

  Widget _buildItem(SftpReqStatus status) {
    switch (status.status) {
      case SftpWorkerStatus.finished:
        final time = status.spentTime.toString();
        final str = '${_s.finished} ${_s.spentTime(
          time == 'null' ? _s.unknown : (time.substring(0, time.length - 7)),
        )}';
        return _wrapInCard(
          status: status,
          subtitle: str,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  onPressed: () {
                    final idx = status.req.localPath.lastIndexOf('/');
                    final dir = status.req.localPath.substring(0, idx);
                    AppRoute(
                      LocalStoragePage(initDir: dir),
                      'sftp local',
                    ).go(context);
                  },
                  icon: const Icon(Icons.file_open)),
              IconButton(
                onPressed: () => shareFiles(context, [status.req.localPath]),
                icon: const Icon(Icons.open_in_new),
              )
            ],
          ),
        );
      case SftpWorkerStatus.downloading:
        final percentStr = (status.progress ?? 0.0).toStringAsFixed(2);
        final size = (status.size ?? 0).convertBytes;
        return _wrapInCard(
          status: status,
          subtitle: _s.downloadStatus(percentStr, size),
          trailing: _buildDelete(status.fileName, status.id),
        );
      case SftpWorkerStatus.preparing:
        return _wrapInCard(
          status: status,
          subtitle: _s.sftpDlPrepare,
          trailing: _buildDelete(status.fileName, status.id),
        );
      case SftpWorkerStatus.sshConnectted:
        return _wrapInCard(
          status: status,
          subtitle: _s.sftpSSHConnected,
          trailing: _buildDelete(status.fileName, status.id),
        );
      default:
        return _wrapInCard(
          status: status,
          subtitle: _s.unknown,
          trailing: IconButton(
            onPressed: () => showRoundDialog(
              context: context,
              title: Text(_s.error),
              child: Text((status.error ?? _s.unknown).toString()),
            ),
            icon: const Icon(Icons.error),
          ),
        );
    }
  }

  Widget _wrapInCard({
    required SftpReqStatus status,
    String? subtitle,
    Widget? trailing,
  }) {
    final time = DateTime.fromMicrosecondsSinceEpoch(status.id);
    return RoundRectCard(
      ListTile(
        leading: Text(time.hourMinute),
        title: Text(
          status.fileName,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: grey,
              ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildDelete(String name, int id) {
    return IconButton(
      onPressed: () => showRoundDialog(
          context: context,
          title: Text(_s.attention),
          child: Text(_s.sureDelete(name)),
          actions: [
            TextButton(
              onPressed: () {
                locator<SftpProvider>().cancel(id);
                context.pop();
              },
              child: Text(_s.ok),
            ),
          ]),
      icon: const Icon(Icons.delete),
    );
  }
}
