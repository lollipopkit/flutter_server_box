/// The parts of an Agent surface that are not about which Agent it is.
///
/// There are two: the one in the terminal, scoped to the server whose tab it
/// is, and the one in the Agent tab, which is not scoped to anything. What
/// differs between them is the scope and the tools; everything here was the
/// same idea written out twice, which is how the two copies came to disagree —
/// see [describeAgentError] for the one that had drifted furthest.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';

/// What went wrong, in a sentence.
///
/// The union of the two copies this replaces, because each had something the
/// other did not: the terminal's separated missing field names by locale —
/// `、` reads as a list in Chinese and Japanese where `, ` does not — and the
/// tab's knew about [AgentNoResponse]. Neither was more correct; they were
/// edited at different times.
String describeAgentError(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is AgentNoResponse) return l10n.askAiNoResponse;
  if (error is AskAiConfigException) {
    if (error.missingFields.isEmpty) {
      return error.hasInvalidBaseUrl
          ? '${libL10n.invalidUrl}: ${error.invalidBaseUrl}'
          : error.toString();
    }
    final locale = Localizations.maybeLocaleOf(context);
    final separator = switch (locale?.languageCode) {
      'zh' || 'ja' => '、',
      _ => ', ',
    };
    final fields = error.missingFields
        .map(
          (field) => switch (field) {
            AskAiConfigField.baseUrl => libL10n.apiEndpoint,
            AskAiConfigField.apiKey => libL10n.apiKey,
            AskAiConfigField.model => libL10n.askAiModel,
          },
        )
        .join(separator);
    return l10n.askAiConfigMissing(fields);
  }
  if (error is AskAiNetworkException) return error.message;
  return error.toString();
}

/// What a turn that ended without an answer has to say for itself.
String agentNoticeText(BuildContext context, AgentNoticeKind kind) =>
    switch (kind) {
      AgentNoticeKind.declined => context.l10n.askAiActionDeclined,
      AgentNoticeKind.interrupted => context.l10n.askAiInterrupted,
    };

/// Copies [text], and says so.
///
/// Silent on empty rather than reporting a success that copied nothing — the
/// content of a message that is still streaming is legitimately empty.
Future<void> copyAgentText(String text) async {
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  Toast.success(libL10n.success);
}

/// Follows the conversation as it grows, unless the reader has scrolled away.
///
/// [force] is for the reader's own message: they just sent it, so they are
/// looking at the bottom whether or not they were before.
///
/// The 96 pixels is the slack for "near enough the bottom to still be
/// following". Without it, a list that grows while a reader is a line or two
/// up stops scrolling and appears to freeze.
void scheduleAgentAutoScroll(
  ScrollController controller, {
  bool force = false,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!force && position.pixels < position.maxScrollExtent - 96) return;
    controller.animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  });
}

/// Whether a key event in the composer means "send".
///
/// The decision only. What sending *is* differs between the two surfaces —
/// one has a command awaiting review, the other does not — so the caller acts
/// and this answers.
///
/// [composing] is whether the input has an open IME composition.
/// [sendOnEnter] is the user's setting, passed rather than read: this is a
/// decision about a key event, and one that reaches into a service locator
/// cannot be exercised without standing one up.
bool composerKeySends(
  KeyEvent event, {
  required bool composing,
  required bool sendOnEnter,
}) {
  if (event is! KeyDownEvent) return false;
  if (event.logicalKey != LogicalKeyboardKey.enter &&
      event.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return false;
  }

  final keys = HardwareKeyboard.instance;
  final withModifier = keys.isMetaPressed || keys.isControlPressed;
  final sends = sendOnEnter ? !keys.isShiftPressed : withModifier;
  if (!sends) return false;

  // Mid-composition a bare Enter belongs to the IME, which is using it to
  // accept a candidate; taking it would send half a word in every language
  // that needs one to type at all. Only a bare one: no IME commits on
  // Cmd/Ctrl+Enter, and Android keeps the word being typed in a composing
  // range at all times, so guarding the modifier form too swallowed the send
  // shortcut for the whole of a sentence.
  if (!withModifier && composing) return false;
  return true;
}

/// The failure of the last turn, with the offer to try it again.
///
/// Takes the sentence rather than the error: one surface keeps the raw object
/// and the other keeps what [describeAgentError] made of it, and a banner that
/// decided which is which would be deciding what errors mean. It renders.
class AgentErrorBanner extends StatelessWidget {
  const AgentErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;

  /// Null while a turn is running: retrying then would start a second one.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(libL10n.retry)),
        ],
      ),
    );
  }
}
