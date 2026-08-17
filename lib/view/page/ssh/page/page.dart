import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/agent_conversation_replay.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/provider/virtual_keyboard.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/session_manager.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/ssh/tmux/tmux_export.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/view/page/ssh/ask_ai_layout.dart';
import 'package:server_box/view/page/ssh/page/clipboard_chord.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/widget/tmux_session_selector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart' hide TerminalThemes;

part 'agent_history.dart';
part 'ask_ai.dart';
part 'init.dart';
part 'keyboard.dart';
part 'virt_key.dart';

final class SshPageArgs {
  /// Where this terminal's shell comes from. A server, or this device — and
  /// what is only true of a server is reached through [spi], which is null for
  /// the other one.
  final TerminalSource source;

  /// The server behind [source], when there is one.
  Spi? get spi => switch (source) {
    ServerSource(:final spi) => spi,
    LocalSource() => null,
  };

  final String? initCmd;
  final Snippet? initSnippet;

  /// A shell that is already running, to be shown here instead of opening one.
  ///
  /// How a snippet started in a dialog carries on in a tab: the connection and
  /// everything printed into it are the session's, not the page's, so the page
  /// showing them can change without the shell noticing.
  final TerminalSession? session;
  final bool notFromTab;
  final Function()? onSessionEnd;
  final GlobalKey<TerminalViewState>? terminalKey;
  final FocusNode? focusNode;
  final ValueListenable<bool>? visibleListenable;
  final String? tmuxSession;
  final int? tmuxWindow;
  final VoidCallback? onTmuxStateChanged;

  /// Distinguishes this page's saved state from another page's.
  ///
  /// Defaults to the server's id, which is only unique while one shell per
  /// server is open. A host that can open several — the SSH tab — passes
  /// something per session instead.
  final String? restorationId;

  const SshPageArgs({
    required this.source,
    this.initCmd,
    this.initSnippet,
    this.session,
    this.notFromTab = true,
    this.onSessionEnd,
    this.terminalKey,
    this.focusNode,
    this.visibleListenable,
    this.tmuxSession,
    this.tmuxWindow,
    this.onTmuxStateChanged,
    this.restorationId,
  }) : assert(
         notFromTab || visibleListenable != null,
         'visibleListenable is required when notFromTab is false',
       );
}

class SSHPage extends ConsumerStatefulWidget {
  final SshPageArgs args;

  const SSHPage({super.key, required this.args});

  @override
  ConsumerState<SSHPage> createState() => SSHPageState();

  static const route = AppRouteArg<void, SshPageArgs>(
    page: SSHPage.new,
    path: '/ssh/page',
  );
}

const _horizonPadding = 7.0;

