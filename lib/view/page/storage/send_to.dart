import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/file_transfer.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/server_file.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/page/storage/transfer_announce.dart';

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
  bool reuseDestination = false,
}) async {
  final _Destination? chosen;
  if (reuseDestination && _last != null) {
    chosen = _last;
  } else {
    final place = await _pickPlace(context, ref);
    if (place == null || !context.mounted) return;

    final dir = await _pickDir(context, place);
    if (dir == null || !context.mounted) return;
    chosen = _Destination(place, dir);
    _last = chosen;
  }
  final place = chosen!.place;
  final dir = chosen.dir;

  final destination = switch (place) {
    _Device() => LocalFileRef(dir).child(source.name),
    // The same order `ServerFilePage` browses in, so what a file is sent over
    // is what the browser showed it over.
    _Server(:final spi) => serverFileRef(ref, spi, dir).child(source.name),
  };

  // Copying a file onto itself truncates it to nothing: the write opens the
  // destination before the read has finished with it.
  if (destination == source) {
    Toast.error(libL10n.fail);
    return;
  }

  final id = ref
      .read(fileTransferProvider.notifier)
      .add(FileTransfer(from: source, to: destination, isDir: isDir));
  await announceQueued(context, ref, [id]);
}

/// Where the last send went, so a batch asks once rather than once per file.
///
/// Deliberately not remembered across a batch's end: "the same place as last
/// time" is a guess, and a guess about where a file lands is the wrong thing
/// to be confident about.
_Destination? _last;

class _Destination {
  const _Destination(this.place, this.dir);
  final _Place place;
  final String dir;
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
      if (state.servers[id] case final spi? when canTransferTo(ref, spi)) spi,
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
  // The resolving page, not the SFTP one: a destination reached through its
  // agent's file API is still a place a file can be sent to.
  _Server(:final spi) => ServerFilePage.route.go(
    context,
    SftpPageArgs(spi: spi, isSelect: true),
  ),
};

/// How to name a path on [spi], by whichever way its files are reached.
///
/// One place, so the browser and the transfer engine cannot disagree about
/// what a server's files are — a file browsed over SFTP and then sent over the
/// agent's API would be two different filesystems on hosts where the roots do
/// not line up.
FileRef serverFileRef(WidgetRef ref, Spi spi, String path) {
  final caps = ref.read(serverProvider(spi.id)).capabilities;
  return caps.byteStream
      ? SftpFileRef.forServer(spi, path)
      : MonitorFileRef.forServer(spi, path);
}

/// Whether a server's files can be reached at all.
///
/// The same question the file tab asks before listing a server, asked here so
/// a destination that could never be written to is not offered.
///
/// Takes a [ref] because the answer is partly the agent's: a monitor server's
/// file API is a grant it reports on `/capabilities`, and building the
/// capabilities without it defaults every agent to "grants nothing" — which
/// silently hid every monitor-backed server from the picker, the rail and this
/// list, and made the file API unreachable from the app entirely.
bool canTransferTo(WidgetRef ref, Spi spi) => ref.watch(
  serverProvider(spi.id).select((state) => state.capabilities.files),
);
