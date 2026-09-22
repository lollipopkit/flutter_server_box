import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum TerminalConnectionStep {
  connecting,
  openingShell,
  ready,
  connectionFailed,
  shellFailed,
}

/// Shows only the foreground terminal's connection, not the server's status poll.
class TerminalConnectionProgress extends StatelessWidget {
  const TerminalConnectionProgress({
    super.key,
    required this.step,
    this.failureDetail,
    required this.onRetry,
  });

  final TerminalConnectionStep step;
  final String? failureDetail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed =
        step == TerminalConnectionStep.connectionFailed ||
        step == TerminalConnectionStep.shellFailed;
    final detail = switch (step) {
      TerminalConnectionStep.connecting => context.l10n.connecting,
      TerminalConnectionStep.openingShell => context.l10n.userOpenShell,
      TerminalConnectionStep.ready => libL10n.success,
      TerminalConnectionStep.connectionFailed =>
        '${context.l10n.connect} · ${libL10n.fail}',
      TerminalConnectionStep.shellFailed =>
        '${context.l10n.userOpenShell} · ${libL10n.fail}',
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Material(
          color: scheme.surfaceContainerHigh,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: failed
                            ? Icon(
                                Icons.error_outline,
                                key: const ValueKey('failed'),
                                size: 20,
                                color: scheme.error,
                              )
                            : CircularProgressIndicator(
                                key: const ValueKey('busy'),
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            libL10n.terminal,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              detail,
                              key: ValueKey(detail),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: failed ? scheme.error : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (failed && failureDetail != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    failureDetail!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (failed) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(libL10n.retry),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
