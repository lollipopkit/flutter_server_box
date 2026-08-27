import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/provider/ai/agent_scope.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/app/terminal_shell.dart';
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
import 'package:server_box/view/page/agent/history.dart';
import 'package:server_box/view/page/ssh/ask_ai_layout.dart';
import 'package:server_box/view/page/ssh/page/virt_key_intro.dart';
import 'package:server_box/view/page/storage/server_file.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/widget/agent_common.dart';
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

/// How tall one row of virtual keys is.
const _kVirtKeyRowHeight = 37.0;

/// And the dots under them, when there is more than one page of rows.
const _kVirtKeyDotsHeight = 9.0;

class SSHPageState extends ConsumerState<SSHPage>
    with
        AutomaticKeepAliveClientMixin,
        AfterLayoutMixin,
        WidgetsBindingObserver {
  /// The tmux session this page attached to, kept for the reconnect that
  /// rebuilds the launch plan and reads it again.
  ///
  /// Plain fields. They were `Restorable*`, which in this app is the same
  /// thing with extra ceremony: `restoreState` runs, registration succeeds,
  /// and a relaunch has nothing, because the route `MaterialApp.home` builds
  /// hands its subtree no bucket — `test/restoration_bucket_test.dart`. What
  /// they did in practice was hold this within one page across a reconnect,
  /// which is what these still do.
  ///
  /// What survives a relaunch is the tab's own record, in
  /// `Stores.history.sshTabs`. A third field held the server id and was only
  /// ever written.
  String? _tmuxSessionState;
  int? _tmuxWindowState;

  /// The terminal and the shell behind it. Handed in when this page is
  /// continuing a session that started elsewhere, and made here otherwise.
  late final TerminalSession _sess =
      widget.args.session ?? TerminalSession(source: widget.args.source);

  /// Whether the session arrived already running, and so must not be started
  /// a second time.
  bool get _adopted => widget.args.session != null;

  /// The terminal and the shell behind it, for whoever is showing them.
  ///
  /// The floating window is the only caller: it draws this session while this
  /// page stands its own view down — see [terminalShellProvider].
  TerminalSession get session => _sess;

  /// Held from `initState` rather than read where it is used, because
  /// [dispose] is one of the places that uses it and `ref` is not usable by
  /// then.
  late final TerminalShell _terminalShell;

  Terminal get _terminal => _sess.terminal;

  late final TerminalController _terminalController = TerminalController();
  final List<List<VirtKey>> _virtKeysList = [];
  late final _termKey =
      widget.args.terminalKey ?? GlobalKey<TerminalViewState>();

  late MediaQueryData _media;
  late TerminalStyle _terminalStyle;
  late TerminalTheme _terminalTheme;
  double _virtKeysHeight = 0;

  /// How many rows of keys to show at once, 0 for all of them. The rest go on
  /// pages of their own — see [_virtKeyPages].
  int _virtKeyRows = 0;

  /// Which of those pages is showing, for the dots under them.
  ///
  /// A notifier rather than state: the page changes on every swipe, and the
  /// terminal above has no reason to rebuild when it does.
  final _virtKeyPage = ValueNotifier(0);

  /// Which step of the virtual keys walkthrough is showing, or null when it is
  /// not running — which is every time but the first.
  int? _introStep;

  /// Built once when the walkthrough starts rather than on every frame, so the
  /// step being shown cannot change out from under the dots counting it.
  List<VirtKeyIntroStep>? _introSteps;

  /// Held only while waiting for this page to become the visible tab, so it
  /// can be taken off again if the tab is closed first.
  VoidCallback? _introVisibilityListener;

  /// Moves the walkthrough, or ends it with a null [step].
  ///
  /// Here rather than in the [_VirtKey] extension the rest of it lives in:
  /// `setState` is protected and an extension is not a subclass, so this is
  /// the one line of it that has to be on the class.
  void setIntroStep(int? step, {List<VirtKeyIntroStep>? steps}) {
    if (!mounted) return;
    setState(() {
      _introStep = step;
      if (step == null) {
        _introSteps = null;
      } else if (steps != null) {
        _introSteps = steps;
      }
      // Starting and ending it both change how many rows are on screen — see
      // [_virtKeyPages] — and the strip is as tall as what it shows.
      _updateVirtKeysHeight();
    });
  }

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

  /// Takes this terminal out of reach of its Agent session, run on dispose.
  ///
  /// A closure rather than a call in `dispose`, because unregistering needs the
  /// notifier and `ref` is not usable once the state is going away. Captured
  /// while it still is — see [_attachAgentHost].
  VoidCallback? _releaseAgentHost;
  Timer? _discontinuityTimer;
  static const _connectionCheckInterval = Duration(seconds: 60);
  static const _connectionCheckTimeout = Duration(seconds: 10);
  static const _maxKeepAliveFailures = 3;

  /// Between the tries of one check that cannot wait for the next interval —
  /// see `_checkConnectionHealth`. Short enough that a genuinely dead session
  /// is still reported within a few seconds of coming back.
  static const _connectionCheckRetryDelay = Duration(seconds: 2);
  int _missedKeepAliveCount = 0;
  bool _isCheckingConnection = false;
  bool _hasPendingImmediateCheck = false;
  bool _reconnectCancelled = false;

  /// The navigator holding the reconnecting dialog, while it is on screen.
  ///
  /// The navigator rather than a bool, because this page's own context is not
  /// enough to close that dialog: it lives on the *root* navigator and so
  /// outlives the page, and `contextSafe` is null the moment the page is gone.
  /// A `NavigatorState` captured while showing it still answers.
  ///
  /// Nulled by whoever closes it — the cancel button, the reconnect finishing,
  /// or [dispose] — so the other two do nothing. A second pop on a dialog that
  /// is already gone takes the route under it instead, which here is the app.
  NavigatorState? _reconnectDialogNav;
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

  /// Used to activate the wake lock while at least one terminal page exists.
  static var _sshConnCount = 0;
  late final String _sessionId = ShortId.generate();
  late final int _sessionStartMs = DateTime.now().millisecondsSinceEpoch;

  Future<void> pickSnippetFromToolbar() => _pickSnippet();

  Future<void> openAgentFromToolbar() =>
      _showAskAiPanel(autoStart: false);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The floating window is a view onto this page's session, and once
    // `_sess.dispose()` below has taken its output subscriptions away it is a
    // terminal that has silently stopped answering. So it goes with the page.
    //
    // Scheduled rather than called: `dispose` runs inside the frame that is
    // unmounting this page, and Riverpod refuses a write from there — it
    // throws, which is a page that cannot be closed at all. By the end of this
    // frame the tree is settled and the write is ordinary; the window has
    // already been drawn once this frame and goes on the next.
    final shell = _terminalShell;
    final session = _sess;
    WidgetsBinding.instance.addPostFrameCallback((_) => shell.hideIf(session));
    _releaseAgentHost?.call();
    _virtKeyLongPressTimer?.cancel();
    final introListener = _introVisibilityListener;
    if (introListener != null) {
      widget.args.visibleListenable?.removeListener(introListener);
    }
    final aiCommandSession = _aiCommandSession;
    if (aiCommandSession != null) {
      unawaited(_terminateAiCommandSession(aiCommandSession));
    }
    _terminalController.dispose();
    _virtKeyPage.dispose();
    _discontinuityTimer?.cancel();
    // The reconnect's own `finally` normally does this, but it only runs when
    // the reconnect returns — and the thing it is waiting on is a connection
    // to a host that is not answering. A dialog left on the root navigator by
    // a page that no longer exists is one nothing else can close.
    _reconnectCancelled = true;
    _dismissReconnectingDialog(deferred: true);
    // Not `close`: the connection may be the status poller's, shared with the
    // rest of the app, and a terminal going away is not a reason to hang it up.
    _sess.dispose();
    _removeVisibilityListener();
    Stores.setting.virtKeyRows.listenable().removeListener(
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
    }

    // Remove session entry
    TermSessionManager.remove(_sessionId);

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _terminalShell = ref.read(terminalShellProvider.notifier);
    _attachAgentHost();
    _initStoredCfg();
    _reloadVirtKeys();
    Stores.setting.virtKeyRows.listenable().addListener(
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
        // Next frame, not this one: the tab the user came back to is decided
        // by the state this frame is built from.
        WidgetsBinding.instance.addPostFrameCallback((_) => _focusTerminal());
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

    // Popped out into the floating window, which is then the only view on this
    // terminal. Two `TerminalView`s on one `Terminal` both resize it as they
    // lay out, each undoing the other's size on the next frame and sending the
    // far side a `SIGWINCH` for every one — so this one stands down rather
    // than drawing a second copy nobody is looking at.
    final floating = ref.watch(
      terminalShellProvider.select(
        (shell) => identical(shell?.session, _sess),
      ),
    );
    if (floating) return _buildFloatedAway();

    final bgImage = Stores.setting.sshBgImage.fetch();
    final bgFile = bgImage.isEmpty ? null : File(bgImage);
    final hasBg = bgFile != null && bgFile.existsSync();

    Widget child = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleEscKeyOrBackButton();
      },
      child: Scaffold(
        // One background for the whole page. Transparent over a picture, and
        // otherwise the `Scaffold`'s own colour — which is what the terminal
        // is drawn on either way, since [TerminalView] is given
        // `backgroundOpacity: 0` and paints none of its own.
        backgroundColor: hasBg ? Colors.transparent : null,
        appBar: widget.args.notFromTab
            ? CustomAppBar(
                leading: BackButton(onPressed: context.pop),
                title: Text(widget.args.source.label),
                centerTitle: false,
                actions: _buildAppBarActions(),
              )
            : null,
        body: _buildBody(hasBg),
        bottomNavigationBar: isDesktop ? null : _buildBottom(),
      ),
    );

    // Behind the `Scaffold` and not inside the body: the virtual keys are a bar
    // under it, and a picture that stops where the terminal does leaves them on
    // a colour of their own.
    if (hasBg) {
      child = Stack(
        fit: StackFit.expand,
        children: [..._buildBackground(bgFile), child],
      );
    }

    if (isIOS) {
      child = AnnotatedRegion(
        value: _isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: child,
      );
    }
    return child;
  }

  /// What the tab shows while the terminal is in the floating window.
  ///
  /// Not left blank: this tab is still open, still named after the server, and
  /// still where the terminal goes back to. Somewhere saying so is the
  /// difference between a terminal that moved and one that broke.
  Widget _buildFloatedAway() {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // Nothing floats a terminal opened as a route — the button is on the tab
      // strip — so this branch is not reached today. Kept because the cost of
      // being wrong about that is a page with no way off it.
      appBar: widget.args.notFromTab
          ? CustomAppBar(
              leading: BackButton(onPressed: context.pop),
              title: Text(widget.args.source.label),
              centerTitle: false,
            )
          : null,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_in_picture_alt,
              size: 56,
              color: scheme.outlineVariant,
            ),
            const SizedBox(height: 13),
            Text(l10n.termInFloatWindow, style: UIs.textGrey),
            const SizedBox(height: 7),
            TextButton.icon(
              onPressed: _terminalShell.hide,
              icon: const Icon(Icons.open_in_full, size: 18),
              label: Text(l10n.floatReturnToTab),
            ),
          ],
        ),
      ),
    );
  }

  /// The picture the page is drawn on, bottom layer first.
  ///
  /// Only called when there is one — see [build], which is also where it is
  /// put in the tree.
  List<Widget> _buildBackground(File file) {
    final opacity = Stores.setting.sshBgOpacity.fetch();
    final blur = Stores.setting.sshBlurRadius.fetch();
    return [
      Positioned.fill(
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(),
        ),
      ),
      if (blur > 0)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: const SizedBox(),
          ),
        ),
      Positioned.fill(
        child: ColoredBox(
          color: _terminalTheme.background.withValues(alpha: opacity),
        ),
      ),
    ];
  }

  Widget _buildBody(bool hasBg) {
    final letterCache = Stores.setting.letterCache.fetch();
    final theme = hasBg
        ? _terminalTheme.copyWith(background: Colors.transparent)
        : _terminalTheme;
    final terminal = SizedBox(
      height: double.infinity,
      child: Padding(
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

    final step = _introStep;
    final steps = _introSteps;
    if (step == null || steps == null || step >= steps.length) return terminal;
    // Over the terminal and no further: the keys the walkthrough is pointing
    // at are the `Scaffold`'s bottom bar, outside this body, and so stay lit
    // while everything it says to look at is dimmed.
    return Stack(
      children: [
        terminal,
        Positioned.fill(
          child: GuideView(
            steps: [for (final step in steps) step.guide],
            step: step,
            onStep: setIntroStep,
            onDone: _endVirtKeyIntro,
          ),
        ),
      ],
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
        // No colour of its own: the keys are part of the page and sit on
        // whatever it is drawn on. Painting the terminal theme's background
        // here put a strip of another colour under the terminal, which is not
        // drawn on that colour at all.
        //
        // Lit but not live while the walkthrough runs: it is describing these,
        // and a tap meant as "let me look at that one" would arm a modifier or
        // open SFTP over the top of it.
        child: IgnorePointer(
          ignoring: _introStep != null,
          child: SizedBox(
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
          tooltip: 'SSH Agent',
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
        Toast.show(libL10n.empty);
        return;
      }

      // By tag, which is what the virtual key used to offer and this did not.
      // There is one picker now: the key called a copy of this that bailed
      // without a word whenever there was no server, so the snippet key did
      // nothing at all on a shell on this device.
      final tags = ref.read(snippetProvider.select((p) => p.tags));
      final picked = await context.showPickWithTagDialog<Snippet>(
        title: libL10n.snippet,
        tags: tags.vn,
        itemsBuilder: (tag) {
          if (tag == TagSwitcher.kDefaultTag) return snippets;
          return snippets
              .where((e) => e.tags?.contains(tag) ?? false)
              .toList();
        },
        display: (snippet) => snippet.name,
      );
      final selected = picked?.firstOrNull;
      if (selected == null) return;

      try {
        await selected.runInTerm(_terminal, spi);
      } catch (e, s) {
        if (!mounted) return;
        context.showErrDialog(e, s, '${libL10n.snippet}: ${selected.name}');
        return;
      }
      if (!mounted) return;
      _focusTerminal();
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
    final pages = _virtKeyPages;

    return LayoutBuilder(
      builder: (_, cons) {
        final virtKeyWidth = cons.maxWidth / count;

        Widget pageOf(List<List<VirtKey>> rows) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              Row(
                children: [
                  for (final key in row)
                    _buildVirtKeyItem(
                      key,
                      virtKeyWidth,
                      virtKeyState,
                      virtKeyNotifier,
                    ),
                ],
              ),
          ],
        );

        if (pages.length == 1) return pageOf(pages.first);

        return Column(
          children: [
            Expanded(
              child: PageView(
                // Keyed by how many pages there are, so a page count that
                // shrinks — a key turned off in the settings — starts a fresh
                // view rather than leaving the old one scrolled past its end.
                key: ValueKey(pages.length),
                onPageChanged: (page) => _virtKeyPage.value = page,
                children: [for (final page in pages) pageOf(page)],
              ),
            ),
            _buildVirtKeyDots(pages.length),
          ],
        );
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

    // While the walkthrough is on a step, only the keys it is about stay lit.
    // The row itself is never dimmed — it is the thing being pointed at.
    final group = _introGroup;
    final lit = group == null || item.group == group;

    return InkWell(
      onTap: () => _doVirtualKey(item, virtKeyNotifier),
      // Held rather than tapped, and only where there is something to say —
      // null otherwise, so a key with no help does not answer a hold with a
      // splash and nothing else. The arrows are out either way: a hold there
      // repeats the key, and their label is already the whole answer.
      onLongPress: item.canLongPress || item.help == null
          ? null
          : () => _showVirtKeyHelp(item),
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
      child: AnimatedOpacity(
        opacity: lit ? 1 : 0.25,
        duration: Durations.medium1,
        curve: Curves.easeOut,
        child: SizedBox(
          width: virtKeyWidth,
          height: _kVirtKeyRowHeight,
          child: Center(child: child),
        ),
      ),
    );
  }

  /// How far through the pages of keys, when there is more than one.
  ///
  /// A row of keys says nothing about there being another row behind it, and
  /// the strip is too short to spend on anything wordier than this.
  Widget _buildVirtKeyDots(int count) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _kVirtKeyDotsHeight,
      child: ValueListenableBuilder(
        valueListenable: _virtKeyPage,
        builder: (_, current, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: Durations.short3,
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: i == current ? 13 : 5,
                height: 3,
                decoration: BoxDecoration(
                  color: i == current
                      ? scheme.primary
                      : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
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
    // `paste`, not `textInput`: it brackets the text when the program asked for
    // that (DECSET 2004), which is what stops an editor auto-indenting every
    // line of it and a shell running the newlines as commands.
    _terminal.paste(text);
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

  /// Whether this is the terminal the user is looking at right now.
  ///
  /// Two questions for a session in a tab, not one. `visibleListenable`
  /// answers which of the terminal tabs is selected, and says nothing about
  /// whether the terminal page is the one the home page is showing — so a
  /// shell left open in it went on answering yes from the servers tab, and
  /// coming back from the background raised the keyboard over whatever the
  /// user was actually reading.
  bool get _isVisibleSessionPage {
    if (widget.args.notFromTab) {
      final route = ModalRoute.of(context);
      return route?.isCurrent ?? true;
    }
    if (widget.args.visibleListenable?.value != true) return false;
    return ref.read(currentHomeTabProvider) == AppTab.ssh;
  }

  /// Puts the cursor back in this terminal, and on a phone raises the keyboard
  /// with it — the terminal's input connection is opened by the focus, so a
  /// bare `requestFocus` shows it just as surely as asking for it does.
  ///
  /// Which is why nothing focuses the terminal directly. A reconnect, a tmux
  /// switch and a snippet all end by restoring focus, and every one of them
  /// can finish while the user is on another tab or in another shell; the
  /// keyboard then came up over whatever they were reading.
  void _focusTerminal({bool keyboard = true}) {
    if (!mounted || !_isVisibleSessionPage) return;
    widget.args.focusNode?.requestFocus();
    if (keyboard) _termKey.currentState?.requestKeyboard();
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
      if (_isVisibleSessionPage) {
        TermSessionManager.setActive(_sessionId, hasTerminal: true);
        unawaited(_checkConnectionHealth(immediate: true));
      } else {
        TermSessionManager.hideTerminal(_sessionId);
      }
    }

    _visibilityListener = listener;
    visibleListenable.addListener(listener);
    // The other half of the same question. Leaving the terminal page takes
    // this shell off screen exactly as selecting another tab within it does,
    // and nothing was telling the session manager so — which left the Live
    // Activity offering a terminal that was two taps away.
    //
    // A `listenManual` subscription from a `ConsumerState` is closed with the
    // widget, so it needs no counterpart in [dispose].
    ref.listenManual(currentHomeTabProvider, (_, _) => listener());
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
    Toast.success(libL10n.success);
  }

  Future<void> _insertSudoPassword() async {
    final spi = widget.args.spi;
    if (spi == null) return;

    final authed = await SudoPassword.authenticateIfNeeded();
    if (!authed) {
      if (!mounted) return;
      Toast.error(libL10n.fail);
      return;
    }

    final password = await SudoPassword.resolveForTerminal(spi);
    if (password == null || password.isEmpty) {
      if (!mounted) return;
      Toast.show(libL10n.empty);
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
      Toast.show(l10n.sudoPromptNotFound);
      return;
    }

    _terminal.textInput(password);
    _terminal.keyInput(TerminalKey.enter);
    _sess.clearOutputTail();

    if (!mounted) return;
    _focusTerminal();
    Toast.success(libL10n.success);
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

  /// The rows of keys, split into what is shown at once.
  ///
  /// One page holding everything when [_virtKeyRows] is 0 or covers the lot,
  /// which is the default and what a short set of keys gets whatever the
  /// setting says. Splitting on whole rows rather than on keys is the point of
  /// the paging: a sideways scroll used to leave the row halfway between two
  /// keys, and nothing said how much further it went.
  List<List<List<VirtKey>>> get _virtKeyPages {
    // Every row while the walkthrough runs. It is about these keys, and a step
    // naming a kind of them cannot point at one that is on a page behind this.
    final perPage = _introStep == null ? _virtKeyRows : 0;
    if (perPage <= 0 || perPage >= _virtKeysList.length) {
      return [_virtKeysList];
    }
    return [
      for (var at = 0; at < _virtKeysList.length; at += perPage)
        _virtKeysList.sublist(
          at,
          math.min(at + perPage, _virtKeysList.length),
        ),
    ];
  }

  void _updateVirtKeysHeight() {
    if (!isMobile || _virtKeysList.isEmpty) {
      _virtKeysHeight = 0;
      return;
    }
    final pages = _virtKeyPages;
    // As tall as the tallest page, which is the first: only the last can be
    // short, and a strip that changed height as it was swiped would move the
    // terminal above it.
    _virtKeysHeight =
        _kVirtKeyRowHeight * pages.first.length +
        (pages.length > 1 ? _kVirtKeyDotsHeight : 0);
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    await _showHelp();
    // After the dialog, and after nothing else: it points at the key row, so
    // it has to be the only thing on screen when it runs.
    _startVirtKeyIntroWhenVisible();
    await _initTerminal();

    if (Stores.setting.sshWakeLock.fetch()) WakelockPlus.enable();

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }
}
