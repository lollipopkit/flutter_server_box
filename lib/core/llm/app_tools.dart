import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/benchmark.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/view/page/benchmark/estimate.dart';
import 'package:server_box/view/widget/agent_common.dart';

/// Tools over the app's own features, each its own switch: the snippets, the
/// virtualization hosts it has loaded, the benchmark, remote desktop. See [AgentTools] for the ones
/// that reach a server.
abstract final class AppDataTools {
  static const snippets = 'snippets';
  static const virt = 'virt';
  static const benchmark = 'benchmark';
  static const remoteDesktop = 'remote_desktop';

  static const all = <ToolFunc>[SnippetTool(), VirtReadTool(), BenchmarkTool(), RemoteDesktopTool()];
}

String? _str(Map<String, Object?> a, String k) => switch (a[k]) {
  final String s when s.trim().isNotEmpty => s,
  _ => null,
};

/// The user's snippets: listed without asking, changed with their approval.
///
/// A snippet's `autoRunOn` — the servers it runs on by itself when they
/// connect — is not the model's to set: a script that runs unattended is
/// the user's decision alone, so it is neither read nor written here.
final class SnippetTool extends ToolFunc {
  const SnippetTool()
    : super(
        name: 'snippet',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['list', 'add', 'update', 'delete'],
            },
            'id': {'type': 'string', 'description': 'The snippet, for update and delete, as list gives it.'},
            'name': {'type': 'string'},
            'script': {'type': 'string', 'description': 'The shell script. `\${host}`, `\${user}` and the like are filled in from the server it runs on.'},
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'note': {'type': 'string'},
          },
          'required': ['action'],
        },
      );

  @override
  String get description =>
      "List, add, change or delete the user's snippets: saved scripts they run on servers from the app. "
      '`add` needs name and script; `update` changes only the fields given; `update` and `delete` take the id '
      'from `list`. This saves snippets and never runs one.';

  @override
  String get l10nName => libL10n.snippet;

  @override
  String get group => AppDataTools.snippets;

  @override
  String get groupLabel => libL10n.snippet;

  @override
  String? get l10nTip => l10n.agentSnippetToolsTip;

  @override
  IconData get groupIcon => Icons.code;

  @override
  IconData get icon => Icons.code;

  @override
  String summary(Map<String, Object?> args) => [args['action'], ?_str(args, 'name'), ?_str(args, 'id')].join(' · ');

  /// Reading them is the app's own data; changing them waits for a yes.
  @override
  LlmApproval? preApprove(Map<String, Object?> args, String chatId) =>
      args['action'] == 'list' ? const LlmApproval.allow() : null;

  @override
  Widget? preview(BuildContext context, Map<String, Object?> args, String chatId) {
    final script = _str(args, 'script');
    if (script == null) return null;
    return AgentCommandPreview(text: script);
  }

  static SnippetNotifier get _notifier => AgentScope.container.read(snippetProvider.notifier);
  static List<Snippet> get _all => AgentScope.container.read(snippetProvider).snippets;

  static Map<String, Object?> _json(Snippet s) => {
    'id': s.id,
    'name': s.name,
    'script': s.script,
    if (s.tags?.isNotEmpty ?? false) 'tags': s.tags,
    'note': ?s.note,
  };

  static List<String>? _tags(Map<String, Object?> a) => switch (a['tags']) {
    final List l => [for (final t in l) if (t is String && t.trim().isNotEmpty) t.trim()],
    _ => null,
  };

  static Snippet _find(Map<String, Object?> a) {
    final id = _str(a, 'id') ?? (throw const LlmException('id is required'));
    return _all.firstWhereOrNull((s) => s.id == id) ??
        (throw LlmException('No snippet $id. List them for their ids.'));
  }

  @override
  Future<LlmToolResult> run(Map<String, Object?> args, ToolCtx ctx) async {
    switch (args['action']) {
      case 'list':
        final all = _all;
        return LlmToolResult.text(all.isEmpty ? 'No snippets.' : jsonEncode([for (final s in all) _json(s)]));
      case 'add':
        final name = _str(args, 'name') ?? (throw const LlmException('name is required'));
        final script = _str(args, 'script') ?? (throw const LlmException('script is required'));
        final s = Snippet(id: ShortId.generate(), name: name, script: script, tags: _tags(args), note: _str(args, 'note'));
        await _notifier.add(s);
        return LlmToolResult.text('Added ${s.name} (${s.id}).');
      case 'update':
        final old = _find(args);
        final next = old.copyWith(
          name: _str(args, 'name') ?? old.name,
          script: _str(args, 'script') ?? old.script,
          tags: _tags(args) ?? old.tags,
          note: args.containsKey('note') ? _str(args, 'note') : old.note,
        );
        await _notifier.update(old, next);
        return LlmToolResult.text('Updated ${next.name} (${next.id}).');
      case 'delete':
        final old = _find(args);
        await _notifier.del(old);
        return LlmToolResult.text('Deleted ${old.name} (${old.id}).');
      default:
        throw const LlmException('action is one of list, add, update, delete');
    }
  }
}

