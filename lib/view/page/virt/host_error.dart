import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/cert_fingerprint.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/virt/common.dart';

/// A host's failure where its guests would be, with the one action that
/// answers it.
///
/// The action is the answer rather than a generic retry wherever there is one:
/// a TOTP code, the certificate, the sudo password, the server's settings.
/// Repeating the same request would get the same refusal, which is also why
/// the provider stops refreshing on these by itself.
class VirtHostError extends ConsumerWidget {
  const VirtHostError({super.key, required this.serverId, required this.err});

  final String serverId;
  final VirtErr err;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final detail = err.detail;
    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 13, 17, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  err.needsInput ? Icons.info_outline : Icons.error_outline,
                  size: 18,
                  color: err.needsInput ? scheme.primary : scheme.error,
                ),
                UIs.width7,
                Expanded(child: Text(err.title, style: UIs.text15Bold)),
              ],
            ),
            if (detail != null) ...[
              UIs.height7,
              SelectableText(detail, style: UIs.text12Grey),
            ],
            UIs.height7,
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _action(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(virtHostProvider(serverId).notifier);
    return switch (err.type) {
      VirtErrType.needTfa => Btn.text(
        text: l10n.pveOtpLabel,
        onTap: () => unawaited(virtPromptTfa(context, notifier, err)),
      ),
      VirtErrType.certUnconfirmed || VirtErrType.certChanged => Btn.text(
        text: l10n.bmcCert,
        onTap: () => unawaited(virtConfirmCert(context, notifier, err)),
      ),
      VirtErrType.sudoPasswordRequired ||
      VirtErrType.sudoPasswordRejected => Btn.text(
        text: libL10n.sudoPassword,
        onTap: () => unawaited(virtAskSudo(context, notifier)),
      ),
      // Nothing answers it: no server to edit, nothing to retry against.
      VirtErrType.serverRemoved => UIs.placeholder,
      VirtErrType.notConfigured => Btn.text(
        text: libL10n.edit,
        onTap: () {
          final spi = ref.read(serversProvider).servers[serverId];
          if (spi == null) return;
          ServerEditPage.route.go(
            context,
            args: ServerEditArgs(spi, section: ServerEditSection.pve),
          );
        },
      ),
      _ => Btn.text(
        text: libL10n.retry,
        // A new session, not only a new request: the last one may be what
        // failed — an expired ticket, a transport that went away.
        onTap: () => unawaited(notifier.reconnect()),
      ),
    };
  }
}

/// Asks for PVE's second factor and hands it over.
Future<void> virtPromptTfa(
  BuildContext context,
  VirtHostNotifier notifier,
  VirtErr err,
) async {
  final ctrl = TextEditingController();
  final ok = await context.showRoundDialog<bool>(
    title: l10n.pveOtpTitle,
    // Disposed by the tree, since `autoFocus` is the case that breaks when
    // the controller goes before the field does.
    child: DisposeWith(
      notifiers: [ctrl],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(err.message ?? l10n.pveOtpRequired),
          UIs.height13,
          Input(
            controller: ctrl,
            label: l10n.pveOtpLabel,
            hint: '123456',
            icon: Icons.password,
            type: TextInputType.number,
            suggestion: false,
            autoFocus: true,
            // `popDialog`: the dialog is on the root navigator and this
            // context is the tab's — see the dialog rules in CLAUDE.md.
            onSubmitted: (_) => context.popDialog(true),
          ),
        ],
      ),
    ),
    actions: Btnx.cancelOk,
  );
  final code = ctrl.text.trim();
  if (ok != true || !context.mounted) return;
  if (code.isEmpty) {
    Toast.show(l10n.pveOtpCodeRequired);
    return;
  }
  // A wrong code comes back as the host's new state, which the card beside
  // this already shows; the loading dialog's own report is enough on top.
  await context.showLoadingDialog(fn: () => notifier.submitTfa(code));
}

/// Shows the certificate PVE presented and pins it if the user accepts.
///
/// The dialog answers; the pinning happens here, after it has closed.
Future<void> virtConfirmCert(
  BuildContext context,
  VirtHostNotifier notifier,
  VirtErr err,
) async {
  final cert = err.cert;
  if (cert == null) return;
  final changed = err.type == VirtErrType.certChanged;
  final previous = err.previousFingerprint;
  final fmt = DateFormat.yMMMd(l10n.localeName);
  final accepted = await context.showRoundDialog<bool>(
    title: changed
        ? l10n.virtErrCertChanged
        : l10n.remoteDesktopTrustCertificate,
    barrierDismiss: false,
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            changed
                ? l10n.remoteDesktopCertificateChangedTip
                : l10n.remoteDesktopCertificateUnverifiedTip,
          ),
          UIs.height13,
          SelectableText('SHA-256\n${cert.prettyFingerprint}'),
          if (changed && previous != null) ...[
            UIs.height7,
            SelectableText(
              l10n.remoteDesktopPreviousCertificate(
                prettyCertFingerprint(previous),
              ),
            ),
          ],
          UIs.height7,
          SelectableText(l10n.remoteDesktopCertificateSubject(cert.subject)),
          SelectableText(l10n.remoteDesktopCertificateIssuer(cert.issuer)),
          SelectableText(
            l10n.remoteDesktopCertificateValidity(
              fmt.format(cert.startValidity),
              fmt.format(cert.endValidity),
            ),
          ),
          if (cert.isExpired) ...[
            UIs.height7,
            Text(
              l10n.bmcCertExpired,
              style: const TextStyle(color: StatePalette.warn),
            ),
          ],
        ],
      ),
    ),
    actions: [
      Btn.cancel(),
      Btn.text(
        text: changed
            ? l10n.remoteDesktopReplaceTrust
            : l10n.remoteDesktopTrustReconnect,
        textStyle: changed ? UIs.textRed : null,
        onTap: () => context.popDialog(true),
      ),
    ],
  );
  if (accepted != true || !context.mounted) return;
  await context.showLoadingDialog(
    fn: () => notifier.confirmCert(cert.fingerprint),
  );
}

/// Asks for the sudo password libvirt needs on this host. Kept in memory for
/// the host's session only, by the backend.
Future<void> virtAskSudo(
  BuildContext context,
  VirtHostNotifier notifier,
) async {
  final pwd = await context.showPwdDialog(
    title: libL10n.sudoPassword,
    remember: false,
  );
  if (pwd == null || pwd.isEmpty) return;
  await notifier.provideSudoPassword(pwd);
}
