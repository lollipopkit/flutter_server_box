import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// What a page shows in place of a list it could not get.
///
/// In the middle of the page rather than in a snackbar: a snackbar is for
/// something that happened beside what is on screen, and this *is* what is on
/// screen — an empty page with a message that has already faded away leaves
/// the user with nothing to read and nothing to do.
///
/// Three levels, because the answers differ in how much the user wants:
/// [title] is what went wrong, [explain] is why in the machine's own terms,
/// and [detail] is what the server actually said, kept small and selectable
/// for the cases where the first two are guesses.
class PageIssueView extends StatelessWidget {
  const PageIssueView({
    super.key,
    required this.title,
    this.explain,
    this.detail,
    this.icon = Icons.error_outline,
    this.onRetry,
  });

  final String title;
  final String? explain;
  final String? detail;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final explain = this.explain;
    final detail = this.detail?.trim();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(23),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 37),
            UIs.height13,
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (explain != null) ...[
              UIs.height7,
              ConstrainedBox(
                // Long enough to be a sentence, short enough to stay readable
                // on a desktop window that is as wide as the screen.
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  explain,
                  textAlign: TextAlign.center,
                  style: UIs.textGrey,
                ),
              ),
            ],
            if (detail != null && detail.isNotEmpty) ...[
              UIs.height13,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SelectableText(
                  detail,
                  textAlign: TextAlign.center,
                  style: UIs.text11Grey,
                ),
              ),
            ],
            if (onRetry != null) ...[
              UIs.height13,
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(libL10n.refresh),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
