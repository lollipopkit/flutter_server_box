import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Builds its child again only when what it is built from has changed.
///
/// For a page that is rebuilt from one object every few seconds and mostly
/// says what it said before. A server's detail page is built from a status
/// that is replaced on every poll: every widget under it is a new one, so
/// every element under it is visited, and most of them — a disk's size, a
/// sensor's name, which CPU it is — to be told what they already had. That
/// walk is what a poll costs, far more than working out what to say.
///
/// Flutter skips a subtree whose widget is the very one it was last given, and
/// this is how to hand it that: the child is kept, and built again when
/// [inputs] no longer equal what they were.
///
/// **[inputs] has to be everything the child shows.** What is left out goes
/// stale without anything saying so. Three things it does not have to list,
/// because this asks for them itself: the theme, the locale, and anything the
/// builder reads through the [BuildContext] it is handed.
///
/// **And the child must not close over what changes.** A callback built into
/// it is the one from when it was built: `onTap: () => open(status)` opens the
/// status of however many polls ago. Pass what the callback needs in [inputs],
/// or leave that subtree out of this.
class BuiltFrom extends StatefulWidget {
  const BuiltFrom(this.inputs, {super.key, required this.builder});

  /// Compared one by one with `==`, so records, strings and numbers are fine
  /// and a list inside this list is compared by identity.
  final List<Object?> inputs;

  final WidgetBuilder builder;

  @override
  State<BuiltFrom> createState() => _BuiltFromState();
}

class _BuiltFromState extends State<BuiltFrom> {
  Widget? _child;

  @override
  void didUpdateWidget(BuiltFrom old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.inputs, widget.inputs)) _child = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _child = null;
  }

  /// A hot reload changes what the builder would build without changing a
  /// single input.
  @override
  void reassemble() {
    super.reassemble();
    _child = null;
  }

  @override
  Widget build(BuildContext context) {
    // Asked for so that a change to either comes here: most of what is kept
    // was built by a page's own methods, from the page's context, and that is
    // where the dependency on these would otherwise have been recorded.
    Theme.of(context);
    Localizations.maybeLocaleOf(context);
    return _child ??= widget.builder(context);
  }
}
