import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:xterm/xterm.dart';

import '../../core/utils/ui.dart';
import '../../core/utils/server.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/model/ssh/virtual_key.dart';
import '../../data/provider/virtual_keyboard.dart';
import '../../data/res/terminal_theme.dart';
import '../../data/res/virtual_key.dart';
import '../../locator.dart';

class SSHPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const SSHPage({Key? key, required this.spi}) : super(key: key);

  @override
  _SSHPageState createState() => _SSHPageState();
}

class _SSHPageState extends State<SSHPage> {
  late final terminal = Terminal(inputHandler: keyboard);
  SSHClient? client;
  final keyboard = locator<VirtualKeyboard>();
  late MediaQueryData _media;
  final _virtualKeyboardHeight = 57.0;

  var isDark = false;

  @override
  void initState() {
    super.initState();
    initTerminal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isDark = isDarkMode(context);
    _media = MediaQuery.of(context);
  }

  @override
  void dispose() {
    client?.close();
    super.dispose();
  }

  Future<void> initTerminal() async {
    terminal.write('Connecting...\r\n');

    client = await genClient(widget.spi);
    terminal.write('Connected\r\n');

    final session = await client!.shell(
      pty: SSHPtyConfig(
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    terminal.buffer.clear();
    terminal.buffer.setCursor(0, 0);

    terminal.onOutput = (data) {
      session.write(utf8.encode(data) as Uint8List);
    };

    session.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(terminal.write);

    session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(terminal.write);

    await session.done;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final termTheme = isDark ? termDarkTheme : termLightTheme;
    return Scaffold(
      backgroundColor: termTheme.background,
      body: SizedBox(
        height: _media.size.height -
            _virtualKeyboardHeight -
            _media.padding.bottom -
            _media.padding.top,
        child: TerminalView(
          terminal,
          keyboardType: TextInputType.visiblePassword,
          theme: termTheme,
          keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        padding: _media.viewInsets,
        duration: const Duration(milliseconds: 23),
        curve: Curves.fastOutSlowIn,
        child: SizedBox(
          height: _virtualKeyboardHeight,
          child: Consumer<VirtualKeyboard>(
            builder: (_, __, ___) => _buildVirtualKey(),
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualKey() {
    final half = virtualKeys.length ~/ 2;
    final top = virtualKeys.sublist(0, half);
    final bottom = virtualKeys.sublist(half);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: top.map((e) => _buildVirtualKeyItem(e)).toList(),
        ),
        Row(
          children: bottom.map((e) => _buildVirtualKeyItem(e)).toList(),
        )
      ],
    );
  }

  Widget _buildVirtualKeyItem(VirtualKey item) {
    var selected = false;
    switch (item.key) {
      case TerminalKey.control:
        selected = keyboard.ctrl;
        break;
      case TerminalKey.alt:
        selected = keyboard.alt;
        break;
      default:
        break;
    }

    final child = item.icon != null
        ? Icon(
            item.icon,
            color: isDark ? Colors.white : Colors.black,
            size: 17,
          )
        : Text(
            item.text,
            style: TextStyle(
              color: selected ? primaryColor : null,
              fontSize: 17,
            ),
          );

    return InkWell(
      onTap: () {
        if (item.extFunc != null) {
          switch (item.extFunc!) {
            case VirtualKeyType.toggleIME:
              FocusScope.of(context).requestFocus(FocusNode());
              break;
            case VirtualKeyType.backspace:
              terminal.keyInput(TerminalKey.backspace);
              break;
          }
          return;
        }
        switch (item.key) {
          case TerminalKey.control:
            keyboard.ctrl = !keyboard.ctrl;
            setState(() {});
            break;
          case TerminalKey.alt:
            keyboard.alt = !keyboard.alt;
            setState(() {});
            break;
          default:
            terminal.keyInput(item.key);
            break;
        }
      },
      child: SizedBox(
        width: _media.size.width / (virtualKeys.length / 2),
        height: _virtualKeyboardHeight / 2,
        child: Center(
          child: child,
        ),
      ),
    );
  }
}
