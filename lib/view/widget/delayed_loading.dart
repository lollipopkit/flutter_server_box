import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// Nothing, and a loading indicator once [delay] has passed.
///
/// For a wait that is usually short. An indicator shown at once blinks on and
/// off for every answer that comes back within a frame or two, which reads as
/// a flicker rather than as progress; nothing shown at all leaves a slow
/// answer looking like an empty result.
class DelayedLoading extends StatefulWidget {
  const DelayedLoading({
    super.key,
    this.delay = const Duration(milliseconds: 100),
    this.child = UIs.centerLoading,
  });

  final Duration delay;

  /// What is shown once [delay] has passed.
  final Widget child;

  @override
  State<DelayedLoading> createState() => _DelayedLoadingState();
}

class _DelayedLoadingState extends State<DelayedLoading> {
  late final Timer _timer;
  var _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () => setState(() => _shown = true));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _shown ? widget.child : UIs.placeholder;
}
