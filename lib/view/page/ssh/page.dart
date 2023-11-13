import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/share.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/provider/virtual_keyboard.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart' hide TerminalThemes;

import '../../../core/route.dart';
import '../../../core/utils/misc.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/model/ssh/virtual_key.dart';
import '../../../data/res/color.dart';
import '../../../data/res/terminal.dart';

const _echoPWD = 'echo \$PWD';

class SSHPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  final String? initCmd;
  final bool pop;
  const SSHPage({
    Key? key,
    required this.spi,
    this.initCmd,
    this.pop = true,
  }) : super(key: key);

  @override
  _SSHPageState createState() => _SSHPageState();
}

class _SSHPageState extends State<SSHPage> with AutomaticKeepAliveClientMixin {
  final _keyboard = VirtKeyProvider();
  late final _terminal = Terminal(inputHandler: _keyboard);
  final TerminalController _terminalController = TerminalController();
  final List<List<VirtKey>> _virtKeysList = [];

  late MediaQueryData _media;
  late TerminalStyle _terminalStyle;
  late TerminalTheme _terminalTheme;
  late TextInputType _keyboardType;
  double _virtKeyWidth = 0;
  double _virtKeysHeight = 0;

  bool _isDark = false;
  Timer? _virtKeyLongPressTimer;
  late final Server? _server = widget.spi.server;
  late final SSHClient? _client = _server?.client;
  Timer? _discontinuityTimer;

  @override
  void initState() {
    super.initState();
    final fontFamilly = getFileName(Stores.setting.fontPath.fetch());
    final textStyle = TextStyle(
      fontFamily: fontFamilly,
      fontSize: Stores.setting.termFontSize.fetch(),
    );
    _terminalStyle = TerminalStyle.fromTextStyle(textStyle);
    _keyboardType = TextInputType.values[Stores.setting.keyboardType.fetch()];
    _initVirtKeys();

    Future.delayed(const Duration(milliseconds: 77), () async {
      await _initTerminal();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _virtKeyLongPressTimer?.cancel();
    _terminalController.dispose();

    /// Use the same [SSHClient], so don't close it
    // if (_client?.isClosed == false) {
    //   try {
    //     _client?.close();
    //   } catch (_) {}
    // }
    _discontinuityTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = context.isDark;
    _media = MediaQuery.of(context);
    _terminalTheme = _isDark ? TerminalThemes.dark : TerminalThemes.light;

    // Because the virtual keyboard only displayed on mobile devices
    if (isMobile) {
      _virtKeyWidth = _media.size.width / 7;
      _virtKeysHeight = _media.size.height * 0.043 * _virtKeysList.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget child = Scaffold(
      backgroundColor: _terminalTheme.background,
      body: _buildBody(),
      bottomNavigationBar: isDesktop ? null : _buildBottom(),
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
      child: Padding(
        padding: EdgeInsets.only(top: _media.padding.top),
        child: TerminalView(
          _terminal,
          controller: _terminalController,
          keyboardType: _keyboardType,
          textStyle: _terminalStyle,
          theme: _terminalTheme,
          deleteDetection: isIOS,
          autofocus: true,
          keyboardAppearance: _isDark ? Brightness.dark : Brightness.light,
          hideScrollBar: false,
        ),
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
          child: ChangeNotifierProvider(
            create: (_) => _keyboard,
            builder: (_, __) =>
                Consumer<VirtKeyProvider>(builder: (_, __, ___) {
              return _buildVirtualKey();
            }),
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
          Shares.copy(selected);
        } else {
          _paste();
        }
        break;
      case VirtualKeyFunc.snippet:
        final s = await context.showPickSingleDialog<Snippet>(
          items: Pros.snippet.snippets,
          name: (p0) => p0.name,
        );
        if (s == null) return;
        _terminal.textInput(s.script);
        _terminal.keyInput(TerminalKey.enter);
        break;
      case VirtualKeyFunc.file:
        // get $PWD from SSH session
        _terminal.textInput(_echoPWD);
        _terminal.keyInput(TerminalKey.enter);
        final cmds = _terminal.buffer.lines.toList();
        // wait for the command to finish
        await Future.delayed(const Duration(milliseconds: 777));
        // the line below `echo $PWD` is the current path
        final idx = cmds.lastIndexWhere((e) => e.toString().contains(_echoPWD));
        final initPath = cmds[idx + 1].toString();
        if (initPath.isEmpty || !initPath.startsWith('/')) {
          context.showRoundDialog(
            title: Text(l10n.error),
            child: const Text('Failed to get current path'),
          );
          return;
        }
        AppRoute.sftp(spi: widget.spi, initPath: initPath).go(context);
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
    final virtKeys = List<VirtKey>.from(Stores.setting.sshVirtKeys.fetch());

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
    if (_client == null) {
      await Pros.server.refreshData(spi: widget.spi);
    }
    _write('Starting shell...\r\n');

    final session = await _client?.shell(
      pty: SSHPtyConfig(
        width: _terminal.viewWidth,
        height: _terminal.viewHeight,
      ),
    );

    _setupDiscontinuityTimer();

    if (session == null) {
      _write(_server?.status.err ?? 'Null session');
      return;
    }

    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);

    _terminal.onOutput = (data) {
      session.write(utf8.encode(data) as Uint8List);
    };
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      session.resizeTerminal(width, height);
    };

    _listen(session.stdout);
    _listen(session.stderr);

    if (widget.initCmd != null) {
      _terminal.textInput(widget.initCmd!);
      _terminal.keyInput(TerminalKey.enter);
    }

    await session.done;
    if (mounted && widget.pop) {
      context.pop();
    }
  }

  void _listen(Stream<Uint8List>? stream) {
    if (stream == null) {
      return;
    }
    stream
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(_terminal.write);
  }

  void _setupDiscontinuityTimer() {
    _discontinuityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        var throwTimeout = true;
        Future.delayed(const Duration(seconds: 3), () {
          if (throwTimeout) {
            _catchTimeout();
          }
        });
        await _client?.ping();
        throwTimeout = false;
      },
    );
  }

  void _catchTimeout() {
    _discontinuityTimer?.cancel();
    if (!mounted) return;
    _write('\n\nConnection lost\r\n');
    context.showRoundDialog(
      title: Text(l10n.attention),
      child: Text('${l10n.disconnected}\n${l10n.goBackQ}'),
      barrierDismiss: false,
      actions: [
        TextButton(
          onPressed: () {
            if (mounted) {
              context.pop();
              context.pop();
            }
          },
          child: Text(l10n.ok),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
