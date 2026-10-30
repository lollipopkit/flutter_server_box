import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/view/page/snippet/edit.dart';
import 'package:server_box/view/page/storage/send_to.dart';

/// What another app handed over on Android: a share, or selected text.
///
/// Nothing runs by itself. Text opens as a snippet draft, saved only by the
/// user; files are sent wherever the user picks, as any other transfer.
abstract final class IncomingUi {
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> incoming,
  ) async {
    switch (incoming) {
      case {'kind': 'text', 'text': final String text}:
        await SnippetEditPage.route.go(
          context,
          args: SnippetEditPageArgs(script: text),
        );
      case {'kind': 'files', 'paths': final List<Object?> raw}:
        final paths = raw.whereType<String>().toList();
        final ends = await sendFilesTo(
          context,
          ref,
          sources: [for (final p in paths) LocalFileRef(p)],
        );
        unawaited(discardIncomingAfter(paths, ends));
      default:
        Loggers.app.warning('Unknown incoming content: ${incoming['kind']}');
    }
  }
}

/// Deletes the copies `IncomingFiles` made of [paths] once [ends] are all
/// answered — at once when nothing was queued.
///
/// Only a batch directory under the app's own `cache/incoming`: these paths
/// came over a channel, and this deletes what they name.
Future<void> discardIncomingAfter(
  List<String> paths,
  List<Future<bool>>? ends,
) async {
  if (ends != null) await Future.wait(ends);
  try {
    final root = '${(await getTemporaryDirectory()).path}/incoming/';
    final batches = {
      for (final p in paths)
        if (p.startsWith(root)) File(p).parent.path,
    };
    for (final dir in batches) {
      if (File(dir).parent.path != root.substring(0, root.length - 1)) continue;
      await Directory(dir).delete(recursive: true);
    }
  } catch (e, s) {
    Loggers.app.warning('Discard incoming files', e, s);
  }
}
