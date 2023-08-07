import 'dart:io' show Process, File;
import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/res/server_cmd.dart';
import 'package:xterm/xterm.dart';

import '../../../core/route.dart';
import '../../../core/utils/platform.dart';
import '../../../core/utils/misc.dart';
import '../../../core/utils/ui.dart';
import '../../../core/utils/server.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/model/ssh/virtual_key.dart';
import '../../../data/provider/virtual_keyboard.dart';
import '../../../data/res/color.dart';
import '../../../data/res/terminal.dart';
import '../../../data/store/setting.dart';
import '../../../locator.dart';
import '../storage/sftp.dart';

startSSH(ServerPrivateInfo spi, BuildContext context) {
  if (isLinux || isMacOS) {
    unawaited(() async {
      List<String> extarArgs = [];
      if (spi.pubKeyId != null) {
        String path = "/tmp/.serverbox_pk_${spi.pubKeyId}";
        File(path).openWrite().write(getPrivateKey(spi.pubKeyId!));
        extarArgs += ["-i", path];
      }
      List<String> sshCommand = ["ssh", spi.user + "@" + spi.ip] + extarArgs;
      if (isLinux) {
        Process.start("x-terminal-emulator", ["-e"] + sshCommand);
        return;
      }
      if (isMacOS) {
        Process.start("osascript", [
          "-e",
          'tell application "Terminal" to do script "${sshCommand.join(" ")}"'
        ]);
        return;
      }
    }());
    return;
  }
  AppRoute(SSHPage(spi: spi), 'ssh page').go(context);
}

class SSHPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  final String? initCmd;
  const SSHPage({Key? key, required this.spi, this.initCmd}) : super(key: key);

  @override
  _SSHPageState createState() => _SSHPageState();
}

class _SSHPageState extends State<SSHPage> {
  final _keyboard = locator<VirtualKeyboard>();
  final _setting = locator<SettingStore>();
  late final _terminal = Terminal(inputHandler: _keyboard);
  final TerminalController _terminalController = TerminalController();
  final List<List<VirtKey>> _virtKeysList = [];

  late MediaQueryData _media;
  late S _s;
  late TerminalStyle _terminalStyle;
  late TerminalTheme _terminalTheme;
  late TextInputType _keyboardType;
  late SSHSession _session;
  late double _virtKeyWidth;
  late double _virtKeysHeight;

  bool _isDark = false;
  Timer? _virtKeyLongPressTimer;
  SSHClient? _client;

  @override
  void initState() {
    super.initState();
    final fontFamilly = getFileName(_setting.fontPath.fetch());
    final textStyle = TextStyle(
      fontFamily: fontFamilly,
      fontSize: _setting.termFontSize.fetch()!,
    );
    _terminalStyle = TerminalStyle.fromTextStyle(textStyle);
    _keyboardType = TextInputType.values[_setting.keyboardType.fetch()!];
    _initTerminal();
    _initVirtKeys();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = isDarkMode(context);
    _media = MediaQuery.of(context);
    _s = S.of(context)!;
    _terminalTheme = _isDark ? termDarkTheme : termLightTheme;
    // Calculate virtkey width / height
    _virtKeyWidth = _media.size.width / 7;
    _virtKeysHeight = _media.size.height * 0.043 * _virtKeysList.length;
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Scaffold(
      backgroundColor: _terminalTheme.background,
      body: _buildBody(),
      bottomNavigationBar: _buildBottom(),
    );
    if (isIOS) {
      child = AnnotatedRegion(
        value: _isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: child,
      );
    }
    return child;
  }

