import 'package:flutter/material.dart';
import 'package:xterm/core.dart';

import '../model/ssh/virtual_key.dart';

var virtualKeys = [
  VirtualKey(TerminalKey.escape, 'Esc'),
  VirtualKey(TerminalKey.alt, 'Alt', toggleable: true),
  VirtualKey(TerminalKey.home, 'Home'),
  VirtualKey(TerminalKey.arrowUp, 'Up', icon: Icons.arrow_upward),
  VirtualKey(TerminalKey.end, 'End'),
  VirtualKey(TerminalKey.backspace, 'Backspace',
      extFunc: VirtualKeyType.backspace, icon: Icons.backspace),
  VirtualKey(TerminalKey.tab, 'Tab'),
  VirtualKey(TerminalKey.control, 'Ctrl', toggleable: true),
  VirtualKey(TerminalKey.arrowLeft, 'Left', icon: Icons.arrow_back),
  VirtualKey(TerminalKey.arrowDown, 'Down', icon: Icons.arrow_downward),
  VirtualKey(TerminalKey.arrowRight, 'Right', icon: Icons.arrow_forward),
  VirtualKey(TerminalKey.none, 'IME',
      extFunc: VirtualKeyType.toggleIME, icon: Icons.keyboard_hide),
];
