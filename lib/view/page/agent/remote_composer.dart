import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart'
    show AttachButton, ComposerBox, ComposerButton, ComposerModelChip, ComposerThinkingChip, MenuBtn, llmL10n;
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_agent.dart';
import 'package:server_box/data/provider/ai/remote_agent.dart';

/// What [RemoteComposer] hands on: the words, the uploads made for them, a
/// model and thinking level when they were changed, and for a new task the
/// permission mode it runs in.
typedef RemoteMessage = ({
  String text,
  List<String> files,
  MonitorAgentModel? model,
  String? thinkingLevel,
  String? mode,
});

/// The box a message to a server's Agent mode is written in — a reply to a
/// task, or the start of one: the chat composer's look, with the server's
/// models and thinking levels, and files uploaded to it as the message goes.
class RemoteComposer extends StatefulWidget {
  const RemoteComposer({
    super.key,
    required this.serverId,
    required this.hint,
    required this.onSend,
    this.flow,
    this.blocked = false,
    this.onStop,
  });

  final String serverId;
  final String hint;

  /// The task replied to; null for a new one. Its model and thinking level
  /// are what is shown until others are picked.
  final MonitorAgentFlow? flow;

  /// Nothing can be written: what the task waits on is answered elsewhere.
  final bool blocked;

  /// Sends [RemoteMessage]; true when it went, and the box empties.
  final Future<bool> Function(RemoteMessage message) onSend;

  /// Where set, an empty box's button stops the task instead.
  final VoidCallback? onStop;

  @override
  State<RemoteComposer> createState() => _RemoteComposerState();
}

class _RemoteComposerState extends State<RemoteComposer> {
  final _text = TextEditingController();
  bool _sending = false;

  /// What the agent lets a task run with; null until read, or when it
  /// cannot say (an older agent).
  MonitorAgentChoices? _choices;

  /// Picked for the next message: files (paths), a model, a thinking level.
  List<String> _files = const [];
  MonitorAgentModel? _model;
  String? _thinking;

  /// The permission mode picked for a new task; null for the server's.
  String? _mode;

  /// As many files as one task takes at once (the agent's `MAX_PER_TASK`).
  static const _maxFiles = 10;

  @override
  void initState() {
    super.initState();
    unawaited(_loadChoices());
  }

