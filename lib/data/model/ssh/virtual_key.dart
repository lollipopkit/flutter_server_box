import 'package:flutter/material.dart';
import 'package:xterm/core.dart';

class VirtualKey {
  final TerminalKey key;
  final String text;
  final bool toggleable;
  final IconData? icon;

  VirtualKey(this.key, this.text, {this.toggleable = false, this.icon});
}

var virtualKeys = [
  VirtualKey(TerminalKey.escape, 'Esc'),
  VirtualKey(TerminalKey.alt, 'Alt', toggleable: true),
  VirtualKey(TerminalKey.pageUp, 'PgUp'),
  VirtualKey(TerminalKey.arrowUp, 'Up', icon: Icons.arrow_upward),
  VirtualKey(TerminalKey.pageDown, 'PgDn'),
  VirtualKey(TerminalKey.end, 'End'),
  VirtualKey(TerminalKey.tab, 'Tab'),
  VirtualKey(TerminalKey.control, 'Ctrl', toggleable: true),
  VirtualKey(TerminalKey.arrowLeft, 'Left', icon: Icons.arrow_back),
  VirtualKey(TerminalKey.arrowDown, 'Down', icon: Icons.arrow_downward),
  VirtualKey(TerminalKey.arrowRight, 'Right', icon: Icons.arrow_forward),
  VirtualKey(TerminalKey.home, 'Home'),
];
