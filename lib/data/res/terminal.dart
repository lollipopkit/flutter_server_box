import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/res/store.dart';
import 'package:xterm/ui.dart';

abstract final class TerminalThemes {
  static const dark = TerminalTheme(
    cursor: Color.fromARGB(137, 174, 175, 173),
    selectionCursor: Color(0xff8b2252),
    selection: Color.fromARGB(147, 174, 175, 173),
    foreground: Color(0XFFCCCCCC),
    background: Colors.black,
    searchHitBackground: Color(0XFFFFFF2B),
    searchHitBackgroundCurrent: Color(0XFF31FF26),
    searchHitForeground: Color(0XFF000000),
    red: Color.fromARGB(255, 194, 54, 33),
    green: Color.fromARGB(255, 37, 188, 36),
    yellow: Color.fromARGB(255, 173, 173, 39),
    blue: Color.fromARGB(255, 73, 46, 225),
    magenta: Color.fromARGB(255, 211, 56, 211),
    cyan: Color.fromARGB(255, 51, 187, 200),
    white: Color.fromARGB(255, 203, 204, 205),
    brightBlack: Color.fromARGB(255, 129, 131, 131),
    brightRed: Color.fromARGB(255, 252, 57, 31),
    brightGreen: Color.fromARGB(255, 49, 231, 34),
    brightYellow: Color.fromARGB(255, 234, 236, 35),
    brightBlue: Color.fromARGB(255, 88, 51, 255),
    brightMagenta: Color.fromARGB(255, 249, 53, 248),
    brightCyan: Color.fromARGB(255, 20, 240, 240),
    brightWhite: Color.fromARGB(255, 233, 235, 235),
    black: Colors.black,
  );
  static const light = TerminalTheme(
    cursor: Color.fromARGB(153, 174, 175, 173),
    selectionCursor: Color(0xff8b2252),
    selection: Color.fromARGB(102, 174, 175, 173),
    foreground: Color(0XFF000000),
    background: Color(0XFFFFFFFF),
    searchHitBackground: Color(0XFFFFFF2B),
    searchHitBackgroundCurrent: Color(0XFF31FF26),
    searchHitForeground: Color(0XFF000000),
    red: Color.fromARGB(255, 194, 54, 33),
    green: Color.fromARGB(255, 37, 188, 36),
    yellow: Color.fromARGB(255, 173, 173, 39),
    blue: Color.fromARGB(255, 73, 46, 225),
    magenta: Color.fromARGB(255, 211, 56, 211),
    cyan: Color.fromARGB(255, 51, 187, 200),
    white: Color.fromARGB(255, 203, 204, 205),
    brightBlack: Color.fromARGB(255, 129, 131, 131),
    brightRed: Color.fromARGB(255, 252, 57, 31),
    brightGreen: Color.fromARGB(255, 49, 231, 34),
    brightYellow: Color.fromARGB(255, 234, 236, 35),
    brightBlue: Color.fromARGB(255, 88, 51, 255),
    brightMagenta: Color.fromARGB(255, 249, 53, 248),
    brightCyan: Color.fromARGB(255, 20, 240, 240),
    brightWhite: Color.fromARGB(255, 233, 235, 235),
    black: Colors.black,
  );
}

extension TerminalThemeX on TerminalTheme {
  TerminalTheme copyWith({
    Color? cursor,
    Color? selectionCursor,
    Color? selection,
    Color? foreground,
    Color? background,
    Color? searchHitBackground,
    Color? searchHitBackgroundCurrent,
    Color? searchHitForeground,
    Color? red,
    Color? green,
    Color? yellow,
    Color? blue,
    Color? magenta,
    Color? cyan,
    Color? white,
    Color? brightBlack,
    Color? brightRed,
    Color? brightGreen,
    Color? brightYellow,
    Color? brightBlue,
    Color? brightMagenta,
    Color? brightCyan,
    Color? brightWhite,
    Color? black,
  }) {
    return TerminalTheme(
      cursor: cursor ?? this.cursor,
      selectionCursor: selectionCursor ?? this.selectionCursor,
      selection: selection ?? this.selection,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      searchHitBackground: searchHitBackground ?? this.searchHitBackground,
      searchHitBackgroundCurrent:
          searchHitBackgroundCurrent ?? this.searchHitBackgroundCurrent,
      searchHitForeground: searchHitForeground ?? this.searchHitForeground,
      red: red ?? this.red,
      green: green ?? this.green,
      yellow: yellow ?? this.yellow,
      blue: blue ?? this.blue,
      magenta: magenta ?? this.magenta,
      cyan: cyan ?? this.cyan,
      white: white ?? this.white,
      brightBlack: brightBlack ?? this.brightBlack,
      brightRed: brightRed ?? this.brightRed,
      brightGreen: brightGreen ?? this.brightGreen,
      brightYellow: brightYellow ?? this.brightYellow,
      brightBlue: brightBlue ?? this.brightBlue,
      brightMagenta: brightMagenta ?? this.brightMagenta,
      brightCyan: brightCyan ?? this.brightCyan,
      brightWhite: brightWhite ?? this.brightWhite,
      black: black ?? this.black,
    );
  }
}

