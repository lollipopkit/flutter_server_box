import 'dart:typed_data';

/// A chunk of a shell's output, and whether it is a redraw: the whole terminal
/// written over from a reset, as a tmux pane's replay is.
final class ShellOutput {
  final Uint8List data;
  final bool redraw;

  /// A redraw of something other than what was on screen, as another tmux
  /// pane's: the view's place in the old text means nothing in it.
  final bool switched;

  const ShellOutput(this.data, {this.redraw = false, this.switched = false});
}

/// A shell whose output can carry redraws. A redraw is written whole and in
/// one frame, and a character left unfinished before it is dropped.
abstract interface class RedrawingShell {
  /// The output, read instead of `stdout`, which has the same bytes without
  /// saying which are redraws.
  Stream<ShellOutput> get output;
}
