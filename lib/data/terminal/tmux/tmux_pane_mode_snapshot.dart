/// The terminal-mode state of a tmux pane.
///
/// `capture-pane` restores screen content, not protocol behaviour. This model
/// is queried from tmux before a capture so the local xterm can be placed in
/// the same input/output mode as the program still running in the pane.
final class TmuxPaneModeSnapshot {
  static const queryFormat =
      '#{alternate_on}\t#{alternate_saved_x}\t#{alternate_saved_y}'
      '\t#{cursor_flag}\t#{cursor_blinking}\t#{cursor_shape}'
      '\t#{cursor_very_visible}\t#{insert_flag}\t#{origin_flag}\t#{wrap_flag}'
      '\t#{keypad_cursor_flag}\t#{keypad_flag}\t#{bracket_paste_flag}'
      '\t#{mouse_standard_flag}\t#{mouse_button_flag}\t#{mouse_any_flag}'
      '\t#{mouse_all_flag}\t#{mouse_sgr_flag}\t#{mouse_utf8_flag}'
      '\t#{pane_key_mode}';

  final bool alternateScreen;
  final int alternateSavedX;
  final int alternateSavedY;
  final bool cursorVisible;
  final bool cursorBlinking;
  final String cursorShape;
  final bool cursorVeryVisible;
  final bool insertMode;
  final bool originMode;
  final bool wrapMode;
  final bool applicationCursorKeys;
  final bool applicationKeypad;
  final bool bracketedPaste;
  final bool mouseStandard;
  final bool mouseButton;
  final bool mouseAny;
  final bool mouseAll;
  final bool mouseSgr;
  final bool mouseUtf8;
  final String extendedKeyMode;

  const TmuxPaneModeSnapshot({
    this.alternateScreen = false,
    this.alternateSavedX = 0,
    this.alternateSavedY = 0,
    this.cursorVisible = true,
    this.cursorBlinking = false,
    this.cursorShape = 'default',
    this.cursorVeryVisible = false,
    this.insertMode = false,
    this.originMode = false,
    this.wrapMode = true,
    this.applicationCursorKeys = false,
    this.applicationKeypad = false,
    this.bracketedPaste = false,
    this.mouseStandard = false,
    this.mouseButton = false,
    this.mouseAny = false,
    this.mouseAll = false,
    this.mouseSgr = false,
    this.mouseUtf8 = false,
    this.extendedKeyMode = 'VT10x',
  });

  factory TmuxPaneModeSnapshot.parse(String line) {
    final fields = line.split('\t');
    if (fields.length < 20) {
      return const TmuxPaneModeSnapshot();
    }

    int number(int index, int fallback) =>
        int.tryParse(fields[index].trim()) ?? fallback;
    bool flag(int index, bool fallback) {
      final value = fields[index].trim().toLowerCase();
      if (value.isEmpty) return fallback;
      return value == '1' || value == 'true' || value == 'yes';
    }

    int savedCursor(int value) => value < 0 || value >= 0x7fffffff ? 0 : value;
    final savedX = savedCursor(number(1, 0));
    final savedY = savedCursor(number(2, 0));
    return TmuxPaneModeSnapshot(
      alternateScreen: flag(0, false),
      alternateSavedX: savedX,
      alternateSavedY: savedY,
      cursorVisible: flag(3, true),
      cursorBlinking: flag(4, false),
      cursorShape: fields[5].trim().isEmpty ? 'default' : fields[5].trim(),
      cursorVeryVisible: flag(6, false),
      insertMode: flag(7, false),
      originMode: flag(8, false),
      wrapMode: flag(9, true),
      applicationCursorKeys: flag(10, false),
      applicationKeypad: flag(11, false),
      bracketedPaste: flag(12, false),
      mouseStandard: flag(13, false),
      mouseButton: flag(14, false),
      mouseAny: flag(15, false),
      mouseAll: flag(16, false),
      mouseSgr: flag(17, false),
      mouseUtf8: flag(18, false),
      extendedKeyMode: fields[19].trim().isEmpty ? 'VT10x' : fields[19].trim(),
    );
  }

  /// Sequence applied after `RIS`, before the captured screen is written.
  ///
  /// Alternate screen is entered last because DECSET 1049 saves the current
  /// cursor and clears the alternate buffer. The cursor is first moved to
  /// tmux's recorded pre-alternate position, so a later exit from Vim restores
  /// the same place in the main screen.
  String get restorePrefix {
    final out = StringBuffer();

    void setAnsiMode(int mode, bool enabled) {
      out.write('\x1b[$mode${enabled ? 'h' : 'l'}');
    }

    void setDecMode(int mode, bool enabled) {
      out.write('\x1b[?$mode${enabled ? 'h' : 'l'}');
    }

    setAnsiMode(4, insertMode);
    setDecMode(1, applicationCursorKeys);
    setDecMode(6, originMode);
    setDecMode(7, wrapMode);
    setDecMode(25, cursorVisible);
    setDecMode(12, cursorBlinking);
    setDecMode(2004, bracketedPaste);

    final shapeCode = _cursorShapeCode;
    if (shapeCode != null) out.write('\x1b[$shapeCode q');

    // tmux's flags name the tracking mode: standard is DECSET 1000, button
    // 1002, all 1003. `mouse_any_flag` is set by any of them, so it names none.
    final mouseMode = mouseAll
        ? 1003
        : mouseButton
        ? 1002
        : mouseStandard
        ? 1000
        : null;
    if (mouseMode != null) {
      setDecMode(mouseMode, true);
      if (mouseSgr) {
        setDecMode(1006, true);
      } else if (mouseUtf8) {
        setDecMode(1005, true);
      }
    }

    out.write(applicationKeypad ? '\x1b=' : '\x1b>');

    if (alternateScreen) {
      out
        ..write('\x1b[${alternateSavedY + 1};${alternateSavedX + 1}H')
        ..write('\x1b[?1049h');
    }
    return out.toString();
  }

  int? get _cursorShapeCode {
    final base = switch (cursorShape.toLowerCase()) {
      'block' => 1,
      'underline' => 3,
      'bar' => 5,
      _ => null,
    };
    if (base == null) return null;
    return cursorBlinking ? base : base + 1;
  }

  @override
  String toString() =>
      'TmuxPaneMode('
      'alternate=$alternateScreen,'
      'cursorKeys=$applicationCursorKeys,'
      'keypad=$applicationKeypad,'
      'paste=$bracketedPaste,'
      'extendedKeys=$extendedKeyMode'
      ')';
}
