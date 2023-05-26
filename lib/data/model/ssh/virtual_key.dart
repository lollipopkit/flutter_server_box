import 'package:flutter/material.dart';
import 'package:xterm/core.dart';

class VirtualKey {
  final String text;
  final bool toggleable;
  final TerminalKey? key;
  final IconData? icon;
  final VirtualKeyFunc? func;

  VirtualKey(
    this.text, {
    this.key,
    this.toggleable = false,
    this.icon,
    this.func,
  });
}

enum VirtualKeyFunc { toggleIME, backspace, copy, paste, snippet }
