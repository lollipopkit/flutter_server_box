import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:xterm/xterm.dart' hide TerminalColors;

import '../../core/utils/platform.dart';
import '../../data/model/ssh/terminal_color.dart';
import '../../core/utils/misc.dart';
import '../../core/utils/ui.dart';
import '../../core/utils/server.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/model/ssh/virtual_key.dart';
import '../../data/provider/virtual_keyboard.dart';
import '../../data/res/color.dart';
import '../../data/res/terminal.dart';
import '../../data/res/virtual_key.dart';
import '../../data/store/setting.dart';
import '../../locator.dart';

class SSHPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  final String? initCmd;
  const SSHPage({Key? key, required this.spi, this.initCmd}) : super(key: key);

  @override
  _SSHPageState createState() => _SSHPageState();
}

class _SSHPageState extends State<SSHPage> {
  late final _terminal = Terminal(inputHandler: _keyboard);
  SSHClient? _client;
  final _keyboard = locator<VirtualKeyboard>();
  final _setting = locator<SettingStore>();
  late MediaQueryData _media;
  final _virtualKeyboardHeight = 57.0;
  final TerminalController _terminalController = TerminalController();
  final ContextMenuController _menuController = ContextMenuController();
  late TextStyle _menuTextStyle;
  late TerminalColors _termColors;
  late S _s;
  late TerminalStyle _terminalStyle;
  late TerminalUITheme _termUITheme;
  late TerminalTheme _terminalTheme;

  var _isDark = false;

  @override
  void initState() {
    super.initState();
    final termColorIdx = _setting.termColorIdx.fetch()!;
    _termColors = TerminalColorsPlatform.values[termColorIdx].colors;
    final fontFamilly = getFileName(_setting.fontPath.fetch());
    final textStyle = TextStyle(
      fontFamily: fontFamilly,
      fontSize: _setting.termFontSize.fetch()!,
    );
    _terminalStyle = TerminalStyle.fromTextStyle(textStyle);
    initTerminal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = isDarkMode(context);
    _media = MediaQuery.of(context);
    _menuTextStyle = TextStyle(color: contentColor.resolve(context));
    _s = S.of(context)!;
    _termUITheme = _isDark ? termDarkTheme : termLightTheme;
    _terminalTheme = _termUITheme.toTerminalTheme(_termColors);
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Scaffold(
      backgroundColor: _termUITheme.background,
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
          _virtualKeyboardHeight -
          _media.padding.bottom -
          _media.padding.top,
      child: TerminalView(
        _terminal,
        controller: _terminalController,
        textStyle: _terminalStyle,
        theme: _terminalTheme,
        deleteDetection: isIOS,
        onTapUp: _onTapUp,
        autoFocus: true,
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
          color: _termUITheme.background,
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
        selected = _keyboard.ctrl;
        break;
      case TerminalKey.alt:
        selected = _keyboard.alt;
        break;
      default:
        break;
    }

    final child = item.icon != null
        ? Icon(
            item.icon,
            color: _isDark ? Colors.white : Colors.black,
            size: 17,
          )
        : Text(
            item.text,
            style: TextStyle(
              color: selected ? primaryColor : null,
              fontSize: 15,
            ),
          );

    return InkWell(
      onTap: () => _doVirtualKey(item),
      child: SizedBox(
        width: _media.size.width / (virtualKeys.length / 2),
        height: _virtualKeyboardHeight / 2,
        child: Center(
          child: child,
        ),
      ),
    );
  }

  void _doVirtualKey(VirtualKey item) {
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
        setState(() {});
        break;
      case TerminalKey.alt:
        _keyboard.alt = !_keyboard.alt;
        setState(() {});
        break;
      default:
        _terminal.keyInput(key);
        break;
    }
  }

  void _doVirtualKeyFunc(VirtualKeyFunc type) {
    switch (type) {
      case VirtualKeyFunc.toggleIME:
        FocusScope.of(context).requestFocus(FocusNode());
        break;
      case VirtualKeyFunc.backspace:
        _terminal.keyInput(TerminalKey.backspace);
        break;
      case VirtualKeyFunc.paste:
        _paste();
        break;
      case VirtualKeyFunc.copy:
        final selected = terminalSelected;
        if (selected != null) {
          copy2Clipboard(selected);
        }
        break;
      case VirtualKeyFunc.snippet:
        showSnippetDialog(context, _s, (s) {
          _terminal.textInput(s.script);
          _terminal.keyInput(TerminalKey.enter);
        });
        break;
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

  void _onTapUp(TapUpDetails details, CellOffset offset) {
    if (_menuController.isShown) {
      _menuController.remove();
      return;
    }
    final selected = terminalSelected;
    final children = <Widget>[
      // TextButton(
      //   onPressed: () {
      //     _paste();
      //   },
      //   child: Text(_s.paste),
      // ),
    ];
    if (selected?.trim().isNotEmpty ?? false) {
      children.add(
        TextButton(
          child: Text(
            _s.copy,
            style: _menuTextStyle,
          ),
          onPressed: () {
            _terminalController.setSelection(null);
            if (selected != null) {
              copy2Clipboard(selected);
            }
            _menuController.remove();
          },
        ),
      );
    }
    if (children.isEmpty) {
      return;
    }
    _menuController.show(
      context: context,
      contextMenuBuilder: (context) {
        return TextSelectionToolbar(
          anchorAbove: details.globalPosition,
          anchorBelow: details.globalPosition,
          children: children,
        );
      },
    );
  }

  void _write(String p0) {
    _terminal.write('$p0\r\n');
  }

  Future<void> initTerminal() async {
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

    final session = await _client!.shell(
      pty: SSHPtyConfig(
        width: _terminal.viewWidth,
        height: _terminal.viewHeight,
      ),
    );

    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);

    _terminal.onOutput = (data) {
      session.write(utf8.encode(data) as Uint8List);
    };

    _listen(session.stdout);
    _listen(session.stderr);

    if (widget.initCmd != null) {
      _terminal.textInput(widget.initCmd!);
      _terminal.keyInput(TerminalKey.enter);
    }

    await session.done;
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
