import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/provider/virtual_keyboard.dart';
import 'package:server_box/data/res/store.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart' hide TerminalThemes;

import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/terminal.dart';

const _echoPWD = 'echo \$PWD';

class SSHPage extends StatefulWidget {
  final Spi spi;
  final String? initCmd;
  final Snippet? initSnippet;
  final bool notFromTab;
  final Function()? onSessionEnd;
  final GlobalKey<TerminalViewState>? terminalKey;
  final FocusNode? focusNode;

  const SSHPage({
    super.key,
    required this.spi,
    this.initCmd,
    this.initSnippet,
    this.notFromTab = true,
    this.onSessionEnd,
    this.terminalKey,
    this.focusNode,
  });

  @override
  State<SSHPage> createState() => SSHPageState();
}

const _horizonPadding = 7.0;

class SSHPageState extends State<SSHPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin {
  final _keyboard = VirtKeyProvider();
  late final _terminal = Terminal(inputHandler: _keyboard);
  final TerminalController _terminalController = TerminalController();
  final List<List<VirtKey>> _virtKeysList = [];
  late final _termKey = widget.terminalKey ?? GlobalKey<TerminalViewState>();

  late MediaQueryData _media;
  late TerminalStyle _terminalStyle;
  late TerminalTheme _terminalTheme;
  double _virtKeyWidth = 0;
  double _virtKeysHeight = 0;
  late final _horizonVirtKeys = Stores.setting.horizonVirtKey.fetch();

  bool _isDark = false;
  Timer? _virtKeyLongPressTimer;
  late SSHClient? _client = widget.spi.server?.value.client;
  Timer? _discontinuityTimer;

  /// Used for (de)activate the wake lock and forground service
  static var _sshConnCount = 0;

