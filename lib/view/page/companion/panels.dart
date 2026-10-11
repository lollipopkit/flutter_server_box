import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/companion.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/app/terminal_lend.dart';
import 'package:server_box/data/provider/app/terminal_shell.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_cwd.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/src/rust/api/shell_cwd.dart';
import 'package:server_box/view/page/companion/host.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/text_scale.dart';
import 'package:server_box/view/page/ssh/float.dart';
import 'package:server_box/view/page/storage/file_browser.dart';
import 'package:server_box/view/page/storage/server_file.dart';
import 'package:server_box/view/page/storage/sftp.dart';

/// What the panels beside a server's own page are: a terminal on it, and its
/// files.
Widget serverCompanion(BuildContext context, CompanionPanel panel, Spi spi) =>
    switch (panel) {
      CompanionPanel.terminal => CompanionTerminal(spi: spi),
      CompanionPanel.files => CompanionFiles(spi: spi),
      // Not offered there: that page is the status.
      CompanionPanel.status => const SizedBox.shrink(),
    };

/// A server's readings, as its page shows them, in a panel.
class CompanionStatus extends StatelessWidget {
  const CompanionStatus({super.key, required this.spi});

  final Spi spi;

  @override
  Widget build(BuildContext context) {
    return CompanionFrame(
      actions: [
        BarAction(
          icon: Icons.open_in_full,
          label: l10n.openServerDetail,
          onTap: () =>
              ServerDetailPage.route.go(context, SpiRequiredArgs(spi)),
        ),
      ],
      // Bare: the panel is the frame, and the page's own bar and button row
      // would be a page inside it.
      body: ServerTextScale(
        child: ServerDetailPage(args: SpiRequiredArgs(spi), bare: true),
      ),
    );
  }
}

/// A server's files in a panel. Beside a terminal, they follow it.
class CompanionFiles extends StatefulWidget {
  const CompanionFiles({super.key, required this.spi, this.terminal});

  final Spi spi;

  /// The terminal this panel is beside, if any: followed into whatever
  /// directory its shell is in, and where a path from the list can be typed.
  final TerminalSession? terminal;

  @override
  State<CompanionFiles> createState() => _CompanionFilesState();
}

class _CompanionFilesState extends State<CompanionFiles> {
  /// The browser's own buttons, which it publishes rather than draws — the
  /// panel's header is where they go.
  final _actions = ValueNotifier<List<BarAction>>(const []);

  FileBrowserHandle? _browser;

  /// Where the terminal was last found to be, for a browser that is not up
  /// yet — it connects after the panel opens.
  String? _pending;

  /// Built once: rebuilding the page for every change to the header would
  /// tear down the connection under it.
  late final Widget _page = ServerFilePage(
    args: SftpPageArgs(
      spi: widget.spi,
      actionsSink: _actions,
      onHandle: _onBrowser,
      hostEntryActions: _entryActions,
    ),
  );

  bool get _following =>
      widget.terminal != null && Stores.setting.companionFollowCwd.fetch();

  @override
  void initState() {
    super.initState();
    _watch(widget.terminal);
  }

  @override
  void didUpdateWidget(CompanionFiles old) {
    super.didUpdateWidget(old);
    if (identical(old.terminal, widget.terminal)) return;
    _unwatch(old.terminal);
    _watch(widget.terminal);
  }

  @override
  void dispose() {
    _unwatch(widget.terminal);
    _actions.dispose();
    super.dispose();
  }

  void _watch(TerminalSession? terminal) {
    if (terminal == null) return;
    terminal.cwd.addListener(_onCwd);
    unawaited(_sync());
  }

  void _unwatch(TerminalSession? terminal) =>
      terminal?.cwd.removeListener(_onCwd);

  /// A shell that reports its directory is followed as it reports it.
  void _onCwd() {
    final cwd = widget.terminal?.cwd.value;
    if (cwd != null && _following) _goTo(cwd);
  }

  /// Asks where the terminal is, and goes there. One that does not report it
  /// is asked when the panel opens and whenever following is switched on,
  /// rather than polled.
  Future<void> _sync() async {
    final terminal = widget.terminal;
    if (terminal == null || !_following) return;
    final cwd = await TerminalCwd.of(terminal);
    if (!mounted || cwd == null || !identical(terminal, widget.terminal)) {
      return;
    }
    _goTo(cwd);
  }

  void _goTo(String path) {
    final browser = _browser;
    if (browser == null) {
      _pending = path;
      return;
    }
    if (browser.path == path) return;
    unawaited(browser.goTo(path));
  }

  void _onBrowser(FileBrowserHandle? browser) {
    _browser = browser;
    final pending = _pending;
    if (browser == null || pending == null) return;
    _pending = null;
    // Not now: the browser is handing itself over from its own `initState`.
    scheduleMicrotask(() {
      if (mounted && identical(_browser, browser)) _goTo(pending);
    });
  }

  void _toggleFollow() {
    final on = !Stores.setting.companionFollowCwd.fetch();
    Stores.setting.companionFollowCwd.put(on);
    setState(() {});
    if (on) unawaited(_sync());
  }

