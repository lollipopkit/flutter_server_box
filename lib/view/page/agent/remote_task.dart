import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart'
    show AttachButton, ComposerBox, llmL10n, ComposerButton, ComposerModelChip, ComposerThinkingChip, LlmEntry, StreamingReply, StreamingView, ThreadBlock, ThreadBlockView, ReplyBlock, SummaryBlock, UserBlock, threadBlocks;
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_agent.dart';
import 'package:server_box/data/provider/ai/remote_agent.dart';
import 'package:server_box/data/provider/server/single.dart';

/// A task of a server's monitor agent, opened in the Agent's pane: its
/// conversation as the agent keeps it, followed live, what it waits on, and a
/// line to say more. It runs on that server; nothing of it is kept here.
class RemoteTaskView extends StatefulWidget {
  const RemoteTaskView({super.key, required this.task, this.header});

  final RemoteTaskRef task;

  /// The pane's header for [title] with these actions; null for none.
  final Widget Function(String title, List<BarAction> actions)? header;

  @override
  State<RemoteTaskView> createState() => _RemoteTaskViewState();
}

class _RemoteTaskViewState extends State<RemoteTaskView> {
  StreamSubscription<Map<String, dynamic>>? _events;
  MonitorAgentFlow? _flow;
  List<Map<String, dynamic>> _entries = const [];
  MonitorAgentPending? _pending;
  StreamingReply? _streaming;

  /// The running command's last lines.
  List<String> _output = const [];
  String? _error;
  bool _loading = true;
  bool _sending = false;
  final _reply = TextEditingController();

  /// What the agent lets a task run with; null until read, or when it
  /// cannot say (an older agent).
  MonitorAgentChoices? _choices;

  /// Picked for the next message: files (paths), a model, a thinking level.
  /// Sent with it, after which the task holds them.
  List<String> _files = const [];
  MonitorAgentModel? _model;
  String? _thinking;

  RemoteTaskRef get _task => widget.task;

