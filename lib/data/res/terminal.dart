import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
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
  static TerminalStyle get style {
    final family = Stores.setting.fontPath.fetch().getFileName();
    final size = Stores.setting.termFontSize.fetch();
    return TerminalStyle.fromTextStyle(
      TextStyle(fontFamily: family, fontSize: size),
    );
  }

  /// The terminal's own theme setting, falling back to the app's and then to
  /// what the system asked for.
  static bool isDark(BuildContext context) => switch (Stores
      .setting
      .termTheme
      .fetch()) {
    1 => false,
    2 => true,
    _ => switch (Stores.setting.themeMode.fetch()) {
      1 => false,
      2 || 3 => true,
      _ => context.isDark,
    },
  };

  static TerminalTheme themeOf(BuildContext context) {
    final theme = isDark(context) ? TerminalThemes.dark : TerminalThemes.light;
    return theme.copyWith(selectionCursor: UIs.primaryColor);
  }
}