  @override
  void didUpdateWidget(RemoteComposer old) {
    super.didUpdateWidget(old);
    if (old.serverId != widget.serverId) {
      _choices = null;
      _model = null;
      _thinking = null;
      _mode = null;
      unawaited(_loadChoices());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadChoices() async {
    final serverId = widget.serverId;
    try {
      final c = await RemoteAgentTasks.client(serverId)?.agentChoices();
      if (mounted && c != null && serverId == widget.serverId) setState(() => _choices = c);
    } catch (e) {
      Loggers.app.warning('Agent choices of $serverId', e);
    }
  }

  /// The model the next message goes to: picked, the task's, the machine's.
  MonitorAgentModel? get _effectiveModel => _choices?.find(_model ?? widget.flow?.model ?? _choices?.model);

  String get _effectiveThinking => _thinking ?? widget.flow?.thinkingLevel ?? _choices?.thinkingLevel ?? 'off';

  /// The permission mode a new task starts in: picked, else the server's;
  /// `bypass` only where the server allows it.
  String _effectiveMode(({String defaultMode, bool bypassAllowed})? server) {
    final m = _mode ?? server?.defaultMode ?? 'manual';
    return m == 'bypass' && !(server?.bypassAllowed ?? false) ? 'manual' : m;
  }

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

  Future<void> _send() async {
    final text = _text.text.trim();
    final client = RemoteAgentTasks.client(widget.serverId);
    if ((text.isEmpty && _files.isEmpty) || client == null || _sending || widget.blocked) return;
    setState(() => _sending = true);
    try {
      final ids = [for (final f in _files) await client.agentUpload(File(f))];
      final model = _model;
      final sent = await widget.onSend((
        text: text,
        files: ids,
        model: model != null && !model.same(widget.flow?.model) ? model : null,
        thinkingLevel: _thinking,
        mode: widget.flow == null ? _effectiveMode(RemoteAgentTasks.modes.value[widget.serverId]) : null,
      ));
      if (sent && mounted) {
        _text.clear();
        setState(() {
          _files = const [];
          _model = null;
          _thinking = null;
          _mode = null;
        });
      }
    } catch (e) {
      Toast.show('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = widget.blocked;
    return ListenableBuilder(
      listenable: Listenable.merge([_text, RemoteAgentTasks.modes]),
      builder: (context, _) {
        final empty = _text.text.isEmpty && _files.isEmpty;
        // Only a new task takes a mode: a task keeps the one it began in.
        final server = widget.flow == null ? RemoteAgentTasks.modes.value[widget.serverId] : null;
        final mode = server == null ? null : _effectiveMode(server);
        return ComposerBox(
          controller: _text,
          enabled: !blocked,
          hint: widget.hint,
          onSubmit: () => unawaited(_send()),
          top: _files.isEmpty && mode != 'bypass'
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mode == 'bypass')
                      Padding(
                        padding: const EdgeInsets.only(left: 5, bottom: 5),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 15, color: scheme.error),
                            UIs.width7,
                            Expanded(
                              child: Text(
                                context.l10n.agentModeBypassWarn,
                                style: TextStyle(fontSize: 12, color: scheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_files.isNotEmpty)
                      Wrap(
                        spacing: 5,
                        children: [
                          for (final f in _files)
                            InputChip(
                              label: Text(f.split(RegExp(r'[/\\]')).last, style: UIs.text12),
                              onDeleted: () => setState(() => _files = [..._files]..remove(f)),
                            ),
                        ],
                      ),
                  ],
                ),
          actions: [
            if (!blocked)
              AttachButton(onPicked: (paths) => setState(() => _files = [..._files, ...paths].take(_maxFiles).toList())),
            if (server != null && mode != null)
              _ModeChip(mode: mode, bypassAllowed: server.bypassAllowed, onPick: (m) => setState(() => _mode = m)),
            if (_effectiveModel case final m?) Flexible(child: ComposerModelChip(name: m.label, onTap: blocked ? null : _pickModel)),
            if (_effectiveModel?.reasoning ?? false)
              ComposerThinkingChip(
                level: _effectiveThinking,
                levels: _choices?.thinkingLevels ?? const [],
                onPick: (l) => setState(() => _thinking = l),
              ),
          ],
          button: _sending
              ? const SizedBox(width: 32, height: 32, child: SizedLoading(20, padding: 6, builder: SizedLoading.circularBuilder))
              : widget.onStop != null && empty
              ? ComposerButton.stop(scheme, onTap: widget.onStop)
              : ComposerButton.send(scheme, onTap: blocked ? null : () => unawaited(_send())),
        );
      },
    );
  }
}

/// The permission mode a new task runs in: what steps it takes without
/// asking. Rules for `manual` are the server's, in its Agent settings.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.bypassAllowed, required this.onPick});

  final String mode;
  final bool bypassAllowed;
  final void Function(String mode) onPick;

  static const _modes = ['auto', 'manual', 'bypass'];

  static IconData _icon(String mode) => switch (mode) {
    'auto' => Icons.auto_mode,
    'bypass' => Icons.bolt,
    _ => Icons.rule,
  };

  static String _label(BuildContext context, String mode) => switch (mode) {
    'auto' => context.l10n.agentModeAuto,
    'bypass' => context.l10n.agentModeBypass,
    _ => context.l10n.agentModeManual,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = mode == 'bypass' ? scheme.error : null;
    return MenuBtn(
      actions: [
        for (final m in _modes)
          ContextMenuAction(
            text: _label(context, m),
            icon: _icon(m),
            checked: m == mode,
            enabled: m != 'bypass' || bypassAllowed,
            note: m == 'bypass' && !bypassAllowed ? context.l10n.agentModeBypassOff : null,
            onTap: () => onPick(m),
          ),
      ],
      builder: (toggle) => Tooltip(
        message: context.l10n.agentPermissionMode,
        child: Btn.row(
          icon: Icon(_icon(mode), size: 16, color: color),
          text: _label(context, mode),
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          mainAxisSize: MainAxisSize.min,
          onTap: toggle,
          padding: const EdgeInsets.all(5),
        ),
      ),
    );
  }
}
