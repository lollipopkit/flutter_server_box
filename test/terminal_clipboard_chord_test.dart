import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/ssh/page/clipboard_chord.dart';

/// The terminal's copy and paste chords, and the key they must not take.
///
/// Ctrl+C is SIGINT. Every other surface in this app can bind Ctrl+C to copy
/// and nobody notices; a terminal cannot, and the failure would be silent —
/// the chord works, the copy happens, and a runaway process simply never
/// stops. So the rule is stated here per platform rather than pressed on three
/// operating systems.
void main() {
  bool copy({
    required LogicalKeyboardKey pressed,
    required bool onMacOS,
    bool meta = false,
    bool control = false,
    bool shift = false,
  }) => isClipboardChord(
    pressed: pressed,
    key: LogicalKeyboardKey.keyC,
    onMacOS: onMacOS,
    meta: meta,
    control: control,
    shift: shift,
  );

  group('away from macOS', () {
    test('Ctrl+C is not a copy — it is the interrupt', () {
      // The one that matters. If this ever returns true, `_handleKeyEvent`
      // swallows the event and the terminal stops being able to interrupt.
      expect(
        copy(pressed: LogicalKeyboardKey.keyC, onMacOS: false, control: true),
        isFalse,
      );
    });

    test('Ctrl+Shift+C is', () {
      expect(
        copy(
          pressed: LogicalKeyboardKey.keyC,
          onMacOS: false,
          control: true,
          shift: true,
        ),
        isTrue,
      );
    });

    test('Shift+C alone is not', () {
      expect(
        copy(pressed: LogicalKeyboardKey.keyC, onMacOS: false, shift: true),
        isFalse,
      );
    });

    test('Cmd+C is not, on a keyboard that has the key anyway', () {
      // A Mac keyboard on Linux still reports meta. Copy there is the
      // platform's chord, not the keyboard's.
      expect(
        copy(pressed: LogicalKeyboardKey.keyC, onMacOS: false, meta: true),
        isFalse,
      );
    });

    test('paste takes Shift too, rather than being the odd one out', () {
      bool paste({bool control = false, bool shift = false}) =>
          isClipboardChord(
            pressed: LogicalKeyboardKey.keyV,
            key: LogicalKeyboardKey.keyV,
            onMacOS: false,
            meta: false,
            control: control,
            shift: shift,
          );

      expect(paste(control: true), isFalse);
      expect(paste(control: true, shift: true), isTrue);
    });
  });

  group('on macOS', () {
    test('Cmd+C is a copy', () {
      expect(
        copy(pressed: LogicalKeyboardKey.keyC, onMacOS: true, meta: true),
        isTrue,
      );
    });

    test('Ctrl+C is not, so it still interrupts here too', () {
      expect(
        copy(pressed: LogicalKeyboardKey.keyC, onMacOS: true, control: true),
        isFalse,
      );
    });

    test('Ctrl+Shift+C is not — that is the other platforms\' chord', () {
      expect(
        copy(
          pressed: LogicalKeyboardKey.keyC,
          onMacOS: true,
          control: true,
          shift: true,
        ),
        isFalse,
      );
    });

    test('Cmd with Shift held is still a copy', () {
      // Nothing requires Shift to be absent, and a user with it down by
      // accident should still get their copy.
      expect(
        copy(
          pressed: LogicalKeyboardKey.keyC,
          onMacOS: true,
          meta: true,
          shift: true,
        ),
        isTrue,
      );
    });
  });

  test('a different key is never the chord, however it is modified', () {
    // Checked before the modifiers in the implementation, so that holding the
    // chord's modifiers does not make every key a clipboard action.
    for (final key in [
      LogicalKeyboardKey.keyX,
      LogicalKeyboardKey.keyV,
      LogicalKeyboardKey.enter,
    ]) {
      expect(
        copy(pressed: key, onMacOS: true, meta: true),
        isFalse,
        reason: '$key was taken for a copy on macOS',
      );
      expect(
        copy(pressed: key, onMacOS: false, control: true, shift: true),
        isFalse,
        reason: '$key was taken for a copy elsewhere',
      );
    }
  });
}