/// What the Virtualization tab has loaded: hosts, their guests, and each
/// guest's last reading. Only what is already in the app — a host not loaded
/// this session is named as such rather than fetched, so reading costs no
/// connection.
final class VirtReadTool extends ToolFunc {
  const VirtReadTool()
    : super(
        name: 'virt_read',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'server_id': {'type': 'string', 'description': 'One host. Default: every one the app knows.'},
          },
        },
      );

  @override
  String get description =>
      'Read the virtual machines and containers (Proxmox VE, libvirt/KVM) the app has loaded: each host, its '
      'guests with their state, CPUs and memory, and the last usage reading. Only what the app already has; a '
      'host not loaded yet says so — the user opens the Virtualization tab to load it.';

  @override
  String get l10nName => l10n.virtualization;

  @override
  String get group => AppDataTools.virt;

  @override
  String get groupLabel => l10n.virtualization;

  @override
  String? get l10nTip => l10n.agentVirtToolsTip;

  @override
  IconData get groupIcon => Icons.dns_outlined;

  @override
  IconData get icon => Icons.dns_outlined;

  @override
  bool get trusted => true;

  @override
  String summary(Map<String, Object?> args) => _str(args, 'server_id') ?? '*';

  @override
  Future<LlmToolResult> run(Map<String, Object?> args, ToolCtx ctx) async {
    final c = AgentScope.container;
    final hosts = c.read(virtHostsProvider).hosts;
    final servers = c.read(serversProvider).servers;
    final only = _str(args, 'server_id');
    final ids = [for (final id in hosts.keys) if (only == null || id == only) id];
    if (ids.isEmpty) {
      return LlmToolResult.text(
        only == null
            ? 'No virtualization host is known yet. The Virtualization tab finds them.'
            : '$only is not a virtualization host the app knows.',
      );
    }
    final out = <String>[];
    for (final id in ids) {
      final name = servers[id]?.name ?? id;
      final head = '## $name ($id, ${hosts[id]!.name})';
      // Not read unless it exists: reading it would load it.
      final provider = virtHostProvider(id);
      if (!c.exists(provider)) {
        out.add('$head\nNot loaded this session.');
        continue;
      }
      final st = c.read(provider);
      final data = st.data;
      if (data == null) {
        out.add('$head\n${st.error == null ? 'Loading.' : 'Failed to load: ${st.error}'}');
        continue;
      }
      out.add([
        head,
        [
          if (data.host.version != null) 'version ${data.host.version}',
          if (data.host.hypervisor != null) data.host.hypervisor!,
          if (st.updatedAt != null) 'read ${st.updatedAt!.toIso8601String()}',
          if (st.error != null) 'last refresh failed: ${st.error}',
        ].join(', '),
        for (final g in data.guests) _guest(g, data.stats[g.id]),
      ].join('\n'));
    }
    return LlmToolResult.text(out.join('\n\n'));
  }

  static String _guest(VirtGuest g, VirtStats? s) {
    final parts = [
      g.kind.name,
      g.state.name + (g.stateReason == null ? '' : ' (${g.stateReason})'),
      if (g.vmid != null) 'vmid ${g.vmid}',
      if (g.node != null) 'node ${g.node}',
      if (g.vcpu != null) '${g.vcpu} vCPU',
      if (g.memBytes != null) '${g.memBytes!.bytes2Str} RAM',
      if (g.uptime != null) 'up ${g.uptime!.inMinutes} min',
      if (g.template) 'template',
      if (g.tags.isNotEmpty) 'tags ${g.tags.join(',')}',
    ];
    final usage = s == null
        ? null
        : [
            if (s.cpu != null) 'cpu ${s.cpu!.toStringAsFixed(1)}%',
            if (s.memUsed != null) 'mem ${s.memUsed!.bytes2Str}${s.memTotal == null ? '' : '/${s.memTotal!.bytes2Str}'}',
            if (s.diskUsed != null) 'disk ${s.diskUsed!.bytes2Str}${s.diskTotal == null ? '' : '/${s.diskTotal!.bytes2Str}'}',
            if (s.netIn != null) 'net in ${s.netIn!.toInt().bytes2Str}/s',
            if (s.netOut != null) 'out ${s.netOut!.toInt().bytes2Str}/s',
          ].join(', ');
    return '- ${g.name} [${g.id}]: ${parts.join(', ')}${usage == null || usage.isEmpty ? '' : ' — $usage'}';
  }
}

