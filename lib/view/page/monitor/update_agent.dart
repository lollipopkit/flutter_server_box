import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_access.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/src/rust/api/script.dart' as rust;
import 'package:server_box/view/page/ssh/page/page.dart';

/// Why an agent is offered an update.
sealed class MonitorUpdateReason {
  const MonitorUpdateReason();
}

/// It wants a user name, so this app cannot sign in to it with the password
/// alone.
final class MonitorTooOld extends MonitorUpdateReason {
  const MonitorTooOld();
}

/// It answers, and a newer release is out.
final class MonitorOutdated extends MonitorUpdateReason {
  const MonitorOutdated({required this.running, required this.latest, this.update});

  final String running;
  final String latest;

  /// The agent's own answer (`GET /api/v1/update`); null for one too old to
  /// give it.
  final MonitorUpdate? update;
}

/// How to update [spi]'s agent, and doing it.
///
/// Over the agent the update is the agent's to run (`POST /update/run`, or,
/// for one too old for that, the same starter through its `/exec`:
/// `sbm_parser::monitor_agent::start_update_script`): it runs apart from the
/// agent, so the restart that ends every connection through the agent does
/// not end it, and this dialog follows its log across the restart. Over SSH
/// the command runs in a terminal, which the restart leaves alone. A
/// container or a NixOS module is updated its own way, said instead.
Future<void> showMonitorUpdate(BuildContext context, Spi spi, MonitorUpdateReason reason, {MonitorAccess? access}) {
  return context.showRoundDialog<void>(
    title: '${l10n.monitorUpdateAgent} · ${spi.name}',
    child: _UpdateDialog(spi: spi, reason: reason, access: access),
  );
}

/// How the update is run.
enum _Way {
  /// The agent starts it (`POST /update/run`).
  agent,

  /// An agent from before one account starts it through `/exec`, signed in
  /// to with the account name it still wants.
  ///
  /// TODO: remove with `MonitorHttpCredential.legacyUser`.
  legacy,

  /// A terminal over SSH.
  ssh,

  /// The command, for the operator to run.
  shown,
}

enum _Phase { idle, starting, running, ended }

