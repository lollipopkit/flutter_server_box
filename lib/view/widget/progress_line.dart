import 'package:flutter/material.dart';

/// A thin bar that says something is happening, and how far along when that is
/// known.
///
/// Two states in one widget because a download has both: bytes arriving with a
/// `Content-Length` are a fraction, bytes arriving without one are not, and the
/// parse that follows them never is. A bar that changed shape between the two
/// would read as two different things happening.
///
/// Not `LinearProgressIndicator`: its indeterminate form is a short segment
/// travelling left to right, which reads as motion across a track. This one
/// grows and shrinks from the same edge the determinate form fills from, so
/// the two forms are the same picture with the length either measured or not.
class ProgressLine extends StatefulWidget {
  const ProgressLine({super.key, this.value, this.height = 3});

  /// How far along, or null while there is no measure of it.
  ///
  /// Clamped rather than asserted: a server that reports a length and then
  /// sends more is a real thing, and a bar is not worth an exception.
  final double? value;

  final double height;

  @override
  State<ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends State<ProgressLine>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Never quite empty. A bar that reaches zero looks like it stopped.
  late final _length = Tween<double>(begin: 0.12, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.value == null) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.value == null) == (oldWidget.value == null)) return;
    // Stopped rather than left running behind a measured length: it would keep
    // a frame scheduled for the life of the row, and `pumpAndSettle` in any
    // test that reaches this page would never return.
    if (widget.value == null) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.height);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: widget.height,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Align(
            alignment: Alignment.centerLeft,
            child: switch (widget.value) {
              // Measured: animated to the new length rather than jumped, so a
              // download reporting in chunks reads as one movement.
              final value? => TweenAnimationBuilder<double>(
                tween: Tween(end: value.clamp(0.0, 1.0)),
                duration: Durations.short4,
                curve: Curves.easeOut,
                builder: (context, length, _) =>
                    _Bar(length: length, color: scheme.primary),
              ),
              null => AnimatedBuilder(
                animation: _length,
                builder: (context, _) =>
                    _Bar(length: _length.value, color: scheme.primary),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.length, required this.color});

  final double length;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: length,
      child: ColoredBox(color: color),
    );
  }
}