/// How a terminal is configured to look, wherever one is shown.
///
/// Shared rather than read where it is needed, so the terminal in a dialog and
/// the terminal in a tab cannot end up on different fonts or a different theme.
abstract final class TerminalLook {
  /// The bounds of [SettingStore.termLineHeight].
  static const minLineHeight = 1.0;
  static const maxLineHeight = 2.0;

  static TerminalStyle styleOf(BuildContext context) {
    final family = Stores.setting.fontPath.fetch().getFileName();
    final style = TerminalStyle.fromTextStyle(
      TextStyle(
        fontSize: Stores.setting.termFontSize.fetch(),
        height: Stores.setting.termLineHeight.fetch().clamp(
          minLineHeight,
          maxLineHeight,
        ),
      ),
    );
    final fonts = fontsFor(
      custom: family,
      linux: isLinux,
      uiFallbacks:
          Theme.of(context).textTheme.bodyMedium?.fontFamilyFallback ??
          const [],
    );
    return style.copyWith(
      fontFamily: fonts.first,
      fontFamilyFallback: fonts.skip(1).toList(),
    );
  }

  /// The families a terminal asks for, in order: [custom] first when there
  /// is one, then xterm's monospace and CJK list, then the UI's own fallbacks.
  ///
  /// On [linux] the fontconfig `monospace` alias goes right after [custom]:
  /// it is the font the system's own terminal uses. Last in xterm's list, it
  /// came after macOS's and Windows's fonts and after Noto Sans Mono CJK, so
  /// a system without Liberation Mono drew Latin text in a CJK font's glyphs
  /// — not what the system terminal showed. A family is listed once.
  @visibleForTesting
  static List<String> fontsFor({
    required String? custom,
    required bool linux,
    List<String> uiFallbacks = const [],
  }) {
    final fonts = <String>[
      if (custom != null && custom.isNotEmpty) custom,
      if (linux) 'monospace',
      ...const TerminalStyle().fontFamilyFallback,
      ...uiFallbacks,
    ];
    final seen = <String>{};
    return [
      for (final font in fonts)
        if (seen.add(font)) font,
    ];
  }

  /// The terminal's own theme setting, falling back to the app's and then to
  /// what the system asked for.
  static bool isDark(BuildContext context) =>
      switch (Stores.setting.termTheme.fetch()) {
        1 => false,
        2 => true,
        _ => context.isDark,
      };

  static TerminalTheme themeOf(BuildContext context) {
    final theme = isDark(context) ? TerminalThemes.dark : TerminalThemes.light;
    return theme.copyWith(selectionCursor: UIs.primaryColor);
  }
}

/// The terminal font file the user chose ([SettingStore.fontPath]), and
/// whether it loaded: a file that is gone or not a font leaves the terminal on
/// the default fonts, which the settings page says rather than only logs.
abstract final class TerminalFont {
  /// Whether the chosen file failed to load. False with none chosen.
  static final failed = ValueNotifier(false);

  static Future<void> load(String path) async {
    if (path.isEmpty) {
      failed.value = false;
      return;
    }
    try {
      if (!await File(path).exists()) throw FileSystemException('missing', path);
      await FontUtils.loadFrom(path);
      failed.value = false;
    } catch (e, s) {
      failed.value = true;
      Loggers.app.warning('Could not load the terminal font', e, s);
    }
  }
}