class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog({required this.spi, required this.reason, required this.access});

  final Spi spi;
  final MonitorUpdateReason reason;
  final MonitorAccess? access;

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  /// How often the agent is asked how the update goes.
  static const _every = Duration(seconds: 2);

  /// When to stop waiting for an agent that does not come back.
  static const _giveUp = Duration(minutes: 15);

  late final MonitorUpdate? _update = switch (widget.reason) {
    MonitorOutdated(:final update) => update,
    MonitorTooOld() => null,
  };
  late final MonitorInstall _install = _update?.install ?? MonitorInstall.other;
  late final String? _command = switch (_install) {
    MonitorInstall.container || MonitorInstall.nix => null,
    _ => _update?.command ?? rust.monitorUpgradeCommand(),
  };
  late final _Way _way = _pickWay();

  late final _user = TextEditingController(text: widget.spi.monitorHttp?.legacyUser ?? 'admin');
  final _password = TextEditingController();
  late bool _askPassword = _update?.needsPassword ?? false;

  var _phase = _Phase.idle;
  String? _error;
  MonitorHttpClient? _client;
  Timer? _timer;
  DateTime? _since;
  MonitorUpdateRun? _run;
  String? _version;

  /// The agent is not answering: restarting, most likely.
  var _away = false;

  _Way _pickWay() {
    final monitor = widget.spi.monitorHttp;
    if (_command == null) return _Way.shown;
    if (_update != null && _install == MonitorInstall.script && widget.access?.ok == true && monitor != null) {
      return _Way.agent;
    }
    if (widget.reason is MonitorTooOld && widget.spi.sshOn == null && monitor != null) return _Way.legacy;
    if (widget.spi.sshOn != null) return _Way.ssh;
    return _Way.shown;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client?.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (why, doc) = switch (widget.reason) {
      MonitorTooOld() => (l10n.monitorAgentTooOldBody, Urls.monitorUpgradeDoc),
      MonitorOutdated(:final running, :final latest) => (l10n.monitorAgentOutdatedBody(latest, running), Urls.monitorInstallDoc),
    };
    return SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(why),
                  UIs.height13,
                  ...switch (_phase) {
                    _Phase.idle || _Phase.starting => _buildHow(),
                    _Phase.running || _Phase.ended => _buildProgress(),
                  },
                ],
              ),
            ),
          ),
          UIs.height13,
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 7,
            children: [
              TextButton(onPressed: () => doc.launchUrl(), child: Text(libL10n.doc)),
              TextButton(onPressed: context.popDialog, child: Text(libL10n.close)),
              ?_buildAction(),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHow() {
    final command = _command;
    if (command == null) {
      return [Text(_install == MonitorInstall.nix ? l10n.monitorUpdateNix : l10n.monitorUpdateDocker)];
    }
    final error = _error;
    return [
      if (_way == _Way.agent || _way == _Way.legacy) ...[
        Text(l10n.monitorUpdateAgentHint, style: UIs.text12Grey),
        if (_way == _Way.legacy) ...[
          UIs.height7,
          Input(
            controller: _user,
            type: TextInputType.text,
            label: l10n.monitorUpdateLegacyUser,
            icon: Icons.person,
            suggestion: false,
            noWrap: true,
          ),
          Text(l10n.monitorUpdateLegacyHint, style: UIs.text12Grey),
        ],
        if (_askPassword) ...[
          UIs.height7,
          Input(
            controller: _password,
            type: TextInputType.visiblePassword,
            obscureText: true,
            label: l10n.monitorUpdateSudoPassword,
            icon: Icons.password,
            suggestion: false,
            noWrap: true,
          ),
          Text(l10n.monitorUpdateSudoHint, style: UIs.text12Grey),
        ],
      ] else ...[
        Text(l10n.monitorUpdateRunHint, style: UIs.text12Grey),
        UIs.height7,
        _CommandBox(command),
        UIs.height13,
        Text(_way == _Way.ssh ? l10n.monitorUpdateSshHint : l10n.monitorUpdateNoSsh, style: UIs.text12Grey),
      ],
      if (_install == MonitorInstall.other && _way != _Way.agent) ...[
        UIs.height7,
        Text(l10n.monitorUpdateDocker, style: UIs.text12Grey),
      ],
      if (error != null) ...[
        UIs.height7,
        Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
      ],
    ];
  }

  List<Widget> _buildProgress() {
    final scheme = Theme.of(context).colorScheme;
    final run = _run;
    final (Widget icon, String text) = switch ((_phase, run?.state)) {
      (_Phase.ended, MonitorUpdateRunState.done) => (
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
        l10n.monitorUpdateDone(_version ?? ''),
      ),
      (_Phase.ended, _) => (Icon(Icons.error_outline, color: scheme.error, size: 20), _error ?? l10n.monitorUpdateFailed),
      _ => (
        const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        _away ? l10n.monitorUpdateRestarting : l10n.monitorUpdating,
      ),
    };
    final lines = run?.lines ?? const <String>[];
    return [
      Row(children: [icon, UIs.width7, Expanded(child: Text(text))]),
      if (lines.isNotEmpty) ...[
        UIs.height13,
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(9)),
          padding: const EdgeInsets.all(9),
          child: SingleChildScrollView(
            reverse: true,
            child: SelectableText(lines.join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
      ],
      UIs.height7,
      Text(l10n.monitorUpdateAfter, style: UIs.text12Grey),
    ];
  }

  Widget? _buildAction() {
    if (_phase != _Phase.idle && _phase != _Phase.starting) return null;
    final command = _command;
    if (command == null) return null;
    return switch (_way) {
      _Way.agent || _Way.legacy => FilledButton.icon(
        icon: _phase == _Phase.starting
            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.system_update_alt, size: 18),
        label: Text(l10n.monitorUpdateNow),
        onPressed: _phase == _Phase.starting ? null : () => unawaited(_start()),
      ),
      _Way.ssh => FilledButton.icon(
        icon: const Icon(Icons.terminal, size: 18),
        label: Text(l10n.monitorUpdateInTerminal),
        onPressed: () {
          final page = context;
          context.popDialog();
          SSHPage.route.go(page, SshPageArgs(source: ServerSource(widget.spi), initCmd: command));
        },
      ),
      _Way.shown => null,
    };
  }

  Future<void> _start() async {
    final monitor = widget.spi.monitorHttp!;
    final user = _user.text.trim();
    final password = _askPassword ? _password.text : null;
    setState(() {
      _phase = _Phase.starting;
      _error = null;
    });
    _client?.dispose();
    final client = _client = MonitorHttpClient(
      _way == _Way.legacy && user.isNotEmpty ? monitor.withLegacyUser(user) : monitor,
    );
    try {
      if (_way == _Way.legacy) {
        final out = await client.exec(rust.monitorStartUpdateScript(), stdin: password == null ? null : '$password\n');
        if (out.exitCode == rust.monitorUpdateSudoRefusedExit()) {
          throw const MonitorHttpErr(type: MonitorHttpErrType.sudoRefused);
        }
        if (out.exitCode != 0) throw Exception('${out.stdout}${out.stderr}'.trim());
      } else {
        await client.startUpdate(password: password);
      }
    } on MonitorHttpErr catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        if (e.type == MonitorHttpErrType.sudoRefused) {
          // Asked for now where it was not known to be needed (an old agent
          // does not say), and wrong where it was given.
          _error = _askPassword ? l10n.monitorUpdateSudoRefused : null;
          _askPassword = true;
        } else {
          _error = e.message ?? '$e';
        }
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = '$e';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.running);
    _since = DateTime.now();
    _timer = Timer.periodic(_every, (_) => unawaited(_poll()));
  }

  var _polling = false;

  Future<void> _poll() async {
    final client = _client;
    if (client == null || _polling || _phase != _Phase.running) return;
    _polling = true;
    try {
      final update = await client.update();
      if (!mounted) return;
      final run = update.run;
      setState(() {
        _away = false;
        _run = run ?? _run;
        _version = update.version;
      });
      if (run != null && run.state != MonitorUpdateRunState.running) _end(null);
    } on MonitorHttpErr catch (e) {
      // An agent too old to have `/update` answers 404 until the new one is
      // up; anything else is an agent not answering, mid-restart.
      if (mounted) setState(() => _away = e.type != MonitorHttpErrType.notFound);
    } catch (_) {
      if (mounted) setState(() => _away = true);
    } finally {
      _polling = false;
    }
    final since = _since;
    if (mounted && _phase == _Phase.running && since != null && DateTime.now().difference(since) > _giveUp) {
      _end(l10n.monitorUpdateNoAnswer);
    }
  }

  void _end(String? error) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _phase = _Phase.ended;
      _error = error;
    });
    // The server reconnects now rather than when its back-off allows: its
    // agent is a new one.
    TryLimiter.reset(widget.spi.id);
    unawaited(ref.read(serversProvider.notifier).refresh(spi: widget.spi));
  }
}

class _CommandBox extends StatelessWidget {
  const _CommandBox(this.command);

  final String command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.fromLTRB(13, 9, 5, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              command,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: libL10n.copy,
            onPressed: () => Pfs.copy(command),
          ),
        ],
      ),
    );
  }
}
