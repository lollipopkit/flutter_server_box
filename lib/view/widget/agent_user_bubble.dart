import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/widget/agent_common.dart';

/// The user's own message, with a way to change what was asked.
///
/// Editing and resending is how a conversation is steered once it has gone
/// somewhere unhelpful. The alternative is typing a correction as a new turn,
/// which leaves the wrong answer in the context for every turn after it.
///
/// Two ways in, because the two kinds of device answer different questions.
/// A finger has nowhere to hover, so it presses and holds; a pointer has
/// nowhere to press and hold without it feeling like a stall, so the actions
/// appear under the message it is over. Neither is behind a platform check —
/// a touch never hovers and a pointer rarely long-presses, so offering both
/// costs nothing and a trackpad on a tablet gets both.
class AgentUserBubble extends StatefulWidget {
  const AgentUserBubble({
    super.key,
    required this.content,
    required this.ordinal,
    required this.onResend,
    required this.onDelete,
    required this.child,
  });

  final String content;

  /// Which of the user's messages this is, counted from the start of the
  /// conversation. What the session cuts back to.
  final int ordinal;

  final Future<void> Function(int ordinal, String text) onResend;
  final Future<void> Function(int ordinal) onDelete;

  final Widget child;

  @override
  State<AgentUserBubble> createState() => _AgentUserBubbleState();
}

class _AgentUserBubbleState extends State<AgentUserBubble> {
  /// Held down, which is not yet a long press.
  ///
  /// The shrink starts here rather than when the press is recognised: pressing
  /// something that gives a little is what says "keep holding, this does
  /// something" — after the menu is already up it would be saying it too late.
  var _pressed = false;
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        // What puts the bubble on the right. It is here rather than around the
        // caller's widget so that the thing being scaled is the bubble itself:
        // an `Align` would be as wide as the row, and scaling that shrinks a
        // right-hand bubble towards the middle of the screen instead of into
        // its own centre.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            // The whole bubble, not just the glyphs. A `Container`'s padding
            // and decoration are proxy boxes that defer their hits to the
            // child, so with the default behaviour the margin between the text
            // and the rounded edge would be dead to a long press.
            behavior: HitTestBehavior.opaque,
            onLongPressDown: (_) => setState(() => _pressed = true),
            onLongPressCancel: () => setState(() => _pressed = false),
            onLongPressUp: () => setState(() => _pressed = false),
            onLongPressStart: (details) {
              // Back to full size as the menu arrives, so the release reads as
              // the menu coming out of the bubble.
              setState(() => _pressed = false);
              _showMenu(context, details.globalPosition);
            },
            child: AnimatedScale(
              // Its own centre, which is now the bubble's centre.
              alignment: Alignment.center,
              scale: _pressed ? 0.96 : 1,
              duration: _pressed ? Durations.medium1 : Durations.short4,
              // Out past its own size and back, the way a held control lets go.
              curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
              child: widget.child,
            ),
          ),
          // Under the message rather than over it: a row floating on the
          // bubble would cover the words being decided about.
          AnimatedSize(
            duration: Durations.short3,
            curve: Curves.easeOut,
            alignment: Alignment.topRight,
            child: _hovered
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HoverAction(
                          icon: Icons.edit_outlined,
                          tooltip: libL10n.edit,
                          onTap: () => _showEditor(context),
                        ),
                        _HoverAction(
                          icon: Icons.copy_rounded,
                          tooltip: libL10n.copy,
                          onTap: () => unawaited(copyAgentText(widget.content)),
                        ),
                        _HoverAction(
                          icon: Icons.delete_outline,
                          tooltip: libL10n.delete,
                          destructive: true,
                          onTap: () => unawaited(widget.onDelete(widget.ordinal)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final scheme = Theme.of(context).colorScheme;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final chosen = await showMenu<_BubbleAction>(
      context: context,
      // Where the finger is, so the menu comes out from under it rather than
      // from a corner of the screen.
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _BubbleAction.edit,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined, size: 20),
            title: Text(libL10n.edit),
          ),
        ),
        PopupMenuItem(
          value: _BubbleAction.copy,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_rounded, size: 20),
            title: Text(libL10n.copy),
          ),
        ),
        PopupMenuItem(
          value: _BubbleAction.delete,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, size: 20, color: scheme.error),
            title: Text(libL10n.delete, style: TextStyle(color: scheme.error)),
          ),
        ),
      ],
    );
    if (!context.mounted) return;
    switch (chosen) {
      case _BubbleAction.edit:
        await _showEditor(context);
      case _BubbleAction.copy:
        await copyAgentText(widget.content);
      case _BubbleAction.delete:
        await widget.onDelete(widget.ordinal);
      case null:
        break;
    }
  }

  Future<void> _showEditor(BuildContext context) async {
    final l10n = context.l10n;
    // `withTextFieldController` disposes the controller when the dialog goes;
    // it answers `void`, so there is nothing to await on it.
    withTextFieldController((controller) async {
      controller.text = widget.content;

      Future<void> send() async {
        final text = controller.text.trim();
        context.popDialog();
        if (text.isEmpty) return;
        await widget.onResend(widget.ordinal, text);
      }

      await context.showRoundDialog(
        title: l10n.askAiResend,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Input(
              controller: controller,
              autoFocus: true,
              maxLines: 5,
              minLines: 1,
              label: l10n.askAiResend,
              icon: Icons.edit,
              onSubmitted: (_) => send(),
            ),
            const SizedBox(height: 8),
            // Said before it happens, not after: what follows a message is an
            // answer to that message, and it cannot survive the question
            // changing.
            Text(l10n.askAiResendTip, style: UIs.textGrey),
          ],
        ),
        actions: [
          TextButton(onPressed: context.popDialog, child: Text(libL10n.cancel)),
          TextButton(onPressed: send, child: Text(l10n.askAiResend)),
        ],
      );
    });
  }
}

enum _BubbleAction { edit, copy, delete }

/// One of the three, small and quiet: they sit under every message a pointer
/// passes over, so they have to be readable without being the loudest thing on
/// the page.
class _HoverAction extends StatelessWidget {
  const _HoverAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      iconSize: 16,
      color: destructive ? scheme.error : scheme.onSurfaceVariant,
      icon: Icon(icon),
    );
  }
}
