import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How long the readings take to fill a card once the first sample lands.
///
/// The design's number, and it is the height as well as the contents: the card
/// grows out of its title over this, and what fills it comes in over the same
/// stretch — so a machine answering is one movement rather than a box growing
/// and then filling.
const kServerCardArrive = Duration(milliseconds: 377);

/// How far apart the blocks of that come in.
///
/// Small enough that six of them are a sweep down the card rather than six
/// separate arrivals — six at 20 is 100ms, inside the 377 the whole thing
/// takes — and large enough to have a direction, which is what says the card
/// filled rather than appeared.
const _kArriveStep = Duration(milliseconds: 20);

/// How a card's rows unfold, over [kServerCardArrive].
///
/// Slow to start, which is not only how it looks. The [AnimatedSize] around
/// the card is a frame behind the first change in its child's height whatever
/// its duration is, and draws the old height for that frame — so the bottom
/// of the card is cut off by however much the rows grew in it. On the curve
/// the card's own height eases along, which starts fast, that is over ten
/// points at 60 Hz: all of the inset under the control and some of the
/// control. On this one it is under a point.
const _kFoldCurve = Curves.easeInOutCubic;

/// The two movements a card has of its own, and when each of them starts.
///
/// **When its readings come in: once, as its machine first answers. Not when
/// what draws them is mounted**, which is what this used to be —
/// [ServerCardArriving] ran its own tween from 0 wherever it was built. A card
/// is mounted far more often than a machine answers: the grid is dropped while
/// a machine is open and mounted again for the way back, a line's card is
/// built on the first frame of opening it, a tag is picked, the globe is left.
/// Each of those played the fill again, and around the opening movement that
/// was the readings going out and coming back before the card started
/// shrinking, and again once it had landed.
///
/// So the clock is here, above every shape the card takes, and what starts it
/// is [hasBody] going from false to true *between two builds of the same
/// card*. A card mounted with readings already had them, and its clock starts
/// at the end — the rule `AnimatedMasonry` follows for its own children, and
/// for the same reason: something is only new against what was already on
/// screen without it.
///
/// **And how far its rows are unfolded**, by the same rule: what moves it is
/// [expanded] changing between two builds, and a card mounted unfolded is
/// unfolded. It is a clock rather than the card's [AnimatedSize] because of
/// what that does with a taller child: lays it out at its full height at once
/// and uncovers it. Nothing under the rows travels — it is where it will end
/// up from the first frame, behind the clip — and the one thing under them is
/// the control that was just pressed. Along this the rows are as tall as they
/// have got to, and what is under them is moved by that.
class ServerCardClocks extends StatefulWidget {
  const ServerCardClocks({
    super.key,
    required this.hasBody,
    required this.expanded,
    required this.duration,
    required this.builder,
  });

  /// Whether the card has readings to draw — see `ServerCard._hasBody`.
  final bool hasBody;

  /// Whether the card's rows are to be showing — see `ServerCard.expanded`.
  final bool expanded;

  /// How long each of the two takes.
  final Duration duration;

  /// Called with this widget's own context and the two clocks: `arrival`
  /// for the readings coming in, `fold` for the rows unfolding.
  final Widget Function(
    BuildContext context,
    Animation<double> arrival,
    Animation<double> fold,
  )
  builder;

  @override
  State<ServerCardClocks> createState() => _ServerCardClocksState();
}

class _ServerCardClocksState extends State<ServerCardClocks>
    with TickerProviderStateMixin {
  late final _arrival = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.hasBody ? 1 : 0,
  );

  late final _fold = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.expanded ? 1 : 0,
  )..addStatusListener(_onFoldStatus);

  /// Built again as the fold comes to rest, because `ServerCard.build` asks
  /// whether it is moving. Its setting off needs nothing: that is
  /// [didUpdateWidget], and a build follows it.
  void _onFoldStatus(AnimationStatus status) {
    if (!status.isAnimating) setState(() {});
  }

  @override
  void didUpdateWidget(ServerCardClocks old) {
    super.didUpdateWidget(old);
    _arrival.duration = widget.duration;
    _fold.duration = widget.duration;
    if (widget.hasBody && !old.hasBody) _arrival.forward(from: 0);
    if (widget.expanded != old.expanded) {
      _fold.animateTo(widget.expanded ? 1 : 0, curve: _kFoldCurve);
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    _fold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _arrival, _fold);
}

/// A column whose children come in one after another along [clock].
///
/// A stretch of a sweep rather than always the whole of one: [from] is where
/// in it the first of [children] is and [of] how many there are in all. What
/// comes in is not all in one column — see `ServerCard._body` — and it is
/// still one movement down the card.
class ServerCardArriving extends StatelessWidget {
  const ServerCardArriving({
    super.key,
    required this.clock,
    required this.duration,
    required this.of,
    required this.children,
    this.from = 0,
  });

  final Animation<double> clock;
  final Duration duration;
  final int from;
  final int of;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed)
          ServerCardArrives(
            clock: clock,
            duration: duration,
            at: from + i,
            of: of,
            child: child,
          ),
      ],
    );
  }
}

/// One child's stretch of that sweep: the [at]th [of] them.
///
/// [Opacity] rather than a fade transition with a controller of its own:
/// there is one clock for the whole card, and each child reads its own stretch
/// of it. Six controllers on forty cards is forty times what this costs.
///
/// The clock is [ServerCardClocks]'s rather than this widget's own, so being
/// mounted again is not arriving again. Once it has run, a poll rebuilds the
/// children and nothing fades.
class ServerCardArrives extends StatelessWidget {
  const ServerCardArrives({
    super.key,
    required this.clock,
    required this.duration,
    required this.at,
    required this.of,
    required this.child,
  });

  final Animation<double> clock;
  final Duration duration;
  final int at;
  final int of;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    final step = _kArriveStep.inMilliseconds;
    // The last child still has the fade's own length to run in, so the steps
    // before it share what is left rather than pushing it past the end.
    final fade = math.max(1, total - step * math.max(0, of - 1));
    final stretch = Interval(
      (at * step) / total,
      ((at * step) + fade) / total,
      curve: Curves.easeOut,
    );

    return AnimatedBuilder(
      animation: clock,
      child: child,
      builder: (_, child) =>
          Opacity(opacity: stretch.transform(clock.value), child: child),
    );
  }
}

/// [shown] of [child], from the top, faded by as much.
///
/// How a block of a card goes as the card becomes the page, or comes in as it
/// does: collapsed rather than faded alone, so what is under it travels with
/// it instead of arriving by that much lower than the page puts it. The child
/// is laid out at its full height throughout and clipped to its share.
class ServerCardReveal extends StatelessWidget {
  const ServerCardReveal({super.key, required this.shown, required this.child});

  /// 0 is none of it, 1 all of it.
  final double shown;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: shown,
        child: Opacity(opacity: shown, child: child),
      ),
    );
  }
}
