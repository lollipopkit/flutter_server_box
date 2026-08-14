import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/android_rootfs.dart';

/// Puts a Linux userland on this device, asking first.
///
/// Returns whether there is one to enter afterwards — already installed counts.
///
/// This is a download of executable code, so it says so before starting rather
/// than fetching several megabytes on a tap. What makes it safe to run is in
/// [AndroidRootfs]: the release is pinned and its digest is checked.
Future<bool> installAndroidRootfs(BuildContext context) async {
  if (await AndroidRootfs.isInstalled) return true;
  if (!context.mounted) return false;

  final confirm = await context.showRoundDialog<bool>(
    // Capitalised: the shared string is a verb used mid-sentence elsewhere,
    // and a dialog title is not mid-sentence.
    title: libL10n.install.capitalize,
    child: Text(context.l10n.rootfsInstallTip(AndroidRootfs.version)),
    actions: Btnx.cancelOk,
  );
  if (confirm != true || !context.mounted) return false;

  final progress = ValueNotifier<double?>(null);
  final cancel = CancelToken();
  // Told apart from a failure: someone who cancelled knows why it stopped, and
  // an error dialog about their own tap is noise.
  var cancelled = false;

  // Not awaited: this dialog has no answer to give. It is closed below, when
  // the work it is describing ends — which is the only thing that should close
  // it, so there is no barrier dismiss either.
  unawaited(
    context.showRoundDialog(
      title: libL10n.download,
      child: ValueListenableBuilder(
        valueListenable: progress,
        builder: (_, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: value),
            UIs.height13,
            // Indeterminate until the server says how large it is, which it
            // may never do.
            Text(
              value == null ? '...' : '${(value * 100).toStringAsFixed(0)}%',
              style: UIs.text13Grey,
            ),
          ],
        ),
      ),
      barrierDismiss: false,
      actions: [
        Btn.text(
          text: libL10n.cancel,
          onTap: () {
            cancelled = true;
            cancel.cancel();
          },
        ),
      ],
    ),
  );

  try {
    await AndroidRootfs.install(
      onProgress: (value) => progress.value = value,
      cancel: cancel,
    );
    if (context.mounted) context.popDialog();
    return true;
  } catch (e, s) {
    if (!context.mounted) return false;
    context.popDialog();
    if (!cancelled) context.showErrDialog(e, s);
    return false;
  } finally {
    progress.dispose();
  }
}

/// Removes the Linux userland, asking first.
///
/// Everything installed inside it goes too, which is why this asks in the same
/// words as deleting anything else.
Future<bool> removeAndroidRootfs(BuildContext context) async {
  final confirm = await context.showRoundDialog<bool>(
    title: libL10n.attention,
    child: Text(libL10n.askContinue('${libL10n.delete} Alpine')),
    actions: Btnx.cancelRedOk,
  );
  if (confirm != true) return false;
  await AndroidRootfs.remove();
  return true;
}
