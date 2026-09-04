import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/data/model/app/geo_manifest.dart';
import 'package:server_box/data/res/url.dart';

/// Getting the city data, from wherever somebody noticed they need it.
///
/// **Three callers, one flow, and that is the point.** The settings tile asks
/// for it, turning the globe on asks for it, and the globe itself asks when it
/// has nothing to place servers with. What must not drift between them is the
/// question: the manifest is fetched *before* the dialog so the sizes quoted
/// are this month's rather than a constant compiled into the app, and the
/// confirm button waits three seconds because the attribution is a licence
/// condition rather than a courtesy.
///
/// The globe entry point is the one that matters most. `globeEnabled` is on by
/// default, so most installs never touch the switch — and until the data is
/// here the globe places nothing but hand-typed coordinates. Offering the
/// download beside the servers it could not place puts the question where its
/// answer is obvious, instead of in a settings group nobody has a reason to
/// open.
abstract final class GeoDataInstall {
  static bool _running = false;

  /// Asks, downloads, and answers whether data ended up installed.
  ///
  /// [onProgress] is for a caller with somewhere of its own to draw progress —
  /// the settings tile draws it in the row. Without one this puts up a modal
  /// dialog, because a 25 MB download with nothing on screen saying so is a
  /// quarter of a minute in which the app looks like it ignored the tap.
  ///
  /// False for every outcome that is not "installed", including the user
  /// declining and the month already being current. A caller cannot act on the
  /// difference: in each case what it has is what it had.
  static Future<bool> run(
    BuildContext context, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (_running) return false;
    _running = true;
    try {
      return await _run(context, onProgress: onProgress);
    } finally {
      _running = false;
    }
  }

  static Future<bool> _run(
    BuildContext context, {
    void Function(int received, int total)? onProgress,
  }) async {
    // Indeterminate: nothing knows the size until the manifest is here, and
    // this request is a couple of hundred bytes rather than the download.
    onProgress?.call(0, 0);
    final manifest = await GeoData.fetchManifest();
    if (!context.mounted) return false;

    if (manifest == null) {
      await _fail(context);
      return false;
    }

    final installed = GeoData.installed();
    if (installed != null && installed.generated == manifest.generated) {
      await context.showRoundDialog(
        title: l10n.geoData,
        child: Text(l10n.geoDataCurrent(manifest.generated)),
        actions: Btnx.oks,
      );
      return false;
    }

    if (!await _confirm(context, manifest)) {
      Diag.crumb(SbDiag.globe, 'data declined');
      return false;
    }
    if (!context.mounted) return false;

    final ok = await _download(context, manifest, onProgress);
    Diag.crumb(SbDiag.globe, ok ? 'data installed' : 'data install failed');
    if (!ok && context.mounted) await _fail(context);
    return ok;
  }

  /// The download itself, drawn wherever the caller has room for it.
  static Future<bool> _download(
    BuildContext context,
    GeoManifest manifest,
    void Function(int received, int total)? onProgress,
  ) async {
    if (onProgress != null) {
      onProgress(0, manifest.downloadBytes);
      return GeoData.install(manifest, onProgress: onProgress);
    }

    final progress = ValueNotifier((0, manifest.downloadBytes));
    // Not awaited here: this dialog is closed from below rather than by a
    // button, so waiting on it would wait for the thing this has to close.
    final closed = context.showRoundDialog(
      title: l10n.geoData,
      child: _Progress(progress: progress),
      // No actions. Cancelling mid-download would leave a directory half
      // written, which `install` only cleans up on a failure it saw.
      barrierDismiss: false,
    );
    try {
      return await GeoData.install(
        manifest,
        onProgress: (got, total) => progress.value = (got, total),
      );
    } finally {
      if (context.mounted) context.popDialog();
      // **After the route has gone, not after `pop` was called.** A dialog's
      // future completes when its route is removed, and the exit transition
      // runs first — so disposing here left the outgoing `_Progress` listening
      // to a disposed notifier for the length of it. It survives today only
      // because `removeListener` tolerates the call; anything that wrote
      // `progress.value` on the way out would assert. This repo has the same
      // trap written down at `test/file_browser_test.dart`.
      unawaited(closed.whenComplete(progress.dispose));
    }
  }

  /// What the user is agreeing to, in the two numbers that differ.
  ///
  /// Both, because they answer different questions and one is more than double
  /// the other: the download is what it costs to get, the disk figure is what
  /// it costs to keep. A prompt quoting only the first would understate what
  /// somebody actually agreed to.
  ///
  /// **The confirm button waits three seconds.** CC BY 4.0 requires the credit
  /// travel with the data, and a dialog whose OK is under the cursor before the
  /// text has been seen is a dialog people dismiss without reading. Three
  /// seconds is short enough not to be a punishment and long enough that the
  /// line has been on screen. Cancel is not delayed: nobody needs protecting
  /// from leaving.
  static Future<bool> _confirm(
    BuildContext context,
    GeoManifest manifest,
  ) async {
    final ok = await context.showRoundDialog<bool>(
      title: l10n.geoData,
      child: SingleChildScrollView(
        child: SimpleMarkdown(
          data:
              '${l10n.geoDataConsent(manifest.downloadBytes.bytes2Str, manifest.diskBytes.bytes2Str)}\n\n'
              '`${Urls.geoData}`\n\n'
              // The attribution the *manifest* carries rather than the app's
              // own copy, so a change to the licence line travels with the data
              // it is a condition of.
              '${manifest.attribution.selfNotEmptyOrNull ?? l10n.geoShardsConsentAttribution}',
        ),
      ),
      actions: [
        Btn.cancel(),
        CountDownBtn(text: libL10n.ok, onTap: () => context.popDialog(true)),
      ],
    );
    return ok == true;
  }

  static Future<void> _fail(BuildContext context) => context.showRoundDialog(
    title: libL10n.fail,
    child: Text(l10n.geoDataUnreachable),
    actions: Btnx.oks,
  );
}

/// How far along the download is, as a bar and as two sizes.
///
/// Determinate, because the manifest gives a denominator before the first byte
/// arrives. A spinner in front of a 25 MB download says nothing about whether
/// it is nearly done, which on a phone network is the only question.
class _Progress extends StatelessWidget {
  const _Progress({required this.progress});

  final ValueListenable<(int, int)> progress;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: progress,
      builder: (_, value, _) {
        final (got, total) = value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: total == 0 ? null : got / total),
            UIs.height13,
            Text('${got.bytes2Str} / ${total.bytes2Str}', style: UIs.textGrey),
          ],
        );
      },
    );
  }
}
