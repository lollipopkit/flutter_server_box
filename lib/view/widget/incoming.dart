import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/chan.dart';
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
        // Not awaited: the route completes when the editor closes, and links
        // opened meanwhile must not wait for that.
        unawaited(
          SnippetEditPage.route.go(context, args: SnippetEditPageArgs(script: text)),
        );
      case {'kind': 'files', 'paths': final List<Object?> raw}:
        final paths = raw.whereType<String>().toList();
        List<Future<bool>>? ends;
        try {
          ends = await sendFilesTo(
            context,
            ref,
            sources: [for (final p in paths) LocalFileRef(p)],
          );
        } finally {
          unawaited(discardIncomingAfter(paths, ends));
        }
      default:
        Loggers.app.warning('Unknown incoming content: ${incoming['kind']}');
    }
  }

  /// For [incoming] taken from the inbox but never [open]ed: its copies.
  static void discard(Map<String, Object?> incoming) {
    if (incoming case {'kind': 'files', 'paths': final List<Object?> raw}) {
      unawaited(MethodChans.discardIncoming(raw.whereType<String>().toList()));
    }
  }
}

/// Deletes the copies `IncomingFiles` made of [paths] once [ends] are all
/// answered — at once when nothing was queued. What counts as a copy is
/// decided natively (`IncomingFiles.discardBatch`), never from these paths.
Future<void> discardIncomingAfter(
  List<String> paths,
  List<Future<bool>>? ends,
) async {
  if (ends != null) await Future.wait(ends);
  await MethodChans.discardIncoming(paths);
}
