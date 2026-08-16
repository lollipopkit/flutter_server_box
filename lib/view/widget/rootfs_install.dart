import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/rootfs.dart';

/// Puts a Linux userland on this device, asking first.
///
/// Returns whether there is one to enter afterwards — already installed counts.
///
/// This is a download of executable code, so it says so before starting rather
/// than fetching several megabytes on a tap. What makes it safe to run is in
/// [AndroidRootfs]: the release is pinned and its digest is checked.
Future<bool> installRootfs(BuildContext context) async {
  // Both platforms fetch the same Alpine release; what differs is what they do
  // with it — Android unpacks a rootfs for proot, iOS a tree for the engine —
  // and neither difference reaches this dialog.
  final present = isIOS
      ? await IosRootfs.isInstalled
      : await AndroidRootfs.isInstalled;
  // Asked once, on the way in, and answered either way: a rootfs that is
  // merely old still works, so declining leaves it running rather than
  // blocking the terminal that was actually being opened.
  final replacing = present && !isIOS && AndroidRootfs.isOutdated;
  if (present && !replacing) return true;
  if (!context.mounted) return false;

  final confirm = await context.showRoundDialog<bool>(
    // Capitalised: the shared string is a verb used mid-sentence elsewhere,
    // and a dialog title is not mid-sentence.
    title: replacing ? libL10n.update : libL10n.install.capitalize,
    child: Text(
      replacing
          ? context.l10n.rootfsUpdateTip(
              AndroidRootfs.installedVersion ?? '',
              AndroidRootfs.version,
            )
          : context.l10n.rootfsInstallTip(Rootfs.version),
    ),
    actions: Btnx.cancelOk,
  );
  // An old rootfs is still a rootfs. Saying no here opens the one that is
  // already there, which is what "not forced" has to mean.
  if (confirm != true) return present;
  if (!context.mounted) return false;

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
    if (isIOS) {
      await IosRootfs.install(
        onProgress: (value) => progress.value = value,
        cancel: cancel,
      );
    } else {
      await AndroidRootfs.install(
        onProgress: (value) => progress.value = value,
        cancel: cancel,
        replace: replacing,
      );
    }
    if (context.mounted) context.popDialog();
    return true;
  } catch (e, s) {
    if (!context.mounted) return false;
    context.popDialog();
    if (!cancelled) context.showErrDialog(e, s);
    // A failed *replacement* took the old one with it — `install` deletes what
    // it cannot finish, so there is nothing left to fall back to.
    return false;
  } finally {
    progress.dispose();
  }
}

/// Removes the Linux userland, asking first.
///
/// Everything installed inside it goes too, which is why this asks in the same
/// words as deleting anything else.
Future<bool> removeRootfs(BuildContext context) async {
  final confirm = await context.showRoundDialog<bool>(
    title: libL10n.attention,
    child: Text(libL10n.askContinue('${libL10n.delete} Alpine')),
    actions: Btnx.cancelRedOk,
  );
  if (confirm != true) return false;
  if (isIOS) {
    await IosRootfs.remove();
  } else {
    await AndroidRootfs.remove();
  }
  return true;
}
