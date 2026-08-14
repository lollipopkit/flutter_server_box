import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/file_transfer.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/sftp.dart';

/// Ask where [source] should go, and queue the transfer.
///
/// [isDir] because a directory is a whole tree, and the two fast single-file
/// paths cannot carry one — the browser knows which it is, having listed it.
///
/// One flow for every pair. It used to be two half-flows that between them
/// could only express a server and this device: the local page's "upload"
/// picked a server, and the SFTP page's "download" picked nothing at all
/// because there was only one place a download could land. Neither could name
/// two servers, and neither could name this device twice.
Future<void> sendTo(
  BuildContext context,
  WidgetRef ref, {
  required FileRef source,
  required bool isDir,
}) async {
  final place = await _pickPlace(context, ref);
  if (place == null || !context.mounted) return;

  final dir = await _pickDir(context, place);
  if (dir == null || !context.mounted) return;

  final destination = switch (place) {
    _Device() => LocalFileRef(dir).child(source.name),
    _Server(:final spi) => SftpFileRef.forServer(spi, dir).child(source.name),
  };

  // Copying a file onto itself truncates it to nothing: the write opens the
  // destination before the read has finished with it.
  if (destination == source) {
    context.showSnackBar(libL10n.fail);
    return;
  }

  ref
      .read(fileTransferProvider.notifier)
      .add(FileTransfer(from: source, to: destination, isDir: isDir));
  context.showSnackBar(l10n.added2List);
}

/// Somewhere files can be put.
sealed class _Place {
  const _Place();
}

final class _Device extends _Place {
  const _Device();
}

final class _Server extends _Place {
  const _Server(this.spi);
  final Spi spi;
}

/// This device, or one of the servers that can carry files.
///
/// A picker rather than the file tab's own list, because this is a question
/// about one file and answering it should not disturb what is open.
Future<_Place?> _pickPlace(BuildContext context, WidgetRef ref) async {
  final state = ref.read(serversProvider);
  final servers = [
    for (final id in state.serverOrder)
      if (state.servers[id] case final spi? when canTransferTo(spi)) spi,
  ];

  return context.showRoundDialog<_Place>(
    title: libL10n.select,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Btn.tile(
            icon: const Icon(Icons.smartphone),
            text: libL10n.device,
            onTap: () => context.popDialog(const _Device()),
          ),
          for (final spi in servers)
            Btn.tile(
              icon: const Icon(Icons.dns),
              text: spi.name,
              onTap: () => context.popDialog(_Server(spi)),
            ),
        ],
      ),
    ),
  );
}

/// Which directory there, in that place's own browser.
Future<String?> _pickDir(BuildContext context, _Place place) => switch (place) {
  _Device() => LocalFilePage.route.go(
    context,
    args: const LocalFilePageArgs(isPickDir: true),
  ),
  _Server(:final spi) => SftpPage.route.go(
    context,
    SftpPageArgs(spi: spi, isSelect: true),
  ),
};

/// Whether a server's files can be reached at all.
///
/// The same question the file tab asks before listing a server, asked here so
/// a destination that could never be written to is not offered.
bool canTransferTo(Spi spi) =>
    ServerCapabilities.of(ServerConnectCredential.fromSpi(spi)).files;
