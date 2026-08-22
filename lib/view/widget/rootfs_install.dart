import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/res/store.dart';

/// Puts a Linux userland on this device, asking first.
///
/// Returns whether there is one to enter afterwards — already installed counts.
///
/// This is a download of executable code, so it says so before starting rather
/// than fetching several megabytes on a tap. What makes it safe to run is in
/// `LinuxDistro`: the release is pinned and its digest is checked.
///
/// TODO(distribution residue; remove when a second one ships): `rootfsInstallTip`
/// and `rootfsUpdateTip` name Alpine in all fifteen locales. Both are accurate
/// while it is the only installable one, and both need a `{distro}` placeholder
/// the moment that stops being true.
Future<bool> installRootfs(
  BuildContext context, {
  LinuxProfile? into,
  bool another = false,
  String? label,
}) async {
  // Both platforms fetch the same release of the same distribution; what
  // differs is what they do with it — Android unpacks a rootfs for proot, iOS a
  // tree for the engine — and neither difference reaches this dialog.
  final present = isIOS
      ? await IosRootfs.isInstalled
      : await AndroidRootfs.isInstalled;
  final selected = Rootfs.selected;
  // This early return is for the one caller that means "there has to be one to
  // enter": a terminal was opened and had nothing to open into. Adding another
  // and replacing one both mean to install *although* something is there, and
  // both were silently doing nothing.
  //
  // An outdated one is still one, so the terminal path does not offer to
  // replace it: that means downloading the release again and losing everything
  // installed in the old tree, which is a decision and not something to raise
  // in the way of opening a terminal.
  if (present && into == null && !another) return true;
  if (!context.mounted) return false;

  // Before anything is downloaded, because this is where the feature is first
  // met: a system has to be installed before it can be entered, so a warning
  // here is one nobody reaches a Linux shell without having seen.
  if (!await _confirmBeta(context)) return present || selected != null;
  if (!context.mounted) return false;

  final distro = into?.distro ?? Rootfs.nextDistro;
  final confirm = await context.showRoundDialog<bool>(
    // Capitalised: the shared string is a verb used mid-sentence elsewhere,
    // and a dialog title is not mid-sentence.
    title: into == null ? libL10n.install.capitalize : libL10n.update,
    child: Text(
      into == null
          ? context.l10n.rootfsInstallTip(distro.version)
          : context.l10n.rootfsUpdateTip(into.version, distro.version),
    ),
    actions: Btnx.cancelOk,
  );
  if (confirm != true) return present || selected != null;
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
    await Rootfs.install(
      distro: distro,
      into: into,
      label: label,
      onProgress: (value) => progress.value = value,
      cancel: cancel,
    );
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

/// Says that the Linux feature is beta, once, and lets it be dismissed for
/// good. Returns whether to go on.
///
/// Its own dialog rather than a line added to the install confirmation: that
/// one asks about downloading a particular release, and answering it yes is
/// not the same as having read this.
///
/// The flag is written only when the answer is yes. A box ticked on a dialog
/// that was then cancelled has agreed to nothing, and writing on the tick — as
/// the port forward warning does, where there is nothing to cancel — would
/// suppress a warning the user backed out of.
Future<bool> _confirmBeta(BuildContext context) async {
  if (Stores.setting.linuxBetaWarned.fetch()) return true;
  var noMore = false;
  final ok = await context.showRoundDialog<bool>(
    title: libL10n.attention,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(context.l10n.betaTip)),
        UIs.height13,
        StatefulBuilder(
          builder: (_, setState) => Row(
            children: [
              Checkbox(
                value: noMore,
                onChanged: (v) => setState(() => noMore = v ?? false),
              ),
              Text(l10n.noPromptAgain),
            ],
          ),
        ),
      ],
    ),
    actions: Btnx.cancelOk,
  );
  if (ok != true) return false;
  if (noMore) Stores.setting.linuxBetaWarned.put(true);
  return true;
}

/// Removes one Linux system, asking first.
///
/// Everything installed inside it goes too, which is why this asks in the same
/// words as deleting anything else. The others are untouched.
Future<bool> removeRootfs(BuildContext context, {LinuxProfile? profile}) async {
  final target = profile ?? Rootfs.selected;
  if (target == null) return false;
  final confirm = await context.showRoundDialog<bool>(
    title: libL10n.attention,
    child: Text(libL10n.askContinue('${libL10n.delete} ${target.label}')),
    actions: Btnx.cancelRedOk,
  );
  if (confirm != true) return false;
  try {
    await Rootfs.removeProfile(target.id);
  } catch (e, s) {
    // Refused rather than half-done: the tree is still there, and so is
    // whatever was using it. Deleting it anyway is what froze the app.
    Loggers.app.warning('Remove ${target.id}', e, s);
    if (context.mounted) Toast.error('${libL10n.fail}: $e');
    return false;
  }
  return true;
}