/// The yabs benchmark: runs read without asking, one started or stopped with
/// the user's approval, every time.
///
/// A run takes ten to twenty minutes, far past one tool call, so [run] starts
/// it and returns; a listener stays on the run until it ends — what keeps it
/// polled and its result written — and then tells the chat that started it
/// ([Chats.notify]), so the model can read it and answer. Only while the app
/// runs: a run outlasting it is read when the benchmark is next opened.
final class BenchmarkTool extends ToolFunc {
  const BenchmarkTool()
    : super(
        name: 'benchmark',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['list', 'read', 'run', 'cancel'],
            },
            'server_id': {'type': 'string'},
            'run_id': {'type': 'string', 'description': 'For read: a run from list. Default: the latest.'},
            'disk': {'type': 'boolean', 'description': 'run: the fio disk test. Default true.'},
            'network': {'type': 'boolean', 'description': 'run: the iperf3 network test. Default true.'},
            'cpu': {
              'type': 'boolean',
              'description': 'run: Geekbench, which publishes the machine\'s results online. Default false; '
                  'only when the user asked for it.',
            },
          },
          'required': ['action', 'server_id'],
        },
      );

  static final _listening = <String, ProviderSubscription<BenchmarkState>>{};

  @override
  String get description =>
      'The yabs benchmark of a server: `list` its runs, `read` one (the latest by default) — disk, network and '
      'CPU results, or the output of one still running — `run` a new one (10 to 20 minutes; returns at once, and '
      'an app notice tells this chat when it ends) or `cancel` the running one. A run needs a shell on the server.';

  @override
  String get l10nName => l10n.benchmark;

  @override
  String get group => AppDataTools.benchmark;

  @override
  String get groupLabel => l10n.benchmark;

  @override
  String? get l10nTip => l10n.agentBenchmarkToolsTip;

  @override
  IconData get groupIcon => Icons.speed;

  @override
  IconData get icon => Icons.speed;

  /// Each run costs time, traffic and load on the server: never a blanket yes.
  @override
  bool get allowAlways => false;

  @override
  String summary(Map<String, Object?> args) => [args['action'], ?_str(args, 'server_id'), ?_str(args, 'run_id')].join(' · ');

  @override
  LlmApproval? preApprove(Map<String, Object?> args, String chatId) =>
      const {'list', 'read'}.contains(args['action']) ? const LlmApproval.allow() : null;

  static String _server(Map<String, Object?> a) {
    final id = _str(a, 'server_id') ?? (throw const LlmException('server_id is required'));
    if (AgentScope.container.read(serversProvider).servers[id] == null) {
      throw LlmException('No server $id. List them with the serverbox tool.');
    }
    return id;
  }

  static Map<String, Object?> _brief(BenchmarkRun r) => {
    'id': r.id,
    'status': r.status.name,
    'started': r.startedAt.toIso8601String(),
    'elapsed': fmtDuration(r.elapsed),
    'tests': [if (r.options.disk) 'disk', if (r.options.network) 'network', if (r.options.cpu) 'cpu'],
  };

  @override
  Future<LlmToolResult> run(Map<String, Object?> args, ToolCtx ctx) async {
    final c = AgentScope.container;
    final id = _server(args);
    final store = BenchmarkStore.instance;
    switch (args['action']) {
      case 'list':
        final runs = store.forServer(id);
        return LlmToolResult.text(runs.isEmpty ? 'No benchmark runs.' : jsonEncode([for (final r in runs) _brief(r)]));
      case 'read':
        final runId = _str(args, 'run_id');
        final r = runId == null ? store.forServer(id).firstOrNull : store.get(runId);
        if (r == null || r.serverId != id) throw LlmException(runId == null ? 'No benchmark runs.' : 'No run $runId.');
        final result = r.result;
        final log = r.log.length > 4000 ? r.log.substring(r.log.length - 4000) : r.log;
        return LlmToolResult.text(jsonEncode({
          ..._brief(r),
          if (r.exitCode != null) 'exit_code': r.exitCode,
          if (r.error.isNotEmpty) 'error': r.error,
          // The public address and its owner stay out of the reply.
          if (result != null) 'result': result.toJson()..remove('ip_info')..remove('ipInfo'),
          if (result == null) 'output_tail': log,
        }));
      case 'run':
        if (!c.read(serverProvider(id)).capabilities.shell) {
          throw const LlmException('This server offers no shell, which the benchmark needs.');
        }
        final provider = benchmarkProvider(id);
        // Kept until the run ends: what polls it, and writes its result.
        final chatId = ctx.chatId;
        _listening[id] ??= c.listen(provider, (prev, next) {
          if (next.active != null || next.isBusy) return;
          _listening.remove(id)?.close();
          final ended = prev?.active;
          if (ended == null) return;
          final r = BenchmarkStore.instance.get(ended.id);
          final server = c.read(serversProvider).servers[id]?.name ?? id;
          unawaited(Chats.notify(
            chatId,
            'The benchmark run ${ended.id} on $server ($id) ended: ${r?.status.name ?? 'unknown'}. '
            'Read it with the benchmark tool.',
          ).catchError((Object e, StackTrace s) => Loggers.app.warning('Benchmark notice', e, s)));
        });
        final options = YabsOptions(
          disk: AskAiCommand.lenientBool(args['disk']) ?? true,
          network: AskAiCommand.lenientBool(args['network']) ?? true,
          cpu: AskAiCommand.lenientBool(args['cpu']) ?? false,
        );
        await c.read(provider.notifier).start(options);
        final st = c.read(provider);
        final active = st.active;
        if (active == null) {
          _listening.remove(id)?.close();
          throw LlmException(st.error ?? 'The benchmark did not start.');
        }
        return LlmToolResult.text(
          'Started run ${active.id}; about ${BenchmarkEstimate(options).minutes} minutes. '
          'Read it later with action read.',
        );
      case 'cancel':
        final provider = benchmarkProvider(id);
        if (c.read(provider).active == null && store.activeFor(id) == null) {
          return LlmToolResult.text('No run in progress.');
        }
        // Kept until the run ends, as for one started here: what polls it to
        // its end. One already kept — this chat's run — is left as it is.
        _listening[id] ??= c.listen(provider, (_, next) {
          if (next.active == null && !next.isBusy) _listening.remove(id)?.close();
        });
        await c.read(provider.notifier).cancel();
        return LlmToolResult.text('Cancelling.');
      default:
        throw const LlmException('action is one of list, read, run, cancel');
    }
  }
}