  Widget _buildBody() {
    return SizedBox(
      height: _media.size.height -
          _virtKeysHeight -
          _media.padding.bottom -
          _media.padding.top,
      child: TerminalView(
        _terminal,
        controller: _terminalController,
        keyboardType: _keyboardType,
        textStyle: _terminalStyle,
        theme: _terminalTheme,
        deleteDetection: isIOS,
        autofocus: true,
        keyboardAppearance: _isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  Widget _buildBottom() {
    return SafeArea(
      child: AnimatedPadding(
        padding: _media.viewInsets,
        duration: const Duration(milliseconds: 23),
        curve: Curves.fastOutSlowIn,
        child: Container(
          color: _terminalTheme.background,
          height: _virtKeysHeight,
          child: Consumer<VirtualKeyboard>(
            builder: (_, __, ___) => _buildVirtualKey(),
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualKey() {
    final rows = _virtKeysList
        .map((e) => Row(
              children: e.map((ee) => _buildVirtualKeyItem(ee)).toList(),
            ))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildVirtualKeyItem(VirtKey item) {
    var selected = false;
    switch (item.key) {
      case TerminalKey.control:
        selected = _keyboard.ctrl;
        break;
      case TerminalKey.alt:
        selected = _keyboard.alt;
        break;
      default:
        break;
    }

    final child = item.icon != null
        ? Icon(item.icon, size: 17)
        : Text(
            item.text,
            style: TextStyle(
              color: selected ? primaryColor : null,
              fontSize: 15,
            ),
          );

    return InkWell(
      onTap: () => _doVirtualKey(item),
      onTapDown: (details) {
        if (item.canLongPress) {
          _virtKeyLongPressTimer = Timer.periodic(
            const Duration(milliseconds: 137),
            (_) => _doVirtualKey(item),
          );
        }
      },
      onTapCancel: () => _virtKeyLongPressTimer?.cancel(),
      onTapUp: (_) => _virtKeyLongPressTimer?.cancel(),
      child: SizedBox(
        width: _virtKeyWidth,
        height: _virtKeysHeight / _virtKeysList.length,
        child: Center(
          child: child,
        ),
      ),
    );
  }

  void _doVirtualKey(VirtKey item) {
    if (item.func != null) {
      _doVirtualKeyFunc(item.func!);
      return;
    }
    if (item.key != null) {
      _doVirtualKeyInput(item.key!);
    }
  }

  void _doVirtualKeyInput(TerminalKey key) {
    switch (key) {
      case TerminalKey.control:
        _keyboard.ctrl = !_keyboard.ctrl;
        break;
      case TerminalKey.alt:
        _keyboard.alt = !_keyboard.alt;
        break;
      default:
        _terminal.keyInput(key);
        break;
    }
  }

  Future<void> _doVirtualKeyFunc(VirtualKeyFunc type) async {
    switch (type) {
      case VirtualKeyFunc.toggleIME:
        FocusScope.of(context).requestFocus(FocusNode());
        break;
      case VirtualKeyFunc.backspace:
        _terminal.keyInput(TerminalKey.backspace);
        break;
      case VirtualKeyFunc.clipboard:
        final selected = terminalSelected;
        if (selected != null) {
          copy2Clipboard(selected);
        } else {
          _paste();
        }
        break;
      case VirtualKeyFunc.snippet:
        showSnippetDialog(context, _s, (s) {
          _terminal.textInput(s.script);
          _terminal.keyInput(TerminalKey.enter);
        });
        break;
      case VirtualKeyFunc.file:
        // get $PWD from SSH session
        _terminal.textInput(echoPWD);
        _terminal.keyInput(TerminalKey.enter);
        final cmds = _terminal.buffer.lines.toList();
        // wait for the command to finish
        await Future.delayed(const Duration(milliseconds: 777));
        // the line below `echo $PWD` is the current path
        final idx = cmds.lastIndexWhere((e) => e.toString().contains(echoPWD));
        final initPath = cmds[idx + 1].toString();
        if (initPath.isEmpty || !initPath.startsWith('/')) {
          showRoundDialog(
            context: context,
            title: Text(_s.error),
            child: const Text('Failed to get current path'),
          );
          return;
        }
        AppRoute(
                SftpPage(
                  widget.spi,
                  initPath: initPath,
                ),
                'SSH SFTP')
            .go(context);
    }
  }

  void _paste() {
    Clipboard.getData(Clipboard.kTextPlain).then((value) {
      if (value != null) {
        _terminal.textInput(value.text!);
      }
    });
  }

  String? get terminalSelected {
    final range = _terminalController.selection;
    if (range == null) {
      return null;
    }
    return _terminal.buffer.getText(range);
  }

  void _write(String p0) {
    _terminal.write('$p0\r\n');
  }

  void _initVirtKeys() {
    final virtKeys = List<VirtKey>.from(_setting.sshVirtKeys.fetchRaw());

    for (int len = 0; len < virtKeys.length; len += 7) {
      if (len + 7 > virtKeys.length) {
        _virtKeysList.add(virtKeys.sublist(len));
      } else {
        _virtKeysList.add(virtKeys.sublist(len, len + 7));
      }
    }
  }

  Future<void> _initTerminal() async {
    _write('Connecting...\r\n');

    _client = await genClient(
      widget.spi,
      onStatus: (p0) {
        switch (p0) {
          case GenSSHClientStatus.socket:
            _write('Destination: ${widget.spi.id}');
            return _write('Establishing socket...');
          case GenSSHClientStatus.key:
            return _write('Using private key to connect...');
          case GenSSHClientStatus.pwd:
            return _write('Sending password to auth...');
        }
      },
    );
    _write('Connected\r\n');
    _write('Terminal size: ${_terminal.viewWidth}x${_terminal.viewHeight}\r\n');
    _write('Starting shell...\r\n');

    _session = await _client!.shell(
      pty: SSHPtyConfig(
        width: _terminal.viewWidth,
        height: _terminal.viewHeight,
      ),
    );

    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);

    _terminal.onOutput = (data) {
      _session.write(utf8.encode(data) as Uint8List);
    };

    _listen(_session.stdout);
    _listen(_session.stderr);

    if (widget.initCmd != null) {
      _terminal.textInput(widget.initCmd!);
      _terminal.keyInput(TerminalKey.enter);
    }

    await _session.done;
    if (mounted) {
      context.pop();
    }
  }

  void _listen(Stream<Uint8List> stream) {
    stream
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(_terminal.write);
  }
}
