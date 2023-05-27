import 'package:flutter/material.dart';
import 'package:xterm/ui.dart' hide TerminalColors;

class TerminalUITheme {
  final Color cursor;
  final Color selection;
  final Color foreground;
  final Color background;
  final Color searchHitBackground;
  final Color searchHitBackgroundCurrent;
  final Color searchHitForeground;

  const TerminalUITheme({
    required this.cursor,
    required this.selection,
    required this.foreground,
    required this.background,
    required this.searchHitBackground,
    required this.searchHitBackgroundCurrent,
    required this.searchHitForeground,
  });

  TerminalTheme toTerminalTheme(TerminalColors termColor) {
    return TerminalTheme(
      cursor: cursor,
      selection: selection,
      foreground: foreground,
      background: background,
      black: termColor.black,
      red: termColor.red,
      green: termColor.green,
      yellow: termColor.yellow,
      blue: termColor.blue,
      magenta: termColor.magenta,
      cyan: termColor.cyan,
      white: termColor.white,
      brightBlack: termColor.brightBlack,
      brightRed: termColor.brightRed,
      brightGreen: termColor.brightGreen,
      brightYellow: termColor.brightYellow,
      brightBlue: termColor.brightBlue,
      brightMagenta: termColor.brightMagenta,
      brightCyan: termColor.brightCyan,
      brightWhite: termColor.brightWhite,
      searchHitBackground: searchHitBackground,
      searchHitBackgroundCurrent: searchHitBackgroundCurrent,
      searchHitForeground: searchHitForeground,
    );
  }
}

class TerminalColors {
  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;

  /// Also called grey
  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;

  const TerminalColors(
    this.red,
    this.green,
    this.yellow,
    this.blue,
    this.magenta,
    this.cyan,
    this.white,
    this.brightBlack,
    this.brightRed,
    this.brightGreen,
    this.brightYellow,
    this.brightBlue,
    this.brightMagenta,
    this.brightCyan, {
    this.black = const Color(0x00000000),
    this.brightWhite = const Color(0xFFFFFFFF),
  });
}
