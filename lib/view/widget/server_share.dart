import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server_share.dart';
import 'package:server_box/data/model/app/share/server_share.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';

/// Handing one server to another device, and taking one in.
///
/// The two carriers are one decision made twice: a QR is scanned in a room and
/// protected by a code read out loud, a file is saved and protected by a
/// passphrase. Everything that differs between them — the KDF cost, whether
/// the payload expires, what the prompt asks for — follows from that, and is
/// named on [ShareCarrier] rather than decided here.
abstract final class ServerShareUi {
  /// The extension the payload is written under.
  ///
  /// Its own, rather than `.json`: it is what the platforms are told to open
  /// with this app, and claiming `.json` would mean claiming every JSON file
  /// on the device.
  static const fileExt = 'sbxsrv';

  // ---------------------------------------------------------------- sending

  static Future<void> send(BuildContext context, Spi spi) async {
    final omissions = ServerShare.omissionsOf(spi);
    // Built once to measure, and again per carrier — `expiresAt` differs, and
    // a payload is cheap next to the key derivation.
    final probe = ServerShare.of(spi, ttl: ShareCarrier.qr.ttl);
    final fits = ServerShareCodec.fitsInQr(probe);

    final carrier = await context.showRoundDialog<ShareCarrier>(
      title: l10n.shareVia,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (probe.keys.isNotEmpty)
            Text(l10n.shareIncludesKey, style: UIs.text13Grey),
          if (omissions.isNotEmpty) ...[
            UIs.height13,
            Text(l10n.shareOmittedTip, style: UIs.text13Grey),
            for (final it in omissions)
              Text('· ${_omissionText(it)}', style: UIs.text13Grey),
          ],
          UIs.height13,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code),
            title: const Text('QR'),
            subtitle: fits ? null : Text(l10n.shareTooBigForQr),
            enabled: fits,
            onTap: () => context.popDialog(ShareCarrier.qr),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_present),
            title: Text(libL10n.file),
            onTap: () => context.popDialog(ShareCarrier.file),
          ),
        ],
      ),
      actions: Btn.cancel().toList,
    );
    if (carrier == null || !context.mounted) return;

    // The sending half. Which carrier is chosen is a real question: the QR is
    // the shorter path and the one this feature was built around, and it is
    // only offered when the payload fits — so `fits: false` here is a server
    // whose owner was pushed onto the file path by something they cannot see.
    Diag.crumb(
      SbDiag.share,
      'sent',
      data: {
        'via': carrier.name,
        'fits': '$fits',
        'keys': '${probe.keys.length}',
        'omitted': '${omissions.length}',
      },
    );

    switch (carrier) {
      case ShareCarrier.qr:
        await _sendQr(context, spi);
      case ShareCarrier.file:
        await _sendFile(context, spi);
    }
  }

  static Future<void> _sendQr(BuildContext context, Spi spi) async {
    final code = ServerShareCodec.generateCode();
    final share = ServerShare.of(spi, ttl: ShareCarrier.qr.ttl);

    final (text, err) = await context.showLoadingDialog(
      fn: () => ServerShareCodec.encodeAsync(share, code, ShareCarrier.qr),
    );
    if (text == null || err != null || !context.mounted) return;

    await context.showRoundDialog(
      title: libL10n.share,
      child: ConstrainedBox(
        // Without a cap the hint's intrinsic width sets the dialog's, and the
        // QR fills whatever it is given — on a desktop window that is a code
        // the height of the screen. A max, so a narrow phone still gets less.
        constraints: const BoxConstraints(maxWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrView(data: text, tip: spi.name, tip2: '${libL10n.server} ~ ServerBox'),
              UIs.height13,
              Text(l10n.shareCodeTitle, style: UIs.text13Grey),
              SelectableText(
                // Spaced, because this is read out loud and `114447` is not.
                code.split('').join(' '),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              UIs.height13,
              Text(l10n.shareCodeHint, style: UIs.text13Grey),
              Text(
                l10n.shareQrTip(ShareCarrier.qr.ttl!.inMinutes),
                style: UIs.text13Grey,
              ),
            ],
          ),
        ),
      ),
      actions: Btnx.oks,
    );
  }

  static Future<void> _sendFile(BuildContext context, Spi spi) async {
    final pwd = await _askSecret(context, digitsOnly: false);
    if (pwd == null || !context.mounted) return;

    final share = ServerShare.of(spi);
    final (text, err) = await context.showLoadingDialog(
      fn: () => ServerShareCodec.encodeAsync(share, pwd, ShareCarrier.file),
    );
    if (text == null || err != null) return;

    // A temp directory, not `Paths.doc`. On desktop `sharePaths` *reveals* the
    // file rather than sending it, so writing it beside `store.db` pointed the
    // user's file manager straight at the app's private data — and the
    // encrypted copy of the server's password and key stayed there, one per
    // share, with nothing listing or removing them.
    final dir = await Directory.systemTemp.createTemp('sbx-share-');
    final file = File(dir.path.joinPath('${_fileName(spi.name)}.$fileExt'));
    try {
      await file.writeAsString(text);
      await Pfs.sharePaths(paths: [file.path], title: spi.name);
    } catch (e, s) {
      if (context.mounted) context.showErrDialog(e, s, libL10n.share);
      Loggers.app.warning('Share server as file', e, s);
    } finally {
      // On mobile the sheet is done with the file by the time `sharePaths`
      // returns. On desktop the file manager is now showing it, so it has to
      // outlive this call — the OS clears the temp directory instead, which is
      // a worse guarantee than deleting it and the only one available.
      if (isMobile) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// A file name that survives every platform's rules.
  ///
  /// A server may be named `a/b`, `..`, or 200 characters of emoji.
  static String _fileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'^\.+'), '')
        .trim();
    if (cleaned.isEmpty) return 'server';
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }

  // -------------------------------------------------------------- receiving

  /// Scan a code and take in whatever it holds.
  static Future<void> receiveFromQr(BuildContext context, WidgetRef ref) async {
    final scanned = await BarcodeScannerPage.route.go(
      context,
      args: const BarcodeScannerPageArgs(),
    );
    final text = scanned?.text;
    if (text == null || !context.mounted) return;
    await consume(context, ref, text, digitsOnly: true);
  }

  /// Pick a `.sbxsrv` file and take in whatever it holds.
  static Future<void> receiveFromFile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Guarded, because the picker offers every file and `pickFileString`
    // reads whatever is chosen as UTF-8. A binary or a mis-encoded file throws
    // out of here, and an unhandled async error is a button that reads as
    // broken: no dialog, no toast, nothing on screen changing.
    String? text;
    try {
      text = await Pfs.pickFileString();
    } catch (e, s) {
      Loggers.app.warning('Pick a share file', e, s);
      if (context.mounted) Toast.show(l10n.shareUnreadable);
      return;
    }
    if (text == null || text.isEmpty || !context.mounted) return;
    await consume(context, ref, text, digitsOnly: false);
  }

  /// The one path every carrier ends on.
  ///
  /// Public because a third caller reaches it from outside this file: a file
  /// the platform handed the app, which arrives through
  /// `MethodChans.takeOpenedShare` rather than through a picker.
  static Future<void> consume(
    BuildContext context,
    WidgetRef ref,
    String text, {
    required bool digitsOnly,
  }) async {
    String? password;
    if (ServerShareCodec.needsPassword(text)) {
      password = await _askSecret(context, digitsOnly: digitsOnly);
      if (password == null || !context.mounted) return;
    }

    // Caught inside `fn` rather than let out. `showLoadingDialog` answers a
    // throw by popping its spinner and raising `showErrDialog` itself, so an
    // exception that escapes is reported twice — the raw object first, then
    // the sentence [_errorText] wrote for it. A mistyped digit showed
    // `Exception: Failed to decrypt: incorrect password or corrupted data`
    // and, once dismissed, said the same thing again; an expired share led
    // with `ServerShareExpiredException`. Anything still escaping is the
    // dialog's own timeout, which has no better message than the raw one.
    Object? decodeErr;
    final (share, _) = await context.showLoadingDialog<ServerShare?>(
      fn: () async {
        try {
          return await ServerShareCodec.decodeAsync(text, password: password);
        } catch (e) {
          decodeErr = e;
          return null;
        }
      },
    );
    if (!context.mounted) return;
    if (share == null) {
      final err = decodeErr;
      // The half nothing else can see. A share that will not open fails on the
      // *receiving* device, so the one that made it — and the person who was
      // told to scan it — have no record at all. By kind: a wrong code, an
      // expired payload and a build that cannot read the format are three
      // different bugs and look identical from here.
      Diag.crumb(
        SbDiag.share,
        'import failed',
        level: DiagLevel.warning,
        data: {
          'why': err == null ? 'cancelled' : Redact.error(err),
          'encrypted': '${password != null}',
        },
      );
      if (err != null) Toast.show(_errorText(err));
      return;
    }

    final existing = ServerShareInstaller.findExisting(share.spi);
    final confirmed = await context.showRoundDialog<bool>(
      title: l10n.shareImportTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(share.spi.name, style: UIs.text15Bold),
          Text(_addrOf(share.spi), style: UIs.text13Grey),
          if (share.keys.isNotEmpty) ...[
            UIs.height13,
            Text(l10n.shareIncludesKey, style: UIs.text13Grey),
          ],
          if (existing != null) ...[
            UIs.height13,
            Text(l10n.shareServerExists(existing.name), style: UIs.text13Grey),
          ],
        ],
      ),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = ServerShareInstaller.install(share);
      // The stores were written directly, so both providers are holding a list
      // that predates it. `reload` rather than `addServer`: the id, the name
      // and the key reference were all resolved during the install, and
      // handing the result back through the notifier would resolve them twice.
      await ref.read(serversProvider.notifier).reload(refreshConnections: false);
      ref.read(privateKeyProvider.notifier).reload();
      // Whether a key travelled is the part worth knowing: it is the difference
      // between handing over an address and handing over the way in, and it is
      // what decides whether the passphrase prompt is on the ordinary path or
      // the rare one.
      Diag.crumb(
        SbDiag.share,
        'imported',
        data: {
          'keys': '${share.keys.length}',
          'replaced': '${existing != null}',
          'encrypted': '${password != null}',
        },
      );
      Toast.success('${libL10n.success}: ${result.spi.name}');
    } catch (e, s) {
      Diag.crumb(
        SbDiag.share,
        'install failed',
        level: DiagLevel.warning,
        data: {'error': Redact.error(e)},
      );
      if (context.mounted) context.showErrDialog(e, s, libL10n.import);
      Loggers.app.warning('Install shared server', e, s);
    }
  }

  static String _addrOf(Spi spi) {
    final ssh = spi.ssh;
    if (ssh != null) return '${ssh.user}@${ssh.ip}:${ssh.port}';
    return spi.monitorHttp?.addr ?? '';
  }

  // ------------------------------------------------------------------ parts

  /// Asks for the code or the passphrase.
  ///
  /// [digitsOnly] narrows the keyboard and caps the length for the QR
  /// flavour, where the code is always [ServerShareCodec.codeDigits] digits.
  static Future<String?> _askSecret(
    BuildContext context, {
    required bool digitsOnly,
  }) async {
    final controller = TextEditingController();
    final node = FocusNode();
    final ok = await context.showRoundDialog<bool>(
      title: digitsOnly ? l10n.shareCodePrompt : libL10n.pwd,
      // Disposed by the tree: the field holds both while the route animates
      // out, and doing it on every return path means remembering both twice.
      child: DisposeWith(
        notifiers: [controller, node],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!digitsOnly)
              Text(l10n.sharePassphraseTip, style: UIs.text13Grey),
            UIs.height13,
            Input(
              label: digitsOnly ? l10n.shareCodePrompt : libL10n.pwd,
              controller: controller,
              node: node,
              autoFocus: true,
              obscureText: !digitsOnly,
              suggestion: false,
              type: digitsOnly ? TextInputType.number : TextInputType.text,
              maxLines: 1,
              // The counter is the reason, as much as the cap: a code is
              // read out loud, and "4/6" is how the person typing knows they
              // missed one.
              maxLength: digitsOnly ? ServerShareCodec.codeDigits : null,
              onSubmitted: (_) => context.popDialog(true),
            ),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );
    if (ok != true) return null;
    var value = controller.text.trim();
    // A code read out loud gets written down with spaces in it, and the
    // keyboard is only a hint — a desktop keyboard has every other character
    // on it too.
    if (digitsOnly) value = value.replaceAll(RegExp(r'\D'), '');
    return value.isEmpty ? null : value;
  }

  static String _omissionText(ServerShareOmission it) => switch (it) {
    ServerShareOmission.jumpServer => l10n.shareOmittedJump,
    ServerShareOmission.localKeyPath => l10n.shareOmittedKeyPath,
    ServerShareOmission.bmcCredential => l10n.shareOmittedBmc,
    ServerShareOmission.missingKey => l10n.shareOmittedMissingKey,
  };

  /// Each failure gets its own sentence, because each has a different fix.
  ///
  /// A wrong code, an expired share and a payload from a newer build all
  /// arrive here as an exception, and collapsing them into "import failed"
  /// leaves the user with nothing to do about it.
  static String _errorText(Object err) => switch (err) {
    ServerShareExpiredException() => l10n.shareExpired,
    ServerShareTooNewException() => l10n.shareTooNew,
    ServerShareUnreadableException() => l10n.shareUnreadable,
    // What `Cryptor.decrypt` throws for a wrong password, which is by far the
    // likeliest of these and already says so.
    _ => '$err',
  };
}