  @override
  void dispose() {
    _virtKeyLongPressTimer?.cancel();
    _terminalController.dispose();
    _discontinuityTimer?.cancel();

    if (--_sshConnCount <= 0) {
      WakelockPlus.disable();
      if (isAndroid) {
        MethodChans.stopService();
      }
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initStoredCfg();
    _initVirtKeys();
    _setupDiscontinuityTimer();

    if (++_sshConnCount == 1) {
      WakelockPlus.enable();
      if (isAndroid) {
        MethodChans.startService();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = switch (Stores.setting.termTheme.fetch()) {
      1 => false,
      2 => true,
      _ => context.isDark,
    };
    _media = context.mediaQuery;

    _terminalTheme = _isDark ? TerminalThemes.dark : TerminalThemes.light;
    _terminalTheme = _terminalTheme.copyWith(selectionCursor: UIs.primaryColor);

    // Because the virtual keyboard only displayed on mobile devices
    if (isMobile) {
      _virtKeyWidth = _media.size.width / 7;
      if (_horizonVirtKeys) {
        _virtKeysHeight = _media.size.height * 0.043;
      } else {
        _virtKeysHeight = _media.size.height * 0.043 * _virtKeysList.length;
      }
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
    final letterCache = Stores.setting.letterCache.fetch();
    return SizedBox(
      height: _media.size.height -
          _virtKeysHeight -
          _media.padding.bottom -
          _media.padding.top,
      child: Padding(
        padding: EdgeInsets.only(
          top: widget.notFromTab ? CustomAppBar.sysStatusBarHeight ?? 0 : 0,
          left: _horizonPadding,
          right: _horizonPadding,
        ),
        child: TerminalView(
          _terminal,
          key: _termKey,
          controller: _terminalController,
          keyboardType: TextInputType.text,
          enableSuggestions: letterCache,
          textStyle: _terminalStyle,
          theme: _terminalTheme,
          deleteDetection: isMobile,
          autofocus: false,
          keyboardAppearance: _isDark ? Brightness.dark : Brightness.light,
          showToolbar: isMobile,
          viewOffset: Offset(
            2 * _horizonPadding,
            CustomAppBar.sysStatusBarHeight ?? _media.padding.top,
          ),
          hideScrollBar: false,
          focusNode: widget.focusNode,
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
    if (_horizonVirtKeys) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              _virtKeysList.expand((e) => e).map(_buildVirtKeyItem).toList(),
        ),
      );
    }
    final rows = _virtKeysList
        .map((e) => Row(children: e.map(_buildVirtKeyItem).toList()))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildVirtKeyItem(VirtKey item) {
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
            size: 17,
            color: _isDark ? Colors.white : Colors.black,
          )
        : Text(
            item.text,
            style: TextStyle(
              color: selected
                  ? UIs.primaryColor
                  : (_isDark ? Colors.white : Colors.black),
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
        child: Center(child: child),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  void _initStoredCfg() {
    final fontFamilly = Stores.setting.fontPath.fetch().getFileName();
    final textSize = Stores.setting.termFontSize.fetch();
    final textStyle = TextStyle(
      fontFamily: fontFamilly,
      fontSize: textSize,
    );

    _terminalStyle = TerminalStyle.fromTextStyle(textStyle);
  }

  Future<void> _showHelp() async {
    if (Stores.setting.sshTermHelpShown.fetch()) return;

    return await context.showRoundDialog(
      title: libL10n.doc,
      child: Text(l10n.sshTermHelp),
      actions: [
        TextButton(
          onPressed: () {
            Stores.setting.sshTermHelpShown.put(true);
            context.pop();
          },
          child: Text(l10n.noPromptAgain),
        ),
      ],
    );
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    await _showHelp();
    await _initTerminal();

    if (Stores.setting.sshWakeLock.fetch()) WakelockPlus.enable();
  }
}

extension _Init on SSHPageState {
  Future<void> _initTerminal() async {
    _writeLn(l10n.waitConnection);
    _client ??= await genClient(
      widget.spi,
      onStatus: (p0) {
        _writeLn(p0.toString());
      },
      onKeyboardInteractive: _onKeyboardInteractive,
    );

    _writeLn('${libL10n.execute}: Shell');
    final session = await _client?.shell(
      pty: SSHPtyConfig(
        width: _terminal.viewWidth,
        height: _terminal.viewHeight,
      ),
      environment: widget.spi.envs,
    );

    //_setupDiscontinuityTimer();

    if (session == null) {
      _writeLn(libL10n.fail);
      return;
    }

    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);

    _terminal.onOutput = (data) {
      session.write(utf8.encode(data));
    };
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      session.resizeTerminal(width, height);
    };

    _listen(session.stdout);
    _listen(session.stderr);

    for (final snippet in SnippetProvider.snippets.value) {
      if (snippet.autoRunOn?.contains(widget.spi.id) == true) {
        snippet.runInTerm(_terminal, widget.spi);
      }
    }

    if (widget.initCmd != null) {
      _terminal.textInput(widget.initCmd!);
      _terminal.keyInput(TerminalKey.enter);
    }

    if (widget.initSnippet != null) {
      widget.initSnippet!.runInTerm(_terminal, widget.spi);
    }

    widget.focusNode?.requestFocus();

    await session.done;
    if (mounted && widget.notFromTab) {
      context.pop();
    }
    widget.onSessionEnd?.call();
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
    _writeLn('\n\nConnection lost\r\n');
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text('${l10n.disconnected}\n${l10n.goBackQ}'),
      barrierDismiss: false,
      actions: Btn.ok(
        onTap: () {
          if (mounted) {
            context.pop();
          }
        },
      ).toList,
    );
  }

  void _writeLn(String p0) {
    _terminal.write('$p0\r\n');
  }
}

extension _VirtKey on SSHPageState {
  void _doVirtualKey(VirtKey item) {
    if (item.func != null) {
      HapticFeedback.mediumImpact();
      _doVirtualKeyFunc(item.func!);
      return;
    }
    if (item.key != null) {
      HapticFeedback.mediumImpact();
      _doVirtualKeyInput(item.key!);
    }
    final inputRaw = item.inputRaw;
    if (inputRaw != null) {
      HapticFeedback.mediumImpact();
      _terminal.textInput(inputRaw);
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
        _termKey.currentState?.toggleFocus();
        break;
      case VirtualKeyFunc.backspace:
        _terminal.keyInput(TerminalKey.backspace);
        break;
      case VirtualKeyFunc.clipboard:
        final selected = terminalSelected;
        if (selected != null) {
          Pfs.copy(selected);
        } else {
          _paste();
        }
        break;
      case VirtualKeyFunc.snippet:
        final snippets = await context.showPickWithTagDialog<Snippet>(
          title: l10n.snippet,
          tags: SnippetProvider.tags,
          itemsBuilder: (e) {
            if (e == TagSwitcher.kDefaultTag) {
              return SnippetProvider.snippets.value;
            }
            return SnippetProvider.snippets.value
                .where((element) => element.tags?.contains(e) ?? false)
                .toList();
          },
          display: (e) => e.name,
        );
        if (snippets == null || snippets.isEmpty) return;

        final snippet = snippets.firstOrNull;
        if (snippet == null) return;
        snippet.runInTerm(_terminal, widget.spi);
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
        final initPath = cmds.elementAtOrNull(idx + 1)?.toString();
        if (initPath == null || !initPath.startsWith('/')) {
          context.showRoundDialog(
            title: libL10n.error,
            child: Text('${l10n.remotePath}: $initPath'),
          );
          return;
        }
        AppRoutes.sftp(spi: widget.spi, initPath: initPath).go(context);
    }
  }

  void _paste() {
    Clipboard.getData(Clipboard.kTextPlain).then((value) {
      final text = value?.text;
      if (text != null) {
        _terminal.textInput(text);
      } else {
        context.showRoundDialog(
          title: libL10n.error,
          child: Text(libL10n.empty),
        );
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

  void _initVirtKeys() {
    final virtKeys = VirtKeyX.loadFromStore();
    for (int len = 0; len < virtKeys.length; len += 7) {
      if (len + 7 > virtKeys.length) {
        _virtKeysList.add(virtKeys.sublist(len));
      } else {
        _virtKeysList.add(virtKeys.sublist(len, len + 7));
      }
    }
  }

  FutureOr<List<String>?> _onKeyboardInteractive(SSHUserInfoRequest req) {
    return KeybordInteractive.defaultHandle(widget.spi, ctx: context);
  }
}