class SSHPageState extends ConsumerState<SSHPage>
    with
        AutomaticKeepAliveClientMixin,
        AfterLayoutMixin,
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        RestorationMixin {
  // Restorable state for this SSH page
  final RestorableString _restorableServerId = RestorableString('');
  final RestorableStringN _restorableTmuxSession = RestorableStringN(null);
  final RestorableIntN _restorableTmuxWindow = RestorableIntN(null);

  /// Per tab, not per server: two shells on one server is ordinary, and both
  /// registering `ssh_page_<serverId>` had them claiming the same bucket —
  /// one tab's tmux state overwriting the other's.
  @override
  String get restorationId =>
      'ssh_page_${widget.args.restorationId ?? widget.args.source.id}';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorableServerId, 'server_id');
    registerForRestoration(_restorableTmuxSession, 'tmux_session');
    registerForRestoration(_restorableTmuxWindow, 'tmux_window');
  }

  /// The terminal and the shell behind it. Handed in when this page is
  /// continuing a session that started elsewhere, and made here otherwise.
  late final TerminalSession _sess =
      widget.args.session ?? TerminalSession(source: widget.args.source);

  /// Whether the session arrived already running, and so must not be started
  /// a second time.
  bool get _adopted => widget.args.session != null;

  Terminal get _terminal => _sess.terminal;

  late final TerminalController _terminalController = TerminalController(
    vsync: this,
  );
  final List<List<VirtKey>> _virtKeysList = [];
  late final _termKey =
      widget.args.terminalKey ?? GlobalKey<TerminalViewState>();

  late MediaQueryData _media;
  late TerminalStyle _terminalStyle;
  late TerminalTheme _terminalTheme;
  double _virtKeysHeight = 0;
  bool _horizonVirtKeys = false;

  bool _isDark = false;
  Timer? _virtKeyLongPressTimer;

  ShellBackend? get _backend => _sess.backend;

  SSHClient? get _client => _sess.client;

  ShellSession? get _session => _sess.foreground;

  /// The agent's own command channel, separate from the terminal's session.
  /// SSH-only: the agent runs commands with `exec`, which the monitor PTY
  /// cannot do — see [ShellBackend.supportsExec].
  SSHSession? _aiCommandSession;
  bool _aiCommandCancelled = false;
  Timer? _discontinuityTimer;
  static const _connectionCheckInterval = Duration(seconds: 60);
  static const _connectionCheckTimeout = Duration(seconds: 10);
  static const _maxKeepAliveFailures = 3;
  int _missedKeepAliveCount = 0;
  bool _isCheckingConnection = false;
  bool _hasPendingImmediateCheck = false;
  bool _reconnectCancelled = false;
  bool _disconnectDialogOpen = false;
  bool _reportedDisconnected = false;
  VoidCallback? _visibilityListener;
  bool _isPickingSnippet = false;
  String? _tmuxCurrentSession;
  int? _tmuxCurrentWindow;

  /// Current tmux session name (for state restoration)
  String? get tmuxCurrentSession => _tmuxCurrentSession;

  /// Current tmux window index (for state restoration)
  int? get tmuxCurrentWindow => _tmuxCurrentWindow;

  /// Used for (de)activate the wake lock and forground service
  static var _sshConnCount = 0;
  late final String _sessionId = ShortId.generate();
  late final int _sessionStartMs = DateTime.now().millisecondsSinceEpoch;

  Future<void> pickSnippetFromToolbar() => _pickSnippet();

  Future<void> openAgentFromToolbar() =>
      _showAskAiPanel(_recentTerminalContext, autoStart: false);

  @override
  void dispose() {
    _restorableServerId.dispose();
    _restorableTmuxSession.dispose();
    _restorableTmuxWindow.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _virtKeyLongPressTimer?.cancel();
    final aiCommandSession = _aiCommandSession;
    if (aiCommandSession != null) {
      unawaited(_terminateAiCommandSession(aiCommandSession));
    }
    _terminalController.dispose();
    _discontinuityTimer?.cancel();
    // Not `close`: the connection may be the status poller's, shared with the
    // rest of the app, and a terminal going away is not a reason to hang it up.
    _sess.dispose();
    _removeVisibilityListener();
    Stores.setting.horizonVirtKey.listenable().removeListener(
      _handleVirtKeySettingsChanged,
    );
    Stores.setting.sshVirtKeys.listenable().removeListener(
      _handleVirtKeySettingsChanged,
    );
    Stores.setting.sshVirtKeysDisabled.listenable().removeListener(
      _handleVirtKeySettingsChanged,
    );

    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);

    if (--_sshConnCount <= 0) {
      WakelockPlus.disable();
      if (isAndroid) {
        MethodChans.stopService();
      }
    }

    // Remove session entry
    TermSessionManager.remove(_sessionId);

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initStoredCfg();
    _reloadVirtKeys();
    Stores.setting.horizonVirtKey.listenable().addListener(
      _handleVirtKeySettingsChanged,
    );
    Stores.setting.sshVirtKeys.listenable().addListener(
      _handleVirtKeySettingsChanged,
    );
    Stores.setting.sshVirtKeysDisabled.listenable().addListener(
      _handleVirtKeySettingsChanged,
    );
    _bindVisibilityListener();
    _setupDiscontinuityTimer();

    // Adopt whatever the provider already has, so a server that is connected
    // for status does not connect a second time just to show a terminal. This
    // device has nothing to adopt, and nothing to ask a provider about.
    final serverId = widget.args.spi?.id;
    if (serverId == null) {
      _sess.adopt(null);
    } else {
      final serverState = ref.read(serverProvider(serverId));
      _sess.adopt(serverState.client, granted: serverState.remoteAccess);
    }
    _sess.onForegroundDone = _onForegroundSessionDone;

    if (++_sshConnCount == 1) {
      WakelockPlus.enable();
      if (isAndroid) {
        MethodChans.startService();
      }
    }

    // Add session entry (for Android notifications & iOS Live Activities)
    TermSessionManager.add(
      id: _sessionId,
      title: widget.args.source.label,
      subtitle: widget.args.spi?.oldId ?? '',
      startTimeMs: _sessionStartMs,
      disconnect: _disconnectFromNotification,
      status: TermSessionStatus.connecting,
      setAsActive: _shouldActivateSessionOnInit,
    );
    if (_shouldActivateSessionOnInit) {
      TermSessionManager.setActive(_sessionId, hasTerminal: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isVisibleSessionPage) return;
        TermSessionManager.setActive(_sessionId, hasTerminal: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_isVisibleSessionPage) return;
          widget.args.focusNode?.requestFocus();
          _termKey.currentState?.requestKeyboard();
        });
        unawaited(_checkConnectionHealth(immediate: true));
        if (_discontinuityTimer == null || !_discontinuityTimer!.isActive) {
          _setupDiscontinuityTimer();
        }
        break;
      case AppLifecycleState.paused:
        if (!_isVisibleSessionPage) return;
        TermSessionManager.setActive(_sessionId, hasTerminal: false);
        break;
      default:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = TerminalLook.isDark(context);
    _media = context.mediaQuery;

    _terminalTheme = TerminalLook.themeOf(context);

    // Because the virtual keyboard only displayed on mobile devices
    _updateVirtKeysHeight();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                title: Text(widget.args.source.label),
                centerTitle: false,
                actions: _buildAppBarActions(),
              )
            : null,
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
    final theme = hasBg
        ? _terminalTheme.copyWith(background: Colors.transparent)
        : _terminalTheme;
    final children = <Widget>[];
    if (hasBg) {
      children.add(
        Positioned.fill(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(),
          ),
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
          child: ColoredBox(
            color: _terminalTheme.background.withValues(alpha: opacity),
          ),
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
          // The convention every terminal on every platform keeps: copy what
          // is selected, and paste when nothing is. `_onClipboardAction` is
          // the whole of it, and this is now its only caller — the toolbar
          // button it was first written for is gone.
          onSecondaryTapUp: (_, _) => _onClipboardAction(),
          enableSuggestions: letterCache,
          textStyle: _terminalStyle,
          backgroundOpacity: 0,
          theme: theme,
          deleteDetection: isMobile,
          autofocus: false,
          keyboardAppearance: _isDark ? Brightness.dark : Brightness.light,
          showToolbar: true,
          viewOffset: Offset(
            2 * _horizonPadding,
            CustomAppBar.sysStatusBarHeight,
          ),
          hideScrollBar: false,
          focusNode: widget.args.focusNode,
          toolbarBuilder: _buildTerminalToolbar,
          onCopied: _onTerminalCopied,
          onSelectAll: _onTerminalSelectAll,
          onPaste: _onTerminalPaste,
        ),
      ),
    );

    return SizedBox(
      height: double.infinity,
      child: Stack(children: children),
    );
  }

  Widget _buildBottom() {
    if (_virtKeysHeight == 0) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        padding: _media.viewInsets,
        duration: const Duration(milliseconds: 23),
        curve: Curves.fastOutSlowIn,
        child: Container(
          color: _terminalTheme.background,
          height: _virtKeysHeight,
          child: Consumer(
            builder: (context, ref, child) {
              final virtKeyState = ref.watch(virtKeyboardProvider);
              final virtKeyNotifier = ref.read(virtKeyboardProvider.notifier);

              // Set the terminal input handler
              _terminal.inputHandler = virtKeyNotifier;

              return _buildVirtualKey(virtKeyState, virtKeyNotifier);
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[
      // The agent's tools all name a server, so on this device the button
      // would look tappable and do nothing. Snippets are different: the ones
      // that do not mention a server run here fine — see [_pickSnippet].
      if (widget.args.spi != null)
        IconButton(
          onPressed: openAgentFromToolbar,
          tooltip: l10n.askAiAgentTitle,
          icon: const Icon(Icons.auto_awesome),
        ),
      IconButton(
        onPressed: _pickSnippet,
        tooltip: libL10n.snippet,
        icon: const Icon(Icons.code),
      ),
    ];
    // Only where there is a sudo password to insert. This device's shell is
    // already whoever is running the app.
    if (widget.args.spi case final spi? when !spi.isRoot) {
      actions.add(
        IconButton(
          onPressed: _insertSudoPassword,
          tooltip: l10n.trySudo,
          icon: const Icon(Icons.password),
        ),
      );
    }
    return actions;
  }

  Future<void> _pickSnippet() async {
    if (_isPickingSnippet) return;
    _isPickingSnippet = true;

    try {
      final spi = widget.args.spi;
      // On this device, only the ones that do not name a server. A script
      // saying `${host}` has no answer here, and substituting an empty string
      // would quietly run a different command rather than refuse.
      final snippets = ref
          .read(snippetProvider.select((p) => p.snippets))
          .where((e) => spi != null || !e.needsServer)
          .toList();
      if (snippets.isEmpty) {
        if (!mounted) return;
        context.showSnackBar(libL10n.empty);
        return;
      }

      final selected = await context.showPickSingleDialog<Snippet>(
        title: libL10n.snippet,
        items: snippets,
        display: (snippet) => snippet.name,
      );
      if (selected == null) return;

      try {
        await selected.runInTerm(_terminal, spi);
      } catch (e, s) {
        if (!mounted) return;
        context.showErrDialog(e, s, '${libL10n.snippet}: ${selected.name}');
        return;
      }
      if (!mounted) return;
      widget.args.focusNode?.requestFocus();
      _termKey.currentState?.requestKeyboard();
    } finally {
      _isPickingSnippet = false;
    }
  }

  Widget _buildVirtualKey(
    VirtKeyState virtKeyState,
    VirtKeyboard virtKeyNotifier,
  ) {
    final count = _virtKeysList.firstOrNull?.length ?? 0;
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
                  .map(
                    (e) => _buildVirtKeyItem(
                      e,
                      virtKeyWidth,
                      virtKeyState,
                      virtKeyNotifier,
                    ),
                  )
                  .toList(),
            ),
          );
        }
        final rows = _virtKeysList
            .map(
              (e) => Row(
                children: e
                    .map(
                      (e) => _buildVirtKeyItem(
                        e,
                        virtKeyWidth,
                        virtKeyState,
                        virtKeyNotifier,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }

  Widget _buildVirtKeyItem(
    VirtKey item,
    double virtKeyWidth,
    VirtKeyState virtKeyState,
    VirtKeyboard virtKeyNotifier,
  ) {
    var selected = false;
    switch (item.key) {
      case TerminalKey.control:
        selected = virtKeyState.ctrl;
        break;
      case TerminalKey.alt:
        selected = virtKeyState.alt;
        break;
      case TerminalKey.shift:
        selected = virtKeyState.shift;
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
      onTap: () => _doVirtualKey(item, virtKeyNotifier),
      onTapDown: (details) {
        if (item.canLongPress) {
          _virtKeyLongPressTimer = Timer.periodic(
            const Duration(milliseconds: 137),
            (_) => _doVirtualKey(item, virtKeyNotifier),
          );
        }
      },
      onTapCancel: () => _virtKeyLongPressTimer?.cancel(),
      onTapUp: (_) => _virtKeyLongPressTimer?.cancel(),
      child: SizedBox(
        width: virtKeyWidth,
        height: _horizonVirtKeys
            ? _virtKeysHeight
            : _virtKeysHeight / _virtKeysList.length,
        child: Center(child: child),
      ),
    );
  }

  void _onTerminalCopied() {
    _showClipboardSuccess();
    _terminalController.clearSelection();
  }

  void _onTerminalSelectAll() {
    if (!mounted) return;
    _termKey.currentState?.renderTerminal.selectAll();
  }

  Future<void> _onTerminalPaste() async {
    final value = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = value?.text;
    if (text == null) return;
    _terminal.textInput(text);
    _terminalController.clearSelection();
  }

  Future<void> _onClipboardAction() async {
    if (_terminalController.selection != null) {
      final selectedText = _termKey.currentState?.renderTerminal.selectedText;
      if (selectedText != null && selectedText.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: selectedText));
        _showClipboardSuccess();
        _terminalController.clearSelection();
        return;
      }
      return;
    }
    await _onTerminalPaste();
  }

  @override
  bool get wantKeepAlive => true;

  bool get _shouldActivateSessionOnInit {
    if (widget.args.notFromTab) return true;
    return widget.args.visibleListenable?.value ?? false;
  }

  bool get _isVisibleSessionPage {
    if (widget.args.notFromTab) {
      final route = ModalRoute.of(context);
      return route?.isCurrent ?? true;
    }
    return widget.args.visibleListenable?.value ?? false;
  }

  void _bindVisibilityListener() {
    final visibleListenable = widget.args.visibleListenable;
    if (widget.args.notFromTab ||
        visibleListenable == null ||
        _visibilityListener != null) {
      return;
    }
    void listener() {
      if (!mounted) return;
      if (visibleListenable.value) {
        TermSessionManager.setActive(_sessionId, hasTerminal: true);
        unawaited(_checkConnectionHealth(immediate: true));
      } else {
        TermSessionManager.hideTerminal(_sessionId);
      }
    }

    _visibilityListener = listener;
    visibleListenable.addListener(listener);
  }

  void _removeVisibilityListener() {
    final visibleListenable = widget.args.visibleListenable;
    final listener = _visibilityListener;
    if (visibleListenable != null && listener != null) {
      visibleListenable.removeListener(listener);
    }
    _visibilityListener = null;
  }

  void _handleVirtKeySettingsChanged() {
    if (!mounted) return;
    setState(_reloadVirtKeys);
  }

  void _showClipboardSuccess() {
    if (!mounted) return;
    context.showSnackBar(libL10n.success);
  }

  Future<void> _insertSudoPassword() async {
    final spi = widget.args.spi;
    if (spi == null) return;

    final authed = await SudoPassword.authenticateIfNeeded();
    if (!authed) {
      if (!mounted) return;
      context.showSnackBar(libL10n.fail);
      return;
    }

    final password = await SudoPassword.resolveForTerminal(spi);
    if (password == null || password.isEmpty) {
      if (!mounted) return;
      context.showSnackBar(libL10n.empty);
      return;
    }

    bool detected = false;
    const delays = [0, 100, 200, 400, 800, 1600];
    for (int i = 0; i < delays.length; i++) {
      final delayMs = delays[i];
      if (delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
        if (!mounted) return;
      }

      _sess.drainOutput();

      if (_hasPendingSudoPrompt()) {
        detected = true;
        break;
      }
    }

    if (!detected) {
      if (!mounted) return;
      context.showSnackBar(l10n.sudoPromptNotFound);
      return;
    }

    _terminal.textInput(password);
    _terminal.keyInput(TerminalKey.enter);
    _sess.clearOutputTail();

    if (!mounted) return;
    widget.args.focusNode?.requestFocus();
    _termKey.currentState?.requestKeyboard();
    context.showSnackBar(libL10n.success);
  }

  bool _hasPendingSudoPrompt() {
    return _hasPendingSudoPromptInTerminalBuffer() ||
        _hasPendingSudoPromptInOutputTail();
  }

  bool _hasPendingSudoPromptInTerminalBuffer() {
    final raw = _terminal.buffer.currentLine.toString().trim();
    if (raw.isEmpty) return false;
    return SudoPassword.isPromptText(raw);
  }

  bool _hasPendingSudoPromptInOutputTail() {
    final raw = _latestSshOutputLine();
    if (raw.isEmpty) return false;
    return SudoPassword.isPromptText(raw);
  }

  String _latestSshOutputLine() {
    final normalized = SudoPassword.normalizeOutput(_sess.outputTail);
    return normalized
        .split('\n')
        .reversed
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  }

  void _updateVirtKeysHeight() {
    if (!isMobile) {
      _virtKeysHeight = 0;
      return;
    }
    if (_virtKeysList.isEmpty) {
      _virtKeysHeight = 0;
    } else if (_horizonVirtKeys) {
      _virtKeysHeight = 37;
    } else {
      _virtKeysHeight = 37.0 * _virtKeysList.length;
    }
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    await _showHelp();
    await _initTerminal();

    if (Stores.setting.sshWakeLock.fetch()) WakelockPlus.enable();

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }
}
