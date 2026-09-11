import 'package:flutter/material.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';

/// The batch of calls awaiting review, one at a time, with a way between them.
///
/// A turn can propose several things at once. Reviewing them as a stack of
/// cards would put an unknown amount of work between the user and the answer
/// they asked for; reviewing only the first and dropping the rest is what this
/// replaces. So: one card, with dots saying how many there are and a swipe or
/// a tap to move between them.
///
/// Approving one takes it out of the batch, and the list closing up under the
/// index is what brings the next into view — this follows the session's index
/// rather than owning one, so an auto-run advances the same way a tap does.
///
/// **Not a `PageView`.** That needs a bounded height, and a card is as tall as
/// whatever is on it: measuring the tallest one first is a layout that cannot
/// start, since nothing is laid out until the height it is waiting for exists.
/// A `PageView` is also a `Scrollable`, which would compete for the horizontal
/// drag with the code block inside every card — the one place a horizontal
/// drag already means something.
class AgentProposalPager extends StatefulWidget {
  const AgentProposalPager({
    super.key,
    required this.proposals,
    required this.index,
    required this.onIndexChanged,
    required this.cardBuilder,
  });

  final List<AskAiCommand> proposals;

  /// Which one is being reviewed. Owned by the session: an approval changes it
  /// without anybody swiping.
  final int index;

  final ValueChanged<int> onIndexChanged;

  final Widget Function(BuildContext context, AskAiCommand proposal)
  cardBuilder;

  @override
  State<AgentProposalPager> createState() => _AgentProposalPagerState();
}

class _AgentProposalPagerState extends State<AgentProposalPager> {
  /// Which way the last change went, so the new card comes in from the side it
  /// should. Approving moves forward, and so does swiping left.
  var _forward = true;

  @override
  void didUpdateWidget(AgentProposalPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _forward = widget.index > oldWidget.index;
    }
  }

  /// A flick, not a drag: there is no card following the finger, so treating a
  /// slow drag as a page turn would move the thing under the buttons while
  /// somebody is reaching for them.
  void _onFlick(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 220) return;
    final next = velocity < 0 ? widget.index + 1 : widget.index - 1;
    if (next < 0 || next >= widget.proposals.length) return;
    widget.onIndexChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final proposals = widget.proposals;
    final index = proposals.isEmpty
        ? 0
        : widget.index.clamp(0, proposals.length - 1);
    final proposal = proposals.isEmpty ? null : proposals[index];

    // Always in the tree, even with nothing to show: approving the last call
    // of a batch is the moment the card should be seen leaving, and a widget
    // removed by an `if` above simply stops existing.
    return AnimatedSize(
      duration: Durations.short4,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Durations.short4,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        // Out and in from opposite sides, so a batch reads as a row of cards
        // even though only one is ever built.
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(proposal?.id ?? '');
          final begin = Offset((incoming == _forward ? 1.0 : -1.0) * 0.12, 0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: begin,
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        // Keyed by the call, not the index: approving removes one, and the
        // card that was next should not animate as though it changed into
        // something else.
        child: proposal == null
            ? const SizedBox(key: ValueKey(''), width: double.infinity)
            : KeyedSubtree(
                key: ValueKey(proposal.id),
                child: GestureDetector(
                  onHorizontalDragEnd: _onFlick,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.cardBuilder(context, proposal),
                      // One call is not a batch: no dots, nothing to swipe.
                      // Which is every turn from a provider that honours
                      // `parallel_tool_calls: false`.
                      if (proposals.length > 1) ...[
                        const SizedBox(height: 9),
                        _Dots(
                          count: proposals.length,
                          index: index,
                          onTap: widget.onIndexChanged,
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

/// Which of the batch is on screen, and a way to any of the others.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.index,
    required this.onTap,
  });

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          // Tappable, and with a target bigger than the dot: a flick is the
          // fast way between neighbours and this is the only way to the fourth
          // card from the first.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
              child: AnimatedContainer(
                duration: Durations.short3,
                curve: Curves.easeOut,
                // The current one is a short bar rather than a bigger dot: at
                // this size a difference in diameter is hard to see and a
                // difference in shape is not.
                width: i == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == index
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
