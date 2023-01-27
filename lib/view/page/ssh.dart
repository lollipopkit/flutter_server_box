import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../data/model/server/server_private_info.dart';
import '../../data/provider/server.dart';
import '../../locator.dart';
import '../widget/virtual_keyboard.dart';

class SSHPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const SSHPage({Key? key, required this.spi}) : super(key: key);

  @override
  _SSHPageState createState() => _SSHPageState();
}

class _SSHPageState extends State<SSHPage> {
  late final terminal = Terminal(inputHandler: keyboard);

  final keyboard = VirtualKeyboard(defaultInputHandler);

  var title = '';

  @override
  void initState() {
    super.initState();
    initTerminal();
  }

  Future<void> initTerminal() async {
    terminal.write('Connecting...\r\n');

    final client = locator<ServerProvider>()
        .servers
        .where((e) => e.info.id == widget.spi.id)
        .first
        .client;
    if (client == null) {
      terminal.write('Failed to connect\r\n');
      return;
    }

    terminal.write('Connected\r\n');

    final session = await client.shell(
      pty: SSHPtyConfig(
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    terminal.buffer.clear();
    terminal.buffer.setCursor(0, 0);

    terminal.onTitleChange = (title) {
      setState(() => this.title = title);
    };

    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      session.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.5),
      ),
      body: Column(
        children: [
          Expanded(
            child: TerminalView(terminal, keyboardType: TextInputType.none),
          ),
          VirtualKeyboardView(keyboard),
        ],
      ),
    );
  }
}