  List<ContextMenuAction> _entryActions(FileEntry entry, String fullPath) {
    final terminal = widget.terminal;
    if (terminal == null) return const [];
    return [
      ContextMenuAction(
        icon: Icons.input,
        text: l10n.insertPathToTerminal,
        // Pasted, not typed: a path is text for the command line, and a
        // bracketed paste is how a shell is told that.
        onTap: () => terminal.terminal.paste(shellWord(path: fullPath)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _actions,
      builder: (_, actions, _) => CompanionFrame(
        actions: [
          if (widget.terminal != null)
            BarAction(
              icon: Icons.link,
              label: l10n.followTerminalDir,
              color: _following ? Theme.of(context).colorScheme.primary : null,
              onTap: _toggleFollow,
            ),
          ...actions,
        ],
        body: _page,
      ),
    );
  }
}

/// A terminal on the server, in a panel.
///
/// The terminal tab's own, when it has one on this server: there is one shell,
/// shown here while this panel is on screen and in the tab otherwise — see
/// [LentTerminal]. Without one this panel starts a shell and hands it to the
/// terminal tab, so it is there too, and outlives the panel.
class CompanionTerminal extends ConsumerStatefulWidget {
  const CompanionTerminal({super.key, required this.spi});

  final Spi spi;

  @override
  ConsumerState<CompanionTerminal> createState() => _CompanionTerminalState();
}

class _CompanionTerminalState extends ConsumerState<CompanionTerminal> {
  /// The shell this panel started, until the terminal tab lists it as its own.
  TerminalSession? _started;

  /// What this panel has lent itself, so that only that is given back.
  TerminalSession? _lent;

  /// Starting is once per panel, by itself: after a shell has ended, another
  /// is started by asking.
  var _autoStarted = false;

  /// Whether [_started] has been queued for the terminal tab, which owns it
  /// from then on.
  var _handedOver = false;

  /// Whether [_started] failed to connect, which it says in the terminal;
  /// the header then offers to try again.
  var _failed = false;

  /// Read here rather than where it is used: [dispose] gives the terminal
  /// back, and `ref` is gone by then.
  late final LentTerminal _lend;

  @override
  void initState() {
    super.initState();
    _lend = ref.read(lentTerminalProvider.notifier);
  }

  @override
  void dispose() {
    if (!_handedOver) _started?.close();
    if (_lent != null) {
      // At the end of the frame, like `TerminalShell.hideIf`: the provider
      // must not change while the tree is being torn down.
      final lend = _lend;
      WidgetsBinding.instance.addPostFrameCallback((_) => lend.giveBack(this));
    }
    super.dispose();
  }

  TerminalSession? _find(List<OpenTerminal> open) {
    for (final terminal in open) {
      if (terminal.session.spi?.id == widget.spi.id) return terminal.session;
    }
    return null;
  }

  Future<void> _start() async {
    _autoStarted = true;
    if (!_handedOver) _started?.close();
    _handedOver = false;
    _failed = false;
    final server = ref.read(serverProvider(widget.spi.id));
    final session = TerminalSession(source: ServerSource(widget.spi))
      ..adopt(server.client, granted: server.remoteAccess);
    setState(() => _started = session);
    // Ended before the terminal tab took it: nothing will close this panel's
    // copy, so it lets go itself.
    session.onForegroundDone = (_) {
      if (mounted && identical(_started, session)) {
        setState(() => _started = null);
      }
    };
    try {
      if (session.backend == null) {
        session.writeLn(l10n.waitConnection);
        await session.connect(
          granted: server.remoteAccess,
          context: mounted ? context : null,
        );
      }
      final shell = await session.openShell();
      // Closed while the shell was opening — the panel went, or a retry
      // replaced it: the session will not take the shell, so nothing else
      // would close it.
      if (shell != null && (!mounted || !identical(_started, session))) {
        shell.close();
        return;
      }
      if (shell == null) {
        session.writeLn(libL10n.fail);
        if (mounted) setState(() => _failed = true);
        return;
      }
      session.bindForeground(shell);
      _handedOver = true;
      // Queued for the terminal tab, which may not be built yet: it takes the
      // session when it is, and lists it from then on.
      ref
          .read(terminalRequestsProvider.notifier)
          .add(widget.spi, session: session);
    } catch (e, s) {
      Loggers.app.warning('Companion terminal failed to start', e, s);
      session.writeLn('${libL10n.fail}: $e');
      if (mounted && identical(_started, session)) {
        setState(() => _failed = true);
      }
    }
  }

  /// Lends [session] while this panel is showing it, and gives it back
  /// otherwise. After the frame: providers do not change during a build.
  void _syncLend(TerminalSession? session) {
    if (identical(_lent, session)) return;
    _lent = session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only what this panel still wants: a later build may have changed it.
      if (!mounted || !identical(_lent, session)) return;
      if (session == null) {
        _lend.giveBack(this);
        return;
      }
      // Out of the floating window too: a terminal is drawn in one place.
      ref.read(terminalShellProvider.notifier).hideIf(session);
      _lend.lend(session, holder: this);
    });
  }

  @override
  Widget build(BuildContext context) {
    final slot = CompanionSlot.of(context);
    final listed = _find(ref.watch(openTerminalsProvider));
    // The terminal tab has it now, and closes it when it ends.
    if (listed != null && identical(listed, _started)) _started = null;
    final session = listed ?? _started;

    if (session == null && !_autoStarted && slot.visible) {
      _autoStarted = true;
      scheduleMicrotask(() {
        if (mounted) unawaited(_start());
      });
    }

    final showing = slot.visible ? session : null;
    _syncLend(showing);

    return CompanionFrame(
      actions: [
        if (_failed && session != null && identical(session, _started))
          BarAction(icon: Icons.refresh, label: libL10n.retry, onTap: _start),
      ],
      body: switch (showing) {
        final session? => BareTerminal(
          key: ValueKey(session),
          session: session,
        ),
        null when session == null && _autoStarted => Center(
          child: TextButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.terminal),
            label: Text(libL10n.start),
          ),
        ),
        null => const SizedBox.shrink(),
      },
    );
  }
}
