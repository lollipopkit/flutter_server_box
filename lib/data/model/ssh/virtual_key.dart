import 'package:flutter/material.dart';
import 'package:xterm/core.dart';

class VirtualKey {
  final TerminalKey key;
  final String text;
  final bool toggleable;
  final IconData? icon;
  final VirtualKeyType? extFunc;

  VirtualKey(this.key, this.text,
      {this.toggleable = false, this.icon, this.extFunc});
}

enum VirtualKeyType { toggleIME, backspace }
