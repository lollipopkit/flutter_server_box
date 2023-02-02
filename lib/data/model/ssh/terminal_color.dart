import 'package:flutter/material.dart';
import 'package:toolbox/data/res/terminal_color.dart';
import 'package:xterm/ui.dart';

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

abstract class TerminalColors {
  final TerminalColorsPlatform platform;
  final Color black = Colors.black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  // 品红
  final Color magenta;
  // 青
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

  TerminalColors(
    this.platform,
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
    this.brightWhite = Colors.white,
  });
}

enum TerminalColorsPlatform {
  macOS,
  vga,
  cmd,
  putty,
  xterm,
  ubuntu,
  ;

  String get name {
    switch (this) {
      case TerminalColorsPlatform.vga:
        return 'VGA';
      case TerminalColorsPlatform.cmd:
        return 'CMD';
      case TerminalColorsPlatform.macOS:
        return 'macOS';
      case TerminalColorsPlatform.putty:
        return 'PuTTY';
      case TerminalColorsPlatform.xterm:
        return 'XTerm';
      case TerminalColorsPlatform.ubuntu:
        return 'Ubuntu';
      default:
        return 'Unknown';
    }
  }

  TerminalColors get colors {
    switch (this) {
      case TerminalColorsPlatform.vga:
        return VGATerminalColor();
      case TerminalColorsPlatform.cmd:
        return CMDTerminalColor();
      case TerminalColorsPlatform.macOS:
        return MacOSTerminalColor();
      case TerminalColorsPlatform.putty:
        return PuttyTerminalColor();
      case TerminalColorsPlatform.xterm:
        return XTermTerminalColor();
      case TerminalColorsPlatform.ubuntu:
        return UbuntuTerminalColor();
      default:
        return MacOSTerminalColor();
    }
  }
}
