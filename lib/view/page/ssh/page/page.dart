import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:provider/provider.dart';

import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/provider/virtual_keyboard.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:server_box/view/page/storage/sftp.dart';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart' hide TerminalThemes;

part 'init.dart';
part 'keyboard.dart';
part 'virt_key.dart';

final class SshPageArgs {
  final Spi spi;
  final String? initCmd;
  final Snippet? initSnippet;
  final bool notFromTab;
  final Function()? onSessionEnd;
  final GlobalKey<TerminalViewState>? terminalKey;
  final FocusNode? focusNode;

  const SshPageArgs({
    required this.spi,
    this.initCmd,
    this.initSnippet,
    this.notFromTab = true,
    this.onSessionEnd,
    this.terminalKey,
    this.focusNode,
  });
}

class SSHPage extends StatefulWidget {
  final SshPageArgs args;

  const SSHPage({super.key, required this.args});

  @override
  State<SSHPage> createState() => SSHPageState();

  static const route = AppRouteArg<void, SshPageArgs>(page: SSHPage.new, path: '/ssh/page');
}

const _horizonPadding = 7.0;

class SSHPageState extends State<SSHPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin, TickerProviderStateMixin {
  final _keyboard = VirtKeyProvider();
  late final _terminal = Terminal(inputHandler: _keyboard);
  late final TerminalController _terminalController = TerminalController(vsync: this);
  final List<List<VirtKey>> _virtKeysList = [];
  late final _termKey = widget.args.terminalKey ?? GlobalKey<TerminalViewState>();

  late MediaQueryData _media;
  late TerminalStyle _terminalStyle;
  late TerminalTheme _terminalTheme;
  double _virtKeysHeight = 0;
  late final _horizonVirtKeys = Stores.setting.horizonVirtKey.fetch();

  bool _isDark = false;
  Timer? _virtKeyLongPressTimer;
  late SSHClient? _client = widget.args.spi.server?.value.client;
  Timer? _discontinuityTimer;

  /// Used for (de)activate the wake lock and forground service
  static var _sshConnCount = 0;

  @override
  void dispose() {
    _virtKeyLongPressTimer?.cancel();
    _terminalController.dispose();
    _discontinuityTimer?.cancel();

    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);

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
      if (_horizonVirtKeys) {
        _virtKeysHeight = 37;
      } else {
        _virtKeysHeight = 37.0 * _virtKeysList.length;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bgImage = Stores.setting.sshBgImage.fetch();
    final hasBg = bgImage.isNotEmpty;
    Widget child = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleEscKeyOrBackButton();
      },
      child: Scaffold(
        appBar: widget.args.notFromTab
            ? CustomAppBar(
                leading: BackButton(onPressed: context.pop),
                title: Text(widget.args.spi.name),
                actions: [_buildCopyBtn],
                centerTitle: false,
              )
            : null,
        backgroundColor: hasBg ? Colors.transparent : _terminalTheme.background,
        body: _buildBody(),
        bottomNavigationBar: isDesktop ? null : _buildBottom(),
      ),
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
    final bgImage = Stores.setting.sshBgImage.fetch();
    final opacity = Stores.setting.sshBgOpacity.fetch();
    final blur = Stores.setting.sshBlurRadius.fetch();
    final file = File(bgImage);
    final hasBg = bgImage.isNotEmpty && file.existsSync();
    final theme = hasBg ? _terminalTheme.copyWith(background: Colors.transparent) : _terminalTheme;
    final children = <Widget>[];
    if (hasBg) {
      children.add(
        Positioned.fill(
          child: Image.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
        ),
      );
      if (blur > 0) {
        children.add(
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: const SizedBox(),
            ),
          ),
        );
      }
      children.add(
        Positioned.fill(
          child: ColoredBox(color: _terminalTheme.background.withValues(alpha: opacity)),
        ),
      );
    }
    children.add(
      Padding(
        padding: EdgeInsets.only(left: _horizonPadding, right: _horizonPadding),
        child: TerminalView(
          _terminal,
          key: _termKey,
          controller: _terminalController,
          keyboardType: TextInputType.text,
          enableSuggestions: letterCache,
          textStyle: _terminalStyle,
          backgroundOpacity: 0,
          theme: theme,
          deleteDetection: isMobile,
          autofocus: false,
          keyboardAppearance: _isDark ? Brightness.dark : Brightness.light,
          showToolbar: isMobile,
          viewOffset: Offset(2 * _horizonPadding, CustomAppBar.sysStatusBarHeight),
          hideScrollBar: false,
          focusNode: widget.args.focusNode,
        ),
      ),
    );

    return SizedBox(
      height: _media.size.height - _virtKeysHeight - _media.padding.bottom - _media.padding.top,
      child: Stack(children: children),
    );
  }

  Widget _buildBottom() {
    return AnimatedPadding(
      padding: _media.viewInsets,
      duration: const Duration(milliseconds: 23),
      curve: Curves.fastOutSlowIn,
      child: Container(
        color: _terminalTheme.background,
        height: _virtKeysHeight + _media.padding.bottom,
        child: ChangeNotifierProvider(
          create: (_) => _keyboard,
          builder: (_, _) => Consumer<VirtKeyProvider>(
            builder: (_, _, _) {
              return _buildVirtualKey();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualKey() {
    final count = _horizonVirtKeys ? _virtKeysList.length : _virtKeysList.firstOrNull?.length ?? 0;
    if (count == 0) return UIs.placeholder;
    return LayoutBuilder(
      builder: (_, cons) {
        final virtKeyWidth = cons.maxWidth / count;
        if (_horizonVirtKeys) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _virtKeysList
                  .expand((e) => e)
                  .map((e) => _buildVirtKeyItem(e, virtKeyWidth))
                  .toList(),
            ),
          );
        }
        final rows = _virtKeysList
            .map((e) => Row(children: e.map((e) => _buildVirtKeyItem(e, virtKeyWidth)).toList()))
            .toList();
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }

  Widget _buildVirtKeyItem(VirtKey item, double virtKeyWidth) {
    var selected = false;
    switch (item.key) {
      case TerminalKey.control:
        selected = _keyboard.ctrl;
        break;
      case TerminalKey.alt:
        selected = _keyboard.alt;
        break;
      case TerminalKey.shift:
        selected = _keyboard.shift;
        break;
      default:
        break;
    }

    final child = item.icon != null
        ? Icon(item.icon, size: 17, color: _isDark ? Colors.white : Colors.black)
        : Text(
            item.text,
            style: TextStyle(
              color: selected ? UIs.primaryColor : (_isDark ? Colors.white : Colors.black),
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
        width: virtKeyWidth,
        height: _virtKeysHeight / _virtKeysList.length,
        child: Center(child: child),
      ),
    );
  }

  Widget get _buildCopyBtn {
    return IconButton(
      icon: Icon(MingCute.copy_2_fill),
      tooltip: libL10n.copy,
      onPressed: () {
        final selected = terminalSelected;
        if (selected == null || selected.isEmpty) {
          return;
        }
        Pfs.copy(selected);
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    await _showHelp();
    await _initTerminal();

    if (Stores.setting.sshWakeLock.fetch()) WakelockPlus.enable();

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }
}
