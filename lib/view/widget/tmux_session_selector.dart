import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/ssh/tmux/tmux_session.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';
import 'package:server_box/data/ssh/tmux/tmux_window_info.dart';

/// Dialog that allows the user to select a tmux session and window.
final class TmuxSessionSelector extends StatefulWidget {
  final List<TmuxSessionInfo> sessions;
  final Future<TmuxSession> Function() tmuxSessionFactory;
  final String defaultSessionName;
  final String? initialSessionName;

  const TmuxSessionSelector({
    super.key,
    required this.sessions,
    required this.tmuxSessionFactory,
    this.defaultSessionName = 'server_box',
    this.initialSessionName,
  });

  @override
  State<TmuxSessionSelector> createState() => _TmuxSessionSelectorState();
}

final class _TmuxSessionSelectorState extends State<TmuxSessionSelector> {
  late final TextEditingController _newSessionCtrl;
  TmuxSessionInfo? _selectedSession;
  List<TmuxWindowInfo>? _windows;
  bool _loadingWindows = false;
  int _windowRequestId = 0;
  Future<void> _windowMutationQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _newSessionCtrl = TextEditingController(text: widget.defaultSessionName);
    final initialSessionName = widget.initialSessionName;
    if (initialSessionName == null) {
      return;
    }

    final initialSession = widget.sessions
        .where((session) => session.name == initialSessionName)
        .firstOrNull;
    if (initialSession == null) return;

