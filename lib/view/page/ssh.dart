import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../core/utils.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/provider/server.dart';
import '../../data/res/terminal_theme.dart';
import '../../data/store/private_key.dart';
import '../../locator.dart';

class SSHPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const SSHPage({Key? key, required this.spi}) : super(key: key);

  @override
  _SSHPageState createState() => _SSHPageState();
}

class _SSHPageState extends State<SSHPage> {
  late final terminal = Terminal(inputHandler: keyboard);
  late final SSHClient client;
  final keyboard = VirtualKeyboard(defaultInputHandler);
  late double _screenWidth;

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
    _screenWidth = MediaQuery.of(context).size.width;
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

  Future<void> initTerminal() async {
    terminal.write('Connecting...\r\n');

    client = await genClient(widget.spi);
    terminal.write('Connected\r\n');

    final session = await client.shell(
      pty: SSHPtyConfig(
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    terminal.buffer.clear();
    terminal.buffer.setCursor(0, 0);

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
    final termTheme = isDark ? termDarkTheme : termLightTheme;
    return Scaffold(
      backgroundColor: termTheme.background,
      body: Column(
        children: [
          Expanded(
            child: TerminalView(
              terminal,
              keyboardType: TextInputType.visiblePassword,
              theme: termTheme,
              onSecondaryTapUp: (p0, p1) {},
              keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          _buildVirtualKey(),
        ],
      ),
    );
  }

  Widget _buildVirtualKey() {
    final half = virtualKeys.length ~/ 2;
    final top = virtualKeys.sublist(0, half);
    final bottom = virtualKeys.sublist(half);
    return Column(
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
        : Text(item.text,
            style:
                TextStyle(color: selected ? Colors.blue : null, fontSize: 15));

    return InkWell(
      onTap: () {
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
        width: _screenWidth / (virtualKeys.length / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.7),
          child: Center(
            child: child,
          ),
        ),
      ),
    );
  }
}

Future<SSHClient> genClient(ServerPrivateInfo spi) async {
  final socket = await SSHSocket.connect(spi.ip, spi.port);
  if (spi.pubKeyId == null) {
    return SSHClient(
      socket,
      username: spi.user,
      onPasswordRequest: () => spi.pwd,
    );
  }
  final key = locator<PrivateKeyStore>().get(spi.pubKeyId!);
  return SSHClient(
    socket,
    username: spi.user,
    identities: await compute(loadIndentity, key.privateKey),
  );
}

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

class VirtualKeyboard extends TerminalInputHandler with ChangeNotifier {
  final TerminalInputHandler inputHandler;

  VirtualKeyboard(this.inputHandler);

  bool ctrl = false;
  bool alt = false;

  @override
  String? call(TerminalKeyboardEvent event) {
    return inputHandler.call(event.copyWith(
      ctrl: event.ctrl || ctrl,
      alt: event.alt || alt,
    ));
  }
}