/// Remote desktop sessions (RDP, VNC) through a server: the profiles read
/// without asking, a session opened or closed with the user's approval.
///
/// Opened with the password the profile keeps, or one the user gave for this
/// session through `ask_user` — a handle the model passes on, traded for the
/// value here ([LlmSecrets]) and never saved. What opens is the Remote desktop tab; the
/// conversation stays in view only as the user left the floating Agent.
final class RemoteDesktopTool extends ToolFunc {
  const RemoteDesktopTool()
    : super(
        name: 'remote_desktop',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['list', 'connect', 'disconnect'],
            },
            'server_id': {'type': 'string', 'description': 'list: one server. Default: every one.'},
            'profile_id': {'type': 'string', 'description': 'connect, disconnect: a profile from list.'},
            'password': {
              'type': 'object',
              'description': 'connect, for a profile that keeps no password: {"secret": "sec_…"} from an ask_user '
                  'secret field. Used for this session only, never saved.',
              'properties': {
                'secret': {'type': 'string'},
              },
            },
          },
          'required': ['action'],
        },
      );

  @override
  String get description =>
      'Remote desktop (RDP, VNC) through the user\'s servers: `list` the saved profiles and which are connected, '
      '`connect` one — the app opens it on the Remote desktop tab for the user — or `disconnect` it. For a profile '
      'that keeps no password, ask the user for it with ask_user (a secret field) and pass what you get as password.';

  @override
  String get l10nName => l10n.remoteDesktop;

  @override
  String get group => AppDataTools.remoteDesktop;

  @override
  String get groupLabel => l10n.remoteDesktop;

  @override
  String? get l10nTip => l10n.agentRemoteDesktopToolsTip;

  @override
  IconData get groupIcon => Icons.desktop_windows_outlined;

  @override
  IconData get icon => Icons.desktop_windows_outlined;

  @override
  String summary(Map<String, Object?> args) => [args['action'], ?_str(args, 'profile_id'), ?_str(args, 'server_id')].join(' · ');

  @override
  LlmApproval? preApprove(Map<String, Object?> args, String chatId) =>
      args['action'] == 'list' ? const LlmApproval.allow() : null;

  static RemoteDesktopProfile _profile(Map<String, Object?> a) {
    final id = _str(a, 'profile_id') ?? (throw const LlmException('profile_id is required'));
    return Stores.remoteDesktop.fetch().firstWhereOrNull((p) => p.id == id) ??
        (throw LlmException('No remote desktop profile $id. List them for their ids.'));
  }

  @override
  Future<LlmToolResult> run(Map<String, Object?> args, ToolCtx ctx) async {
    final c = AgentScope.container;
    switch (args['action']) {
      case 'list':
        final servers = c.read(serversProvider).servers;
        final only = _str(args, 'server_id');
        // Sessions only if there are any: reading it would start the tracker.
        final live = c.exists(remoteDesktopSessionsProvider)
            ? c.read(remoteDesktopSessionsProvider).sessions
            : const <String, RemoteDesktopSessionView>{};
        final profiles = [
          for (final p in Stores.remoteDesktop.fetch())
            if (only == null || p.serverId == only) p,
        ];
        if (profiles.isEmpty) return LlmToolResult.text('No remote desktop profiles.');
        return LlmToolResult.text(jsonEncode([
          for (final p in profiles)
            {
              'id': p.id,
              'name': p.name,
              'server': servers[p.serverId]?.name ?? p.serverId,
              'server_id': p.serverId,
              'protocol': p.protocol.name,
              'address': '${p.host}:${p.port}',
              'password_saved': p.password?.isNotEmpty ?? false,
              'session': ?live[p.id]?.connectionState.name,
            },
        ]));
      case 'connect':
        final p = _profile(args);
        final given = LlmSecrets.take(ctx.chatId, args['password']);
        if (given == null && !(p.password?.isNotEmpty ?? false)) {
          throw const LlmException(
            'This profile keeps no password: ask the user for it with ask_user, a secret field, and pass it as password.',
          );
        }
        if (!c.read(serverProvider(p.serverId)).capabilities.tcpRelay) {
          throw const LlmException('This server cannot relay a connection, which remote desktop needs.');
        }
        c.read(remoteDesktopSessionsProvider.notifier).open(p, sessionPassword: given);
        c.read(homeTabRequestProvider.notifier).go(AppTab.remoteDesktop);
        return LlmToolResult.text('Opening ${p.name} on the Remote desktop tab.');
      case 'disconnect':
        final p = _profile(args);
        // No tracker, no session: nothing to close.
        if (c.exists(remoteDesktopSessionsProvider)) {
          await c.read(remoteDesktopSessionsProvider.notifier).closeForProfile(p.id);
        }
        return LlmToolResult.text('Closed ${p.name}.');
      default:
        throw const LlmException('action is one of list, connect, disconnect');
    }
  }
}
