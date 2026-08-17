import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/provider/file_transfer.dart';

/// How long a transfer has to still be running to be worth mentioning.
///
/// A copy within this device finishes in less time than it takes to read the
/// word "added", and then the message points at a list with nothing in it.
const _announceAfter = Duration(milliseconds: 500);

/// Says that transfers were queued, unless they have already finished.
///
/// [ids] are what `FileTransferNotifier.add` returned. A row that is gone by
/// the time this looks counts as finished: it was removed, which only happens
/// after it ended.
Future<void> announceQueued(
  BuildContext context,
  WidgetRef ref,
  Iterable<int> ids,
) async {
  if (ids.isEmpty) return;
  await Future<void>.delayed(_announceAfter);
  if (!context.mounted) return;

  final queue = ref.read(fileTransferProvider.notifier);
  final running = ids.any((id) {
    final status = queue.get(id);
    if (status == null) return false;
    return status.status != FileTransferStage.finished;
  });
  if (running) Toast.show(context.l10n.added2List);
}
