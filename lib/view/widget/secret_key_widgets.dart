import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// Zero-knowledge and irrecoverable Secret Key warning banner shared by
/// [IntroPage] and [BackupPage].
final class SecretKeyZeroKnowledgeWarning extends StatelessWidget {
  const SecretKeyZeroKnowledgeWarning({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_maybe_outlined, size: 18, color: scheme.error),
          UIs.width7,
          Expanded(
            child: Text(
              l10n.syncSecretKeyZeroKnowledgeWarn,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// QR code + monospace text display for a Secret Key, optionally wrapped in a
/// [CardX] with an inline Copy button (used in [IntroPage] and [BackupPage]).
final class SecretKeyQrDisplay extends StatelessWidget {
  const SecretKeyQrDisplay({
    super.key,
    required this.secretKey,
    this.qrWidth = 180,
    this.inCard = true,
    this.showCopyButton = true,
  });

  final String secretKey;
  final double qrWidth;
  final bool inCard;
  final bool showCopyButton;

  @override
  Widget build(BuildContext context) {
    final libL10n = context.libL10n;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: qrWidth, child: QrView(data: secretKey)),
        UIs.height13,
        SelectableText(
          secretKey,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        if (showCopyButton) ...[
          UIs.height13,
          FilledButton.tonalIcon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: secretKey));
              Toast.success(libL10n.success);
            },
            icon: const Icon(Icons.copy, size: 17),
            label: Text(libL10n.copy),
          ),
        ],
      ],
    );
    if (!inCard) return content;
    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: content,
      ),
    );
  }
}
