import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/sftp/worker.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/view/page/storage/local.dart';

class SftpMissionPage extends StatefulWidget {
  const SftpMissionPage({super.key});

  @override
  State<SftpMissionPage> createState() => _SftpMissionPageState();
}

class _SftpMissionPageState extends State<SftpMissionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.mission, style: UIs.text18),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SftpProvider.status.listenVal((status) {
      if (status.isEmpty) {
        return Center(child: Text(libL10n.empty));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(11),
        itemCount: status.length,
        itemBuilder: (context, index) {
          return _buildItem(status[index]);
        },
      );
    });
  }

  Widget _buildItem(SftpReqStatus status) {
    final err = status.error;
    if (err != null) {
      return _wrapInCard(
        status: status,
        subtitle: libL10n.error,
        trailing: IconButton(
          onPressed: () => context.showRoundDialog(
            title: libL10n.error,
            child: Text(err.toString()),
          ),
          icon: const Icon(Icons.error),
        ),
      );
    }
    return switch (status.status) {
      const (SftpWorkerStatus.finished) => _buildFinished(status),
      const (SftpWorkerStatus.loading) => _buildLoading(status),
      const (SftpWorkerStatus.sshConnectted) => _buildConnected(status),
      const (SftpWorkerStatus.preparing) => _buildPreparing(status),
      _ => _buildDefault(status),
    };
  }

  Widget _buildPreparing(SftpReqStatus status) {
    return _wrapInCard(
      status: status,
      subtitle: l10n.sftpDlPrepare,
      trailing: _buildDelete(status.fileName, status.id),
    );
  }

  Widget _buildDefault(SftpReqStatus status) {
    return _wrapInCard(
      status: status,
      subtitle: l10n.unknown,
      trailing: IconButton(
        onPressed: () => context.showRoundDialog(
          title: libL10n.error,
          child: Text((status.error ?? l10n.unknown).toString()),
        ),
        icon: const Icon(Icons.error),
      ),
    );
  }

  Widget _buildConnected(SftpReqStatus status) {
    return _wrapInCard(
      status: status,
      subtitle: l10n.sftpSSHConnected,
      trailing: _buildDelete(status.fileName, status.id),
    );
  }

  Widget _buildLoading(SftpReqStatus status) {
    final percentStr = (status.progress ?? 0.0).toStringAsFixed(2);
    final size = (status.size ?? 0).bytes2Str;
    return _wrapInCard(
      status: status,
      subtitle: l10n.percentOfSize(percentStr, size),
      trailing: _buildDelete(status.fileName, status.id),
    );
  }

  Widget _buildFinished(SftpReqStatus status) {
    final time = status.spentTime.toString();
    final str = l10n.spentTime(
      time == 'null' ? l10n.unknown : (time.substring(0, time.length - 7)),
    );

    final btns = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            final idx = status.req.localPath.lastIndexOf(Pfs.seperator);
            final dir = status.req.localPath.substring(0, idx);
            LocalFilePage.route.go(
              context,
              args: LocalFilePageArgs(initDir: dir),
            );
          },
          icon: const Icon(Icons.file_open),
        ),
        IconButton(
          onPressed: () => Pfs.share(path: status.req.localPath),
          icon: const Icon(Icons.open_in_new),
        )
      ],
    );

    return _wrapInCard(
      status: status,
      subtitle: str,
      trailing: btns,
    );
  }

  Widget _wrapInCard({
    required SftpReqStatus status,
    String? subtitle,
    Widget? trailing,
  }) {
    final time = DateTime.fromMicrosecondsSinceEpoch(status.id);
    return CardX(
      child: ListTile(
        leading: Text(time.hourMinute),
        title: Text(
          status.fileName,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: subtitle == null ? null : Text(subtitle, style: UIs.textGrey),
        trailing: trailing,
      ),
    );
  }

  Widget _buildDelete(String name, int id) {
    return IconButton(
      onPressed: () => context.showRoundDialog(
        title: libL10n.attention,
        child: Text(libL10n.askContinue(
          '${libL10n.delete} ${l10n.mission}($name)',
        )),
        actions: Btn.ok(
          onTap: () {
            SftpProvider.cancel(id);
            context.pop();
          },
        ).toList,
      ),
      icon: const Icon(Icons.delete),
    );
  }
}
