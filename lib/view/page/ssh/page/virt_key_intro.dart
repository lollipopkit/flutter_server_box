import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';

/// One thing the walkthrough has to say, and which keys it is about.
///
/// [group] null means the step is about the terminal rather than the row, and
/// nothing in the row is singled out.
final class VirtKeyIntroStep {
  const VirtKeyIntroStep({
    required this.title,
    required this.body,
    this.group,
  });

  final String title;
  final String body;
  final VirtKeyGroup? group;

  /// Read where they are shown, not once at startup: the app's locale can
  /// change while a terminal is open, and a list built at launch would still
  /// be in the language it launched in.
  static List<VirtKeyIntroStep> of(BuildContext context) {
    final l10n = context.l10n;
    return [
      VirtKeyIntroStep(
        title: context.libL10n.terminal,
        body: l10n.virtKeyIntroSelect,
      ),
      VirtKeyIntroStep(
        title: l10n.virtKeyIntroModifiers,
        body: l10n.virtKeyIntroModifiersTip,
        group: VirtKeyGroup.modifiers,
      ),
      VirtKeyIntroStep(
        title: l10n.virtKeyIntroNav,
        body: l10n.virtKeyIntroNavTip,
        group: VirtKeyGroup.navigation,
      ),
      VirtKeyIntroStep(
        title: l10n.virtKeyIntroActions,
        body: l10n.virtKeyIntroActionsTip,
        group: VirtKeyGroup.shortcuts,
      ),
      VirtKeyIntroStep(
        title: l10n.editVirtKeys,
        body: l10n.virtKeyIntroCustomizeTip,
      ),
    ];
  }
}

/// What the virtual keys are for, said over the terminal they sit under.
///
/// Floating rather than a dialog, and over the terminal rather than over the
/// keys: the row it is describing is the one thing that must stay legible, so
/// the scrim covers the body and stops where the keys begin. The page dims the
/// keys outside [VirtKeyIntroStep.group] itself — they are the `Scaffold`'s
/// bottom bar and out of this widget's reach, which is exactly why they are
/// still lit.
///
/// Three kinds of key and not seventeen keys. A step each would be a tour
/// nobody finishes, and what is worth knowing is which of them type, which
/// move the cursor, and which leave the terminal altogether.
class VirtKeyIntro extends StatelessWidget {
  const VirtKeyIntro({
    super.key,
    required this.step,
    required this.steps,
    required this.onStep,
    required this.onDone,
  });

  /// Which step is showing, indexing [steps].
  final int step;

  final List<VirtKeyIntroStep> steps;

  final ValueChanged<int> onStep;

  /// Finished or dismissed — both mean the same thing to the caller, which is
  /// that this does not come back.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final current = steps[step];
    final last = step == steps.length - 1;

    return Stack(
      children: [
        // Tapping the scrim moves on rather than dismissing. Dismissing is the
        // ✕, which says so.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => last ? onDone() : onStep(step + 1),
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
          ),
        ),
        Positioned(
          left: 13,
          right: 13,
          bottom: 13,
          child: _Card(
            step: step,
            count: steps.length,
            title: current.title,
            body: current.body,
            onNext: last ? onDone : () => onStep(step + 1),
            onSkip: onDone,
            last: last,
          ),
        ),
      ],
    );
  }
}

final class _Card extends StatelessWidget {
  const _Card({
    required this.step,
    required this.count,
    required this.title,
    required this.body,
    required this.onNext,
    required this.onSkip,
    required this.last,
  });

  final int step;
  final int count;
  final String title;
  final String body;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(17),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 13, 9, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // No label on it: every word here would need translating to
                // say what a ✕ already says.
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: scheme.onSurfaceVariant,
                  tooltip: libL10n.close,
                  onPressed: onSkip,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 3, bottom: 13),
              child: Text(
                body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < count; i++)
                  _Dot(filled: i == step, done: i < step),
                const Spacer(),
                TextButton(
                  onPressed: onNext,
                  child: Text(last ? libL10n.done : libL10n.next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// How far along, as far as it is worth saying. The step behind stays marked
/// so the row reads as progress rather than as a position.
final class _Dot extends StatelessWidget {
  const _Dot({required this.filled, required this.done});

  final bool filled;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Durations.short3,
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(right: 5),
      width: filled ? 17 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: filled || done
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
