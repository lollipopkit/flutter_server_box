import 'package:flutter/services.dart';

/// Whether a key press is this platform's clipboard chord for [key].
///
/// macOS uses Cmd+C and Cmd+V. Everywhere else it has to be Ctrl+**Shift**+C,
/// because Ctrl+C is SIGINT: a terminal that swallowed it would be a terminal
/// that cannot interrupt anything, which is the one key nobody will accept
/// losing. So this returning false for a plain Ctrl+C is not an omission — it
/// is the whole point, and it is why the paste chord takes Shift too rather
/// than being the odd one out.
///
/// A pure function of the modifiers rather than a read of
/// `HardwareKeyboard.instance`, so the platform matrix can be stated in a test
/// instead of reproduced by pressing keys on three operating systems.
bool isClipboardChord({
  required LogicalKeyboardKey pressed,
  required LogicalKeyboardKey key,
  required bool onMacOS,
  required bool meta,
  required bool control,
  required bool shift,
}) {
  if (pressed != key) return false;
  if (onMacOS) return meta;
  return control && shift;
}