  @override
  void initState() {
    super.initState();
    RemoteAgentTasks.follow();
    _events = RemoteAgentTasks.events(_task.serverId).listen(_onEvent);
    unawaited(_load());
    unawaited(_loadChoices());
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    RemoteAgentTasks.unfollow();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = RemoteAgentTasks.client(_task.serverId);
    if (client == null) return;
    try {
      final d = await client.agentFlow(_task.flowId);
      if (!mounted) return;
      setState(() {
        _flow = d.flow;
        _entries = d.entries;
        _pending = d.pending;
        _output = d.output?.lines ?? const [];
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _say(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadChoices() async {
    try {
      final c = await RemoteAgentTasks.client(_task.serverId)?.agentChoices();
      if (mounted && c != null) setState(() => _choices = c);
    } catch (e) {
      Loggers.app.warning('Agent choices of ${_task.serverId}', e);
    }
  }

  /// The model the next message goes to: picked, the task's, the machine's.
  MonitorAgentModel? get _effectiveModel => _choices?.find(_model ?? _flow?.model ?? _choices?.model);

  String get _effectiveThinking => _thinking ?? _flow?.thinkingLevel ?? _choices?.thinkingLevel ?? 'off';

  Future<void> _pickModel() async {
    final choices = _choices;
    if (choices == null || choices.models.isEmpty) return;
    final current = _effectiveModel;
    final picked = await context.showRoundDialog<MonitorAgentModel>(
      title: llmL10n.model,
      childBuilder: (dialogContext) => SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in choices.models)
              ListTile(
                dense: true,
                title: Text(m.label),
                subtitle: Text(m.provider),
                trailing: m.same(current) ? const Icon(Icons.check, size: 18) : null,
                onTap: () => dialogContext.pop(m),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _model = picked);
  }

  void _onEvent(Map<String, dynamic> e) {
    final id = e['id'] ?? (e['flow'] as Map?)?['id'];
    if (e['type'] == 'resync') return unawaited(_load());
    if (id != _task.flowId) return;
    setState(() {
      switch (e['type']) {
        case 'flow':
          _flow = MonitorAgentFlow.fromJson(e['flow'] as Map<String, dynamic>);
          if (!_flow!.status.active) _streaming = null;
        case 'pending':
          _pending = switch (e['pending']) {
            final Map<String, dynamic> p => MonitorAgentPending.fromJson(p),
            _ => null,
          };
        case 'output':
          final lines = [..._output, ...MonitorAgentOutput.linesOf(e['lines'])];
          _output = lines.length > _outputLines ? lines.sublist(lines.length - _outputLines) : lines;
        case 'event':
          _onPiEvent(e['event'] as Map<String, dynamic>? ?? const {});
      }
    });
  }

  static const _outputLines = 40;

  /// As many files as one task takes at once (the agent's `MAX_PER_TASK`).
  static const _maxFiles = 10;

  static Object? _roleOf(Object? message) => message is Map ? message['role'] : null;

  /// The session's events, as `fl_pi_llm` reports them.
  void _onPiEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'message_start' when _roleOf(e['message']) == 'assistant':
        _streaming = const StreamingReply();
      case 'message_update':
        final u = e['event'] as Map? ?? const {};
        final delta = u['delta'] as String? ?? '';
        final s = _streaming ?? const StreamingReply();
        _streaming = switch (u['type']) {
          'text_delta' => s.copyWith(text: s.text + delta),
          'thinking_delta' => s.copyWith(thinking: s.thinking + delta),
          _ => s,
        };
      case 'message_end':
        _streaming = null;
      case 'entry_added':
        if (e['entry'] case final Map<String, dynamic> entry) {
          _entries = [..._entries.where((x) => x['id'] != entry['id']), entry]
            ..sort((a, b) => ((a['seq'] as num?) ?? 0).compareTo((b['seq'] as num?) ?? 0));
          // A command's result is in: its live output is done with.
          if ((entry['message'] as Map?)?['role'] == 'toolResult') _output = const [];
        }
    }
  }

  String _say(Object e) => switch (e) {
    MonitorHttpErr(type: MonitorHttpErrType.notFound) => context.l10n.agentRemoteGone,
    _ => '$e',
  };

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
    } on MonitorHttpErr catch (e) {
      // Answered meanwhile, elsewhere: what it waits on now is the thing to show.
      if (e.type == MonitorHttpErrType.conflict) unawaited(_load());
      if (mounted) Toast.show(_say(e));
    } catch (e) {
      if (mounted) Toast.show(_say(e));
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    final client = RemoteAgentTasks.client(_task.serverId);
    if ((text.isEmpty && _files.isEmpty) || client == null || _sending) return;
    setState(() => _sending = true);
    await _guard(() async {
      final ids = [for (final f in _files) await client.agentUpload(File(f))];
      final model = _model;
      final flow = await client.agentReply(
        _task.flowId,
        text,
        files: ids,
        model: model != null && !model.same(_flow?.model) ? model : null,
        thinkingLevel: _thinking,
      );
      _reply.clear();
      if (mounted) {
        setState(() {
          _flow = flow;
          _files = const [];
          _model = null;
          _thinking = null;
        });
      }
    });
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _answer(Map<String, Object?> answer) async {
    final pending = _pending;
    final client = RemoteAgentTasks.client(_task.serverId);
    if (pending == null || client == null) return;
    await _guard(() async {
      await client.agentAnswer(_task.flowId, {'id': pending.id, ...answer});
      if (mounted) setState(() => _pending = null);
    });
  }

  bool get _admin =>
      AgentScope.container.read(serverProvider(_task.serverId)).agentCapabilities?.me?.admin == true;

  String get _server => RemoteAgentTasks.servers().firstWhereOrNull((s) => s.id == _task.serverId)?.name ?? '';

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    final actions = [
      BarAction(
        icon: Icons.add,
        label: context.l10n.askAiNewConversation,
        onTap: () => AgentChats.startNew(null),
      ),
    ];
    final title = switch (flow?.title) {
      final t? when t.isNotEmpty => t,
      _ => context.l10n.askAiUntitledConversation,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?widget.header?.call(title, actions),
        Expanded(child: _buildBody(context)),
        _buildReply(context),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: SizedLoading(25, padding: 3, builder: SizedLoading.circularBuilder));
    if (_error case final e?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e, textAlign: TextAlign.center, style: UIs.textGrey),
        ),
      );
    }
    final flow = _flow;
    final blocks = threadBlocks([for (final e in _entries) LlmEntry(e)]);
    final active = flow?.status.active ?? false;
    final lastIsReply = blocks.lastOrNull is ReplyBlock;
    Widget view(int i, ThreadBlock b, [StreamingReply? s]) => ThreadBlockView(
      key: ValueKey(switch (b) {
        UserBlock(:final entry) || SummaryBlock(:final entry) => entry.id,
        ReplyBlock(:final entries) => entries.first.id,
      }),
      chat: null,
      block: b,
      streaming: s,
      live: active && i == blocks.length - 1,
    );
    final streaming = _streaming ?? (active && _pending == null ? const StreamingReply() : null);
    final items = <Widget>[
      _RunsOn(server: _server, flow: flow),
      for (final (i, b) in blocks.indexed)
        view(i, b, i == blocks.length - 1 && lastIsReply ? streaming : null),
      if (streaming != null && !lastIsReply) StreamingView(reply: streaming),
      if (_output.isNotEmpty) _Output(lines: _output),
      if (_pending case final p?)
        _PendingCard(key: ValueKey(p.id), pending: p, admin: _admin, onAnswer: _answer),
      if (flow?.status == MonitorAgentStatus.failed && flow!.line.isNotEmpty)
        Text(flow.line, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ];
    return LayoutBuilder(
      builder: (context, cons) {
        final side = (cons.maxWidth * 0.04).clamp(13.0, 26.0);
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(side, 17, side, 26),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 20),
          itemBuilder: (_, i) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox(width: double.infinity, child: items[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReply(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A sudo password is answered in its card, never as a reply.
    final blocked = _pending?.kind == 'sudo' || _flow == null;
    // Running, and not waiting on the person: the button stops it.
    final stops = (_flow?.status.active ?? false) && _pending == null && _reply.text.isEmpty && _files.isEmpty;
    // Inset and as wide as the messages above it, as a chat's composer is.
    return LayoutBuilder(
      builder: (context, cons) {
        final side = (cons.maxWidth * 0.03).clamp(9.0, 20.0);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(side, 0, side, 13),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListenableBuilder(
                  listenable: _reply,
                  builder: (context, _) => ComposerBox(
                    controller: _reply,
                    enabled: !blocked,
                    hint: context.l10n.agentRemoteReplyHint(_server),
                    onSubmit: () => unawaited(_send()),
                    top: _files.isEmpty
                        ? null
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 5,
                              children: [
                                for (final f in _files)
                                  InputChip(
                                    label: Text(f.split(RegExp(r'[/\\]')).last, style: UIs.text12),
                                    onDeleted: () => setState(() => _files = [..._files]..remove(f)),
                                  ),
                              ],
                            ),
                          ),
                    actions: [
                      if (!blocked)
                        AttachButton(
                          onPicked: (paths) => setState(() => _files = [..._files, ...paths].take(_maxFiles).toList()),
                        ),
                      if (_effectiveModel case final m?)
                        Flexible(child: ComposerModelChip(name: m.label, onTap: blocked ? null : _pickModel)),
                      if (_effectiveModel?.reasoning ?? false)
                        ComposerThinkingChip(
                          level: _effectiveThinking,
                          levels: _choices?.thinkingLevels ?? const [],
                          onPick: (l) => setState(() => _thinking = l),
                        ),
                    ],
                    button: _sending
                        ? const SizedBox(width: 32, height: 32, child: SizedLoading(20, padding: 6, builder: SizedLoading.circularBuilder))
                        : stops
                        ? ComposerButton.stop(
                            scheme,
                            onTap: () => _guard(() async => RemoteAgentTasks.client(_task.serverId)?.agentStop(_task.flowId)),
                          )
                        : ComposerButton.send(scheme, onTap: blocked ? null : () => unawaited(_send())),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Where the task runs and how it stands.
class _RunsOn extends StatelessWidget {
  const _RunsOn({required this.server, required this.flow});

  final String server;
  final MonitorAgentFlow? flow;

  @override
  Widget build(BuildContext context) {
    final status = flow?.status.name ?? '';
    return Text(
      context.l10n.agentRemoteStatus(server, status),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// The running command's last lines.
class _Output extends StatelessWidget {
  const _Output({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(9)),
      child: SelectableText(
        lines.join('\n'),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35),
      ),
    );
  }
}

/// What the task waits on, and the answers it takes (`answer` bodies of
/// `/agent/flows/{id}/answer`).
class _PendingCard extends StatefulWidget {
  const _PendingCard({super.key, required this.pending, required this.admin, required this.onAnswer});

  final MonitorAgentPending pending;
  final bool admin;
  final Future<void> Function(Map<String, Object?> answer) onAnswer;

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  final _typed = TextEditingController();
  var _remember = false;
  var _busy = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _go(Map<String, Object?> answer) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onAnswer(answer);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pending;
    final scheme = Theme.of(context).colorScheme;
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 13, color: scheme.onSurface);
    final cancel = TextButton(onPressed: _busy ? null : () => _go({'action': 'cancel'}), child: Text(libL10n.cancel));
    final children = <Widget>[
      Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      if (p.summary case final s? when s.isNotEmpty) Text(s),
    ];
    switch (p.kind) {
      case 'confirm':
        children.addAll([
          if (p.command case final c?)
            SelectableText(c, style: mono)
          else
            for (final s in p.steps)
              Text('• ${s.text}${s.command == null ? '' : '\n  ${s.command}'}', style: mono),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              FilledButton(onPressed: _busy ? null : () => _go({'action': 'run'}), child: Text(libL10n.run)),
              if (widget.admin && p.allowRule != null)
                OutlinedButton(
                  onPressed: _busy ? null : () => _go({'action': 'always'}),
                  child: Text(context.l10n.agentRemoteAlways(p.allowRule!)),
                ),
              cancel,
            ],
          ),
        ]);
      case 'danger':
        final confirm = p.confirmText ?? '';
        children.addAll([
          if (p.command case final c?) SelectableText(c, style: mono),
          for (final (i, a) in p.alternatives.indexed)
            OutlinedButton(
              onPressed: _busy ? null : () => _go({'action': 'alternative', 'index': i}),
              child: Text(a, style: mono),
            ),
          TextField(
            controller: _typed,
            decoration: InputDecoration(labelText: context.l10n.agentRemoteTypeToRun(confirm), isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          Wrap(
            spacing: 7,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                onPressed: _busy || _typed.text.trim() != confirm
                    ? null
                    : () => _go({'action': 'run', 'confirm': _typed.text.trim()}),
                child: Text(context.l10n.agentRemoteRunAnyway),
              ),
              cancel,
            ],
          ),
        ]);
      case 'sudo':
        children.addAll([
          if (p.command case final c?) SelectableText(c, style: mono),
          TextField(
            controller: _typed,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.l10n.agentRemoteSudoFor(p.user ?? 'root'),
              errorText: p.error == 'wrongPassword' ? context.l10n.agentRemoteSudoWrong : null,
              isDense: true,
            ),
            onSubmitted: (v) => v.isEmpty ? null : _go({'action': 'password', 'password': v, 'remember': _remember}),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            title: Text(context.l10n.agentRemoteSudoRemember),
          ),
          Wrap(
            spacing: 7,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _typed.text.isEmpty ? null : _go({'action': 'password', 'password': _typed.text, 'remember': _remember}),
                child: Text(libL10n.ok),
              ),
              cancel,
            ],
          ),
        ]);
      case 'clarify':
        children.addAll([
          for (final (i, o) in p.options.indexed)
            OutlinedButton(
              onPressed: _busy ? null : () => _go({'action': 'pick', 'index': i}),
              child: Text(o.hint == null ? o.label : '${o.label} — ${o.hint}'),
            ),
          // Anything else is a reply, typed below.
          cancel,
        ]);
    }
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: p.kind == 'danger' ? scheme.error : scheme.primary),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 9,
        children: children,
      ),
    );
  }
}
