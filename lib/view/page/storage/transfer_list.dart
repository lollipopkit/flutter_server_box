import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_status.dart';
import 'package:server_box/data/provider/file_transfer.dart';
import 'package:server_box/data/res/default.dart';
import 'package:server_box/view/page/storage/local.dart';

/// Every transfer, running and finished.
///
/// Was the SFTP mission list, when a transfer had exactly one remote end and
/// the list could say "this file" and mean the local one. It now names both
/// ends, because either of them can be a server and both of them can be this
/// device.
/// The transfers, as a page.
///
/// What a narrow window gets, and what anything outside the file tab gets:
/// there is no second column to put them in.
class TransferListPage extends ConsumerStatefulWidget {
  const TransferListPage({super.key});

  @override
  ConsumerState<TransferListPage> createState() => _TransferListPageState();

  static const route = AppRouteNoArg(
    page: TransferListPage.new,
    path: '/files/transfers',
  );
}

class _TransferListPageState extends ConsumerState<TransferListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(libL10n.mission, style: UIs.text18)),
      body: const TransferListView(),
    );
  }
}

/// The transfers, as a body.
///
/// Split out so the file tab can show them in the column beside its rail
/// rather than pushing a page over the whole window — including over the rail,
/// which is where someone goes to get back.
class TransferListView extends ConsumerStatefulWidget {
  const TransferListView({super.key});

  @override
  ConsumerState<TransferListView> createState() => _TransferListViewState();
}

class _TransferListViewState extends ConsumerState<TransferListView> {
  Timer? _speedRefreshTimer;

  @override
  void initState() {
    super.initState();
    final interval =
        serverStatusRefreshInterval() ??
        const Duration(seconds: Defaults.updateInterval);
    _speedRefreshTimer = Timer.periodic(interval, (_) {
      ref.read(fileTransferProvider.notifier).refreshTransferSpeeds();
    });
  }

  @override
  void dispose() {
    _speedRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildBody();

  Widget _buildBody() {
    final transfers = ref.watch(fileTransferProvider).transfers;
    if (transfers.isEmpty) {
      return Center(child: Text(libL10n.empty));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(11),
      itemCount: transfers.length,
      itemBuilder: (context, index) => _buildItem(transfers[index]),
    );
  }

  Widget _buildItem(FileTransferStatus status) {
    final err = status.error;
    if (err != null) {
      return _wrapInCard(
        status: status,
        subtitle: libL10n.error,
        trailing: IconButton(tooltip: libL10n.error, 
          onPressed: () => context.showRoundDialog(
            title: libL10n.error,
            child: Text(err.toString()),
          ),
          icon: const Icon(Icons.error),
        ),
      );
    }
    return switch (status.status) {
      FileTransferStage.finished => _buildFinished(status),
      FileTransferStage.loading => _buildLoading(status),
      FileTransferStage.connected => _wrapInCard(
        status: status,
        subtitle: l10n.sftpSSHConnected,
        trailing: _buildDelete(status),
      ),
      FileTransferStage.preparing || null => _wrapInCard(
        status: status,
        subtitle: l10n.sftpDlPrepare,
        trailing: _buildDelete(status),
      ),
    };
  }

  Widget _buildLoading(FileTransferStatus status) {
    final percentStr = (status.progress ?? 0.0).toStringAsFixed(2);
    final transferred = (status.transferredBytes ?? 0).bytes2Str;
    final size = (status.size ?? 0).bytes2Str;
    final speed = '${(status.speedBytesPerSecond ?? 0).bytes2Str}/s';
    return _wrapInCard(
      status: status,
      subtitle: '$transferred / $size - $percentStr% - ${libL10n.speed}: $speed',
      trailing: _buildDelete(status),
    );
  }

  Widget _buildFinished(FileTransferStatus status) {
    final time = status.spentTime.toString();
    final str = l10n.spentTime(
      time == 'null' ? libL10n.unknown : (time.substring(0, time.length - 7)),
    );

    // Only where the file actually landed on this device. A server-to-server
    // transfer has nothing here to open, and offering it would open the wrong
    // thing.
    final landed = status.job.to;
    final btns = landed is! LocalFileRef
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(tooltip: libL10n.open, 
                onPressed: () {
                  final idx = landed.path.lastIndexOf(Pfs.seperator);
                  LocalFilePage.route.go(
                    context,
                    args: LocalFilePageArgs(
                      initDir: landed.path.substring(0, idx),
                    ),
                  );
                },
                icon: const Icon(Icons.file_open),
              ),
              IconButton(tooltip: libL10n.share, 
                onPressed: () => Pfs.sharePaths(
                  paths: [LocalFileBackend.nativePath(landed.path)],
                ),
                icon: const Icon(Icons.open_in_new),
              ),
            ],
          );

    return _wrapInCard(status: status, subtitle: str, trailing: btns);
  }

  Widget _wrapInCard({
    required FileTransferStatus status,
    String? subtitle,
    Widget? trailing,
  }) {
    return CardX(
      child: ListTile(
        leading: Text(status.startedAt.hourMinute),
        title: Text(
          status.fileName,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Which two places, because either end can now be anywhere.
            Text(
              '${_endName(status.job.from)} → ${_endName(status.job.to)}',
              style: UIs.text11Grey,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (subtitle != null) Text(subtitle, style: UIs.textGrey),
          ],
        ),
        trailing: trailing,
      ),
    );
  }

  /// The place, not the transport: a server is a server whether its bytes
  /// come over SFTP or over its agent's file API.
  static String _endName(FileRef ref) => switch (ref) {
    LocalFileRef() => libL10n.device,
    SshFileRef(:final spi) => spi.name,
    MonitorFileRef(:final spi) => spi.name,
  };

  Widget _buildDelete(FileTransferStatus status) {
    return IconButton(tooltip: libL10n.delete, 
      onPressed: () => context.showRoundDialog(
        title: libL10n.attention,
        child: Text(
          libL10n.askContinue(
            '${libL10n.delete} ${libL10n.mission}(${status.fileName})',
          ),
        ),
        actions: Btn.ok(
          onTap: () {
            ref.read(fileTransferProvider.notifier).cancel(status.id);
            context.popDialog();
          },
        ).toList,
      ),
      icon: const Icon(Icons.delete),
    );
  }
}