    _selectedSession = initialSession;
    _loadingWindows = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadWindowsForSession(initialSession);
    });
  }

  @override
  void dispose() {
    _newSessionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSession != null) {
      return _buildWindowView();
    }
    return _buildSessionView();
  }

  Widget _buildSessionView() {
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400, maxWidth: 400),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.sessions.isNotEmpty) ...[
              _buildSectionHeader(l10n.tmuxExistingSessions),
              const SizedBox(height: 4),
              ...widget.sessions.map(_buildSessionTile),
              const Divider(height: 24),
            ],
            _buildSectionHeader(l10n.tmuxNewSession),
            const SizedBox(height: 4),
            _buildNewSessionInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowView() {
    final l10n = context.l10n;
    final session = _selectedSession!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400, maxWidth: 400),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      _windowRequestId++;
                      _selectedSession = null;
                      _windows = null;
                    }),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildSectionHeader(l10n.tmuxWindows)),
                IconButton(
                  onPressed: () => _createWindow(session.name),
                  icon: const Icon(Icons.add, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: l10n.tmuxNewWindow,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_loadingWindows)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_windows != null && _windows!.isNotEmpty)
              ..._windows!.map((w) => _buildWindowTile(session.name, w))
            else if (_windows != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.tmuxNoWindowsFound,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSessionTile(TmuxSessionInfo session) {
    final l10n = context.l10n;
    final timeParts = <String>[];
    if (session.activity != null && session.activity!.isNotEmpty) {
      timeParts.add(l10n.tmuxActiveAt(session.activity!));
    }
    if (session.lastAttached != null && session.lastAttached!.isNotEmpty) {
      timeParts.add(l10n.tmuxAttachedAt(session.lastAttached!));
    }
    final timeLine = timeParts.isNotEmpty ? '\n${timeParts.join(' · ')}' : '';
    final details = <String>[
      l10n.tmuxWindowCount(session.windows),
      if (session.attached) l10n.tmuxAttached,
    ];

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        session.attached ? Icons.link : Icons.link_off,
        size: 20,
        color: session.attached ? Colors.green : null,
      ),
      title: Text(session.name),
      subtitle: Text(
        '${details.join(' · ')}$timeLine',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => _onSessionTapped(session),
    );
  }

  Future<void> _onSessionTapped(TmuxSessionInfo session) async {
    setState(() {
      _selectedSession = session;
      _loadingWindows = true;
      _windows = null;
    });
    await _loadWindowsForSession(session);
  }

  Future<void> _loadWindowsForSession(TmuxSessionInfo session) async {
    final previousWindows = _windows;
    final requestId = ++_windowRequestId;
    try {
      final windows = await _withTmuxSession(
        (tmuxSession) => tmuxSession.tryListWindows(session.name),
      );
      if (!_isCurrentWindowRequest(requestId, session.name)) return;
      if (windows == null) {
        setState(() {
          _windows = previousWindows;
          _loadingWindows = false;
        });
        context.showSnackBar(libL10n.fail);
        return;
      }
      setState(() {
        _windows = windows;
        _loadingWindows = false;
      });
    } catch (_) {
      if (!_isCurrentWindowRequest(requestId, session.name)) return;
      setState(() {
        _windows = previousWindows;
        _loadingWindows = false;
      });
      context.showSnackBar(libL10n.fail);
    }
  }

  bool _isCurrentWindowRequest(int requestId, String sessionName) {
    return mounted &&
        requestId == _windowRequestId &&
        _selectedSession?.name == sessionName;
  }

  Widget _buildWindowTile(String sessionName, TmuxWindowInfo window) {
    final l10n = context.l10n;
    final details = <String>[
      l10n.tmuxPaneCount(window.panes),
      if (window.active) l10n.tmuxActive,
    ];
    final activity = window.activity;
    final subtitle = '${details.join(' · ')}'
        '${activity != null && activity.isNotEmpty ? '\n$activity' : ''}';

    final tile = ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        window.active ? Icons.circle : Icons.circle_outlined,
        size: 16,
        color: window.active ? Colors.green : null,
      ),
      title: Text('${window.index}: ${window.name}'),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () {
        context.pop(
          TmuxAttachExisting(
            sessionName: sessionName,
            windowIndex: window.index,
          ),
        );
      },
    );

    return Dismissible(
      key: ValueKey('window_${sessionName}_${window.index}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.withValues(alpha: 0.15),
        child: const Icon(Icons.delete, color: Colors.red, size: 20),
      ),
      onDismissed: (_) => _killWindow(sessionName, window.index),
      child: tile,
    );
  }

  Future<T> _withTmuxSession<T>(
    Future<T> Function(TmuxSession tmuxSession) action,
  ) async {
    final tmuxSession = await widget.tmuxSessionFactory();
    try {
      return await action(tmuxSession);
    } finally {
      await tmuxSession.dispose();
    }
  }

  Future<void> _killWindow(String sessionName, int windowIndex) async {
    await _runWindowMutation(
      sessionName,
      (tmuxSession) => tmuxSession.killWindow(sessionName, windowIndex),
    );
  }

  Widget _buildNewSessionInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Input(
              controller: _newSessionCtrl,
              hint: context.l10n.tmuxSessionName,
              suggestion: false,
              onSubmitted: (_) => _createNewSession(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _createNewSession,
            icon: const Icon(Icons.add, size: 20),
          ),
        ],
      ),
    );
  }

  void _createNewSession() {
    final name = _newSessionCtrl.text.trim();
    if (name.isEmpty) return;
    context.pop(TmuxAttachNew(sessionName: name));
  }

  Future<void> _createWindow(String sessionName) async {
    await _runWindowMutation(
      sessionName,
      (tmuxSession) => tmuxSession.newWindow(sessionName),
    );
  }

  Future<void> _runWindowMutation(
    String sessionName,
    Future<bool> Function(TmuxSession tmuxSession) mutation,
  ) {
    _windowMutationQueue = _windowMutationQueue.then(
      (_) => _executeWindowMutation(sessionName, mutation),
    );
    return _windowMutationQueue;
  }

  Future<void> _executeWindowMutation(
    String sessionName,
    Future<bool> Function(TmuxSession tmuxSession) mutation,
  ) async {
    if (!mounted || _selectedSession?.name != sessionName) return;
    final previousWindows = _windows;
    final requestId = ++_windowRequestId;
    setState(() {
      _loadingWindows = true;
    });
    try {
      final windows = await _withTmuxSession((tmuxSession) async {
        if (!await mutation(tmuxSession)) return null;
        return tmuxSession.tryListWindows(sessionName);
      });
      if (!_isCurrentWindowRequest(requestId, sessionName)) return;
      if (windows == null) {
        setState(() {
          _windows = previousWindows;
          _loadingWindows = false;
        });
        context.showSnackBar(libL10n.fail);
        return;
      }
      setState(() {
        _windows = windows;
        _loadingWindows = false;
      });
    } catch (_) {
      if (!_isCurrentWindowRequest(requestId, sessionName)) return;
      setState(() {
        _windows = previousWindows;
        _loadingWindows = false;
      });
      context.showSnackBar(libL10n.fail);
    }
  }
}

/// Show the session/window selector with a "skip" option.
Future<TmuxAttachChoice?> showTmuxSessionSelectorWithSkip(
  BuildContext context, {
  required List<TmuxSessionInfo> sessions,
  required Future<TmuxSession> Function() tmuxSessionFactory,
  String defaultSessionName = 'server_box',
  String? initialSessionName,
}) async {
  final l10n = context.l10n;
  return context.showRoundDialog<TmuxAttachChoice>(
    title: 'tmux',
    child: TmuxSessionSelector(
      sessions: sessions,
      tmuxSessionFactory: tmuxSessionFactory,
      defaultSessionName: defaultSessionName,
      initialSessionName: initialSessionName,
    ),
    actions: [
      TextButton(
        onPressed: () => context.pop(const TmuxAttachSkip()),
        child: Text(l10n.tmuxSkip),
      ),
    ],
  );
}
