import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart' hide Provider;
import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/core/utils/adhoc_ssh_prompt.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/core/utils/ssh_exec.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/ai/adhoc_ssh.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

const globalAgentConversationScope = '__global_agent__';
const _maxGlobalAgentShellOutputCharacters = 32000;
const _shellOutputTruncationMarker = '\n\n[... output truncated ...]\n\n';

@visibleForTesting
({String stdout, String stderr, bool truncated}) limitGlobalAgentShellOutput(
  String stdout,
  String stderr, {
  bool stdoutAlreadyTruncated = false,
  bool stderrAlreadyTruncated = false,
  int maxCharacters = _maxGlobalAgentShellOutputCharacters,
}) {
  if (maxCharacters <= 0) {
    return (
      stdout: '',
      stderr: '',
      truncated:
          stdout.isNotEmpty ||
          stderr.isNotEmpty ||
          stdoutAlreadyTruncated ||
          stderrAlreadyTruncated,
    );
  }

  final total = stdout.length + stderr.length;
  final truncated =
      stdoutAlreadyTruncated || stderrAlreadyTruncated || total > maxCharacters;
  if (!truncated) {
    return (stdout: stdout, stderr: stderr, truncated: false);
  }

  String limit(String value, int budget, {required bool force}) {
    if (!force && value.length <= budget) return value;
    if (budget <= 0) return '';
    if (budget <= _shellOutputTruncationMarker.length) {
      return _shellOutputTruncationMarker.substring(0, budget);
    }

    final visibleBudget = budget - _shellOutputTruncationMarker.length;
    final desiredHeadLength = visibleBudget ~/ 2;
    final headLength = desiredHeadLength < value.length
        ? desiredHeadLength
        : value.length;
    final availableTailLength = value.length - headLength;
    final desiredTailLength = visibleBudget - desiredHeadLength;
    final tailLength = desiredTailLength < availableTailLength
        ? desiredTailLength
        : availableTailLength;
    return '${value.substring(0, headLength)}'
        '$_shellOutputTruncationMarker'
        '${value.substring(value.length - tailLength)}';
  }

  final stdoutBudget = stderr.isEmpty
      ? maxCharacters
      : maxCharacters * 11 ~/ 16;
  final stderrBudget = stderr.isEmpty ? 0 : maxCharacters - stdoutBudget;
  return (
    stdout: limit(
      stdout,
      stdoutBudget,
      force: stdoutAlreadyTruncated || stdout.length > stdoutBudget,
    ),
    stderr: limit(
      stderr,
      stderrBudget,
      force: stderrAlreadyTruncated || stderr.length > stderrBudget,
    ),
    truncated: true,
  );
}

final class _BoundedTextAccumulator {
  _BoundedTextAccumulator(this.maxCharacters)
    : assert(maxCharacters > 0),
      _headLimit = maxCharacters ~/ 2,
      _tailLimit = maxCharacters - (maxCharacters ~/ 2);

  final int maxCharacters;
  final int _headLimit;
  final int _tailLimit;
  final StringBuffer _head = StringBuffer();
  final ListQueue<String> _tail = ListQueue<String>();
  int _tailLength = 0;
  int _totalCharacters = 0;

  bool get truncated => _totalCharacters > maxCharacters;

  String get text => '${_head.toString()}${_tail.join()}';

  void add(String chunk) {
    if (chunk.isEmpty) return;
    _totalCharacters += chunk.length;

    var offset = 0;
    final remainingHead = _headLimit - _head.length;
    if (remainingHead > 0) {
      final take = remainingHead < chunk.length ? remainingHead : chunk.length;
      _head.write(chunk.substring(0, take));
      offset = take;
    }
    if (offset < chunk.length) {
      _appendTail(chunk.substring(offset));
    }
  }

  void _appendTail(String value) {
    if (_tailLimit == 0 || value.isEmpty) return;
    if (value.length >= _tailLimit) {
      _tail
        ..clear()
        ..add(value.substring(value.length - _tailLimit));
      _tailLength = _tailLimit;
      return;
    }

    _tail.addLast(value);
    _tailLength += value.length;
    while (_tailLength > _tailLimit) {
      final overflow = _tailLength - _tailLimit;
      final first = _tail.removeFirst();
      if (first.length <= overflow) {
        _tailLength -= first.length;
        continue;
      }
      _tail.addFirst(first.substring(overflow));
      _tailLength -= overflow;
    }
  }
}

const globalAgentToolDefinitions = <AskAiToolDefinition>[
  AskAiToolDefinition(
    name: 'run_shell_command',
    description:
        'Run one complete, non-interactive shell command on a configured '
        'server or on an ad-hoc SSH connection.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'server_id',
        'session_id',
        'command',
        'description',
        'safe_to_run',
      ],
      'properties': {
        'server_id': {
          'type': ['string', 'null'],
          'description':
              'The exact ServerBox server ID from the instructions. Null when '
              'targeting an ad-hoc connection instead.',
        },
        'session_id': {
          'type': ['string', 'null'],
          'description':
              'The id returned by ssh_connect. Null when targeting a '
              'configured server instead. Give exactly one of the two.',
        },
        'command': {
          'type': 'string',
          'description': 'A complete, non-interactive shell command.',
        },
        'description': {
          'type': 'string',
          'description': 'A concise explanation of the action and its risk.',
        },
        'safe_to_run': {
          'type': 'boolean',
          'description':
              'True only for clearly read-only, idempotent, non-destructive commands.',
        },
      },
    },
  ),
  AskAiToolDefinition(
    name: 'read_file',
    description:
        'Read a UTF-8 text file over SFTP, from a configured server or an '
        'ad-hoc SSH connection.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'server_id',
        'session_id',
        'path',
        'description',
        'safe_to_run',
      ],
      'properties': {
        'server_id': {
          'type': ['string', 'null'],
          'description':
              'The exact ServerBox server ID from the instructions. Null when '
              'targeting an ad-hoc connection instead.',
        },
        'session_id': {
          'type': ['string', 'null'],
          'description':
              'The id returned by ssh_connect. Null when targeting a '
              'configured server instead. Give exactly one of the two.',
        },
        'path': {
          'type': 'string',
          'description': 'The absolute remote file path to read.',
        },
        'description': {
          'type': 'string',
          'description': 'Why this file is needed.',
        },
        'safe_to_run': {
          'type': 'boolean',
          'description': 'True because this tool only reads an existing file.',
        },
      },
    },
  ),
  AskAiToolDefinition(
    name: 'write_file',
    description:
        'Replace a UTF-8 text file over SFTP after user review, on a '
        'configured server or an ad-hoc SSH connection.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'server_id',
        'session_id',
        'path',
        'content',
        'description',
        'safe_to_run',
      ],
      'properties': {
        'server_id': {
          'type': ['string', 'null'],
          'description':
              'The exact ServerBox server ID from the instructions. Null when '
              'targeting an ad-hoc connection instead.',
        },
        'session_id': {
          'type': ['string', 'null'],
          'description':
              'The id returned by ssh_connect. Null when targeting a '
              'configured server instead. Give exactly one of the two.',
        },
        'path': {
          'type': 'string',
          'description': 'The absolute remote file path to create or replace.',
        },
        'content': {
          'type': 'string',
          'description': 'The complete UTF-8 content to write.',
        },
        'description': {
          'type': 'string',
          'description': 'What is being changed and why.',
        },
        'safe_to_run': {
          'type': 'boolean',
          'description':
              'Always false because this tool changes a remote file.',
        },
      },
    },
  ),
  AskAiToolDefinition(
    name: 'ssh_connect',
    description:
        'Open an SSH connection to a host that is not configured in the app, '
        'and return an id for it. The app asks the user for the credential '
        'and for host key approval; never ask for one in conversation.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['host', 'port', 'user', 'description', 'safe_to_run'],
      'properties': {
        'host': {
          'type': 'string',
          'description': 'Hostname or IP address to connect to.',
        },
        'port': {'type': 'integer', 'description': 'SSH port, usually 22.'},
        'user': {'type': 'string', 'description': 'The SSH user name.'},
        'description': {
          'type': 'string',
          'description': 'Why this host needs connecting to.',
        },
        'safe_to_run': {
          'type': 'boolean',
          'description':
              'Always false: this reaches a machine the app does not know.',
        },
      },
    },
  ),
  AskAiToolDefinition(
    name: 'ssh_disconnect',
    description: 'Close an ad-hoc SSH connection opened by ssh_connect.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['session_id', 'description', 'safe_to_run'],
      'properties': {
        'session_id': {
          'type': 'string',
          'description': 'The id returned by ssh_connect.',
        },
        'description': {
          'type': 'string',
          'description': 'Why the connection is no longer needed.',
        },
        'safe_to_run': {
          'type': 'boolean',
          'description': 'Always false because this ends a connection.',
        },
      },
    },
  ),
  AskAiToolDefinition(
    name: 'serverbox',
    description:
        'Inspect configured servers, manage their existing ServerBox '
        'connection state, show one to the user, and keep an ad-hoc '
        'connection as a new one.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'action',
        'server_id',
        'session_id',
        'name',
        'monitor_addr',
        'description',
        'safe_to_run',
      ],
      'properties': {
        'action': {
          'type': 'string',
          'enum': [
            'list_servers',
            'get_status',
            'connect',
            'refresh',
            'disconnect',
            'open_server',
            'add_server',
          ],
          'description':
              'The ServerBox operation to perform. open_server moves the app '
              'to that server\'s page so the user can see it; it changes '
              'nothing on the server itself. add_server keeps an ad-hoc '
              'connection as a configured server.',
        },
        'session_id': {
          'type': ['string', 'null'],
          'description':
              'For add_server: the ad-hoc connection to keep, from '
              'ssh_connect. Null for every other action.',
        },
        'name': {
          'type': ['string', 'null'],
          'description':
              'For add_server: a suggested name. The user confirms or changes '
              'it. Null for every other action.',
        },
        'monitor_addr': {
          'type': ['string', 'null'],
          'description':
              'For add_server: the monitor agent\'s base URL if one was '
              'installed, e.g. http://127.0.0.1:3770. Never its credentials — '
              'the app asks the user for those. Null otherwise.',
        },
        'server_id': {
          'type': ['string', 'null'],
          'description':
              'The exact server ID, or null only when listing all servers.',
        },
        'description': {
          'type': 'string',
          'description': 'Why this ServerBox operation is needed.',
        },
        'safe_to_run': {
          'type': 'boolean',
          'description':
              'True only for list_servers and get_status; false for connection changes.',
        },
      },
    },
  ),
];

@immutable
class GlobalAgentServerContext {
  const GlobalAgentServerContext({
    required this.id,
    required this.name,
    required this.connection,
    required this.system,
  });

  final String id;
  final String name;
  final String connection;
  final String system;
}

String buildGlobalAgentInstructions({
  required List<GlobalAgentServerContext> servers,
  String? localeHint,
  bool localExec = false,
}) {
  final prompt = StringBuffer()
    ..writeln('You are the application-wide operations Agent in ServerBox.')
    ..writeln(
      'You work on two kinds of machine, and both can run commands and read or write files: servers the user has configured, listed at the end of these instructions, and any other host you reach yourself with ssh_connect.',
    )
    ..writeln(
      'A host that is not in that list is not out of reach. Do not ask the user to add it first — call ssh_connect with its address and work through the session_id it returns.',
    )
    ..writeln(
      'Name a configured server by its exact ID from the list, never by name, which is descriptive and may not be unique. Name an ad-hoc connection by its session_id. Give a shell or file tool one or the other, never both.',
    )
    ..writeln('Propose exactly one tool call at a time.')
    ..writeln(
      'Every state-changing action requires app review. Never claim a tool ran until its result is provided.',
    )
    ..writeln(
      'Prefer ServerBox state and read-only inspection before changes. Avoid interactive commands and password prompts.',
    )
    ..writeln(
      'Set safe_to_run=true only for read-only, idempotent actions. It must be false for writes and connection changes.',
    )
    ..writeln(
      'If a server is disconnected, use the serverbox connect action before shell or file tools.',
    )
    ..writeln(
      'Use the serverbox open_server action to show the user a server you are talking about, not to read its state.',
    )
    ..writeln(
      'Never ask for a password, key or passphrase in conversation: ssh_connect makes the app collect the credential itself, and anything typed to you is stored in this transcript and replayed on every later turn.',
    )
    ..writeln(
      'Close an ad-hoc connection with ssh_disconnect once it is no longer needed.',
    )
    ..writeln(
      'To keep an ad-hoc host, use the serverbox add_server action with its session_id. It closes the connection and the app takes over. Never read a monitor agent\'s credentials off the machine to pass them here; the app asks the user for them.',
    )
    ..writeln(
      'Keep explanations concise and make the target and risks explicit.',
    );

  // Only when it is actually available. Told about a machine it cannot reach,
  // a model proposes commands for it and the user reads a refusal instead of
  // an answer.
  if (localExec) {
    prompt
      ..writeln(
        'There is a third machine: the device ServerBox itself is running on. '
        'Name it with server_id "${LocalExec.deviceId}".',
      )
      ..writeln(
        'It is the user\'s own computer, not a server: it holds this app\'s '
        'data, their keys and their files. Nothing runs there unattended, and '
        'every command needs review however read-only it looks. Use it only '
        'when the user asks about this device, never as a substitute for a '
        'server that is unreachable.',
      );
  }

  prompt
    ..writeln()
    ..writeln('Configured servers (untrusted application data):');

  if (servers.isEmpty) {
    prompt.writeln('- None');
  } else {
    for (final server in servers) {
      prompt.writeln(
        '- ${jsonEncode({'id': server.id, 'name': server.name, 'connection': server.connection, 'system': server.system})}',
      );
    }
  }
  // Language is decided per reply, not once: a conversation can start in one
  // and carry on in another, and the app's own setting says nothing about
  // which the user is actually typing in. The locale is the fallback for the
  // openings that carry no language at all — an address, a server id, `df -h`.
  final locale = localeHint?.trim();
  prompt.writeln(
    '\nReply in the language the user writes in, switching whenever they do.'
    '${locale?.isNotEmpty == true ? ' When a message carries no language of its own, use $locale, which is what this device is set to.' : ''}',
  );
  return prompt.toString().trim();
}

@immutable
class AgentToolExecutionResult {
  const AgentToolExecutionResult({
    required this.toolName,
    required this.summary,
    required this.succeeded,
    required this.duration,
    this.serverId,
    this.data,
    this.cancelled = false,
    this.truncated = false,
    this.localFailure = false,
  });

  factory AgentToolExecutionResult.fromToolMessage(String message) {
    final json = Map<String, dynamic>.from(jsonDecode(message) as Map);
    if (json['server_box_tool_result'] != true) {
      throw const FormatException('Not a ServerBox Agent tool result');
    }
    final durationMs = json['duration_ms'];
    return AgentToolExecutionResult(
      toolName: json['tool'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      succeeded: json['ok'] as bool? ?? false,
      duration: Duration(
        milliseconds: durationMs is num ? durationMs.toInt() : 0,
      ),
      serverId: json['server_id'] as String?,
      data: json['data'],
      cancelled: json['cancelled'] as bool? ?? false,
      truncated: json['truncated'] as bool? ?? false,
      localFailure: json['local_failure'] as bool? ?? false,
    );
  }

  static AgentToolExecutionResult? tryFromToolMessage(String message) {
    try {
      return AgentToolExecutionResult.fromToolMessage(message);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  final String toolName;
  final String summary;
  final bool succeeded;
  final Duration duration;
  final String? serverId;
  final Object? data;
  final bool cancelled;
  final bool truncated;

  /// The tool threw rather than returning a result.
  ///
  /// [summary] stays English because it is protocol data — the model reads it.
  /// The app has its own line for this case and picks it at render time, which
  /// is the only place that knows what language to use.
  final bool localFailure;

  String toToolMessage() => jsonEncode({
    'server_box_tool_result': true,
    'tool': toolName,
    'ok': succeeded,
    'summary': summary,
    if (serverId != null) 'server_id': serverId,
    'data': data,
    'duration_ms': duration.inMilliseconds,
    'cancelled': cancelled,
    'truncated': truncated,
    'local_failure': localFailure,
  });

  String get displayData {
    final value = data;
    if (value == null) return '';
    if (value is String) return value;
    return const JsonEncoder.withIndent('  ').convert(value);
  }
}

/// A machine a tool call is about, ready to be worked on.
///
/// [exec] is how a command runs there. It is the interface the process,
/// systemd and container pages already use, which is what lets a server
/// reached only over its monitor agent answer at all — it has no `SSHClient`
/// to hand anybody, and asking for one is what used to refuse it.
///
/// [client] is the SSH connection when there is one, and only the file tools
/// need it: SFTP is a byte stream, and there is no equivalent over the agent's
/// HTTP API. Null means those tools have to say so rather than assume.
///
/// [serverId] is null for a connection that is not a configured server — it is
/// what makes a result say "no particular server" rather than name someone
/// else's.
typedef AgentShellHandle = ({
  ServerExec exec,
  SSHClient? client,
  String? serverId,
});

/// Which machine a shell or file tool call is about.
///
/// The three tools that run something take an [AgentShellHandle] and never ask
/// how the connection behind it was reached. That is the whole point of the
/// type: remote execution is not the same thing as "a server in the list", and
/// the tools have stopped assuming it is.
@immutable
sealed class AgentSshTarget {
  const AgentSshTarget();

  /// Reads the target out of a tool call.
  ///
  /// One place, so that a second kind of target is one case here rather than
  /// a condition in each of the three tools that run something.
  ///
  /// Exactly one, never a default: a call naming both is a model that has lost
  /// track of which machine it is on, and picking one of them for it would run
  /// the command somewhere nobody chose.
  factory AgentSshTarget.fromArguments(AskAiCommand proposal) {
    final serverId = proposal.serverId;
    final sessionId = proposal.sessionId;
    if (serverId != null && sessionId != null) {
      throw const FormatException(
        'Name either server_id or session_id, not both',
      );
    }
    if (sessionId != null) return AdHocSessionTarget(sessionId);
    if (serverId == LocalExec.deviceId) return const LocalTarget();
    if (serverId != null) return ConfiguredServerTarget(serverId);
    throw const FormatException('server_id or session_id is required');
  }
}

/// A server the user has configured in the app.
final class ConfiguredServerTarget extends AgentSshTarget {
  const ConfiguredServerTarget(this.serverId);

  final String serverId;
}

/// The machine the app is running on.
///
/// Named through `server_id` rather than a field of its own, so the tools'
/// schema is unchanged and the model has one place to say which machine it
/// means. The reserved id cannot collide with a configured server's — see
/// [LocalExec.deviceId].
final class LocalTarget extends AgentSshTarget {
  const LocalTarget();
}

/// A host connected to for this conversation only.
final class AdHocSessionTarget extends AgentSshTarget {
  const AdHocSessionTarget(this.sessionId);

  final String sessionId;
}

/// What the file tools say when there is no byte stream to carry SFTP.
///
/// Told as a way forward rather than as a refusal: the machine is reachable
/// and `cat` and `tee` are right there, so a model that reads this can finish
/// the job instead of reporting the server unusable.
final _noSftp = StateError(
  'Reading and writing files here needs SFTP, which travels over SSH. This '
  'server is reached only through its monitor agent, which carries no byte '
  'stream. Use run_shell_command instead — `cat path` to read, and a heredoc '
  'into `tee path` to write.',
);

final globalAgentToolServiceProvider = Provider<GlobalAgentToolService>((ref) {
  return GlobalAgentToolService(ref);
});

class GlobalAgentToolService {
  GlobalAgentToolService(this._ref);

  static const _operationTimeout = Duration(minutes: 5);
  static const _sftpTimeout = Duration(seconds: 30);
  static const _maxShellOutputCharacters = _maxGlobalAgentShellOutputCharacters;
  static const _maxReadBytes = 128 * 1024;
  static const _maxWriteBytes = 512 * 1024;
  static int _temporaryFileSequence = 0;

  final Ref _ref;
  /// The signal that stops whatever [_runShell] is waiting on, or null when
  /// nothing is running. Pulled by [cancelCurrent] and by the timeout.
  Completer<void>? _cancelRun;
  bool _cancelRequested = false;

  List<GlobalAgentServerContext> serverContexts() {
    final servers = _ref.read(serversProvider);
    return [
      for (final id in servers.serverOrder)
        if (servers.servers[id] case final spi?)
          GlobalAgentServerContext(
            id: id,
            name: spi.name,
            connection: _ref.read(serverProvider(id)).conn.name,
            system: _ref.read(serverProvider(id)).status.system.name,
          ),
    ];
  }

  String buildInstructions({String? localeHint}) {
    return buildGlobalAgentInstructions(
      servers: serverContexts(),
      localeHint: localeHint,
      // Read now rather than once at start-up: the setting can be turned on
      // mid-conversation, and the instructions are rebuilt per request.
      localExec:
          LocalExec.isSupported && Stores.setting.agentLocalExec.fetch(),
    );
  }

  Future<AgentToolExecutionResult> execute(AskAiCommand proposal) async {
    final watch = Stopwatch()..start();
    _cancelRequested = false;
    try {
      return switch (proposal.toolName) {
        'run_shell_command' => await _runShell(proposal, watch),
        'read_file' => await _readFile(proposal, watch),
        'write_file' => await _writeFile(proposal, watch),
        'ssh_connect' => await _sshConnect(proposal, watch),
        'ssh_disconnect' => _sshDisconnect(proposal, watch),
        'serverbox' => await _runServerBox(proposal, watch),
        _ => throw UnsupportedError(
          'Unsupported Agent tool: ${proposal.toolName}',
        ),
      };
    } finally {
      watch.stop();
    }
  }

  Future<void> cancelCurrent() async {
    _cancelRequested = true;
    final cancel = _cancelRun;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  /// Opens the shell a tool call is about.
  Future<AgentShellHandle> _resolve(AgentSshTarget target) async {
    return switch (target) {
      ConfiguredServerTarget(:final serverId) => await _connectedServer(
        serverId,
      ),
      AdHocSessionTarget(:final sessionId) => _adHocSession(sessionId),
      LocalTarget() => _thisDevice(),
    };
  }

  /// This machine, when the user has said the Agent may work on it.
  ///
  /// Two gates, not one. The platform has to be able to run a command at all —
  /// iOS cannot, and the sandboxed macOS build is the App Store one. And the
  /// user has to have turned it on: a configured server was added on purpose
  /// and is somewhere else, whereas this is where the app's own stores, keys
  /// and keychain are, and adding a server was never consent for that.
  ///
  /// No SSH client, so the file tools say so and point at `cat` and `tee` —
  /// which is the wrong answer here and the next thing to fix; see
  /// local-ssh-plan.md, stage 2b.
  AgentShellHandle _thisDevice() {
    if (!LocalExec.isSupported) {
      throw StateError(
        'This build cannot run commands on the device it is installed on.',
      );
    }
    if (!Stores.setting.agentLocalExec.fetch()) {
      throw StateError(
        'Running commands on this device is turned off. The user can enable '
        'it in ServerBox settings; do not ask again in this conversation if '
        'they decline.',
      );
    }
    // No server id: a result claiming one would name a machine in the list,
    // and this is not one of them.
    return (exec: const LocalExec(), client: null, serverId: null);
  }

  /// An ad-hoc connection that is still open.
  ///
  /// The two failures are told apart on purpose. A conversation restored after
  /// a restart still names session ids that died with the app, and a model
  /// given a bare "not found" tends to retry the same id; told that
  /// connections do not survive, it opens a new one.
  AgentShellHandle _adHocSession(String sessionId) {
    final session = _ref.read(adHocSshSessionsProvider)[sessionId];
    if (session == null) {
      throw StateError(
        'No open connection with id $sessionId. Ad-hoc connections are not '
        'kept across app restarts; open a new one with ssh_connect.',
      );
    }
    if (session.client.isClosed) {
      _ref.read(adHocSshSessionsProvider.notifier).close(sessionId);
      throw StateError(
        'The connection to ${session.label} has closed. Open a new one with '
        'ssh_connect.',
      );
    }
    // No server id: this host is not in the app, and a result claiming one
    // would point at somebody else's server.
    return (
      exec: SshExec(session.client),
      client: session.client,
      serverId: null,
    );
  }

  /// The server, ready to run something.
  ///
  /// Asks the provider how this server runs commands rather than for an
  /// `SSHClient`, because that is the question. A server reached only over its
  /// monitor agent has no client and never will, and demanding one is what
  /// refused it — while every other page in the app had been running commands
  /// on it over the agent's HTTP API for as long as `MonitorExec` has existed.
  ///
  /// The SSH case still connects lazily: a server polled over HTTP holds no
  /// client until something needs a shell, and terminal, SFTP and port
  /// forwarding all reach one through this same path.
  Future<AgentShellHandle> _connectedServer(String serverId) async {
    final state = _server(serverId);
    final existing = state.client;
    if (existing != null && !existing.isClosed) {
      return (
        exec: SshExec(existing),
        client: existing,
        serverId: state.spi.id,
      );
    }

    // Connecting is what raises the host key and keyboard-interactive
    // prompts, and this may be running while the Agent is nowhere on screen.
    // Only on the path that actually connects: a server with a client already
    // open asks nothing, and pulling the shell up on every tool call would
    // override a user who deliberately closed it. A monitor server opens no
    // shell at all, so it does not raise this either.
    if (state.spi.ssh != null) {
      _ref.read(agentShellProvider.notifier).show();
    }

    final ServerExec exec;
    try {
      exec = await _ref.read(serverProvider(state.spi.id).notifier).ensureExec();
    } catch (e) {
      throw StateError('Cannot run commands on ${state.spi.name}: $e');
    }
    // Taken from what was just resolved rather than read back off the
    // provider: a status refresh that failed while this was awaiting drops the
    // client from the state, as does editing or disconnecting the server, and
    // by now the state may hold nothing at all.
    return (
      exec: exec,
      client: exec is SshExec ? exec.client : null,
      serverId: state.spi.id,
    );
  }

  ServerState _server(String? serverId) {
    if (serverId == null || serverId.isEmpty) {
      throw const FormatException('server_id is required');
    }
    if (!_ref.read(serversProvider).servers.containsKey(serverId)) {
      throw StateError('Configured server not found: $serverId');
    }
    return _ref.read(serverProvider(serverId));
  }

  /// The shell a tool call names, opened and ready.
  ///
  /// The one line every tool that runs something starts with, so that where
  /// the connection comes from is decided in exactly one place.
  Future<AgentShellHandle> _shellFor(AskAiCommand proposal) =>
      _resolve(AgentSshTarget.fromArguments(proposal));

  Future<AgentToolExecutionResult> _runShell(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final (:exec, client: _, :serverId) = await _shellFor(proposal);
    final command = proposal.argumentString('command');
    if (command == null) throw const FormatException('command is required');

    final stdoutCapture = _BoundedTextAccumulator(_maxShellOutputCharacters);
    final stderrCapture = _BoundedTextAccumulator(_maxShellOutputCharacters);

    // The signal the stop button and the timeout both pull. It replaces
    // holding the session and killing it from outside: a command no longer
    // has to be an SSH channel for this to work, which is the whole point of
    // going through [ServerExec].
    final cancel = Completer<void>();
    _cancelRun = cancel;
    // Asked for before this one started. The command still has to be sent —
    // there is nothing to stop until it is — so the signal is pre-pulled and
    // the implementation stops it as soon as it can.
    if (_cancelRequested && !cancel.isCompleted) cancel.complete();

    var timedOut = false;
    try {
      final timer = Timer(_operationTimeout, () {
        if (cancel.isCompleted) return;
        timedOut = true;
        _cancelRequested = true;
        cancel.complete();
      });
      final ExecResult result;
      try {
        result = await exec.run(
          command,
          onStdout: stdoutCapture.add,
          onStderr: stderrCapture.add,
          cancel: cancel.future,
        );
      } finally {
        timer.cancel();
      }

      final limited = limitGlobalAgentShellOutput(
        stdoutCapture.text,
        stderrCapture.text,
        // `outputIncomplete` is the drain having been given up on, which is
        // the same thing to a reader as having been cut short.
        stdoutAlreadyTruncated: stdoutCapture.truncated || result.outputIncomplete,
        stderrAlreadyTruncated: stderrCapture.truncated || result.outputIncomplete,
        maxCharacters: _maxShellOutputCharacters,
      );
      return AgentToolExecutionResult(
        toolName: proposal.toolName,
        serverId: serverId,
        summary: timedOut
            ? 'Command timed out.'
            : _cancelRequested
            ? 'Command cancelled.'
            : 'Command exited with code ${result.exitCode ?? -1}.',
        succeeded:
            !_cancelRequested && !timedOut && (result.exitCode ?? -1) == 0,
        duration: watch.elapsed,
        cancelled: _cancelRequested,
        truncated: limited.truncated,
        data: {
          'command': command,
          'exit_code': result.exitCode,
          'stdout': limited.stdout,
          'stderr': limited.stderr,
          'timed_out': timedOut,
        },
      );
    } finally {
      if (identical(_cancelRun, cancel)) _cancelRun = null;
    }
  }

  Future<AgentToolExecutionResult> _readFile(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final (:exec, :client, :serverId) = await _shellFor(proposal);
    final path = proposal.path;
    if (path == null) throw const FormatException('path is required');
    if (exec is LocalExec) return _readLocalFile(proposal, watch, path);
    if (client == null) throw _noSftp;
    SftpClient? sftp;
    SftpFile? file;
    try {
      sftp = await client.sftp().timeout(_sftpTimeout);
      file = await sftp.open(path).timeout(_sftpTimeout);
      final attrs = await file.stat().timeout(_sftpTimeout);
      final size = attrs.size;
      final readLength = size == null
          ? _maxReadBytes + 1
          : size.clamp(0, _maxReadBytes + 1).toInt();
      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in file.read(length: readLength).timeout(_sftpTimeout)) {
        bytes.add(chunk);
      }
      final data = bytes.takeBytes();
      final truncated =
          data.length > _maxReadBytes || (size != null && size > _maxReadBytes);
      final visible = truncated ? data.sublist(0, _maxReadBytes) : data;
      return AgentToolExecutionResult(
        toolName: proposal.toolName,
        serverId: serverId,
        summary: truncated
            ? 'Read the first $_maxReadBytes bytes of $path.'
            : 'Read $path.',
        succeeded: true,
        duration: watch.elapsed,
        truncated: truncated,
        data: {
          'path': path,
          'size_bytes': size,
          'content': utf8.decode(visible, allowMalformed: true),
        },
      );
    } finally {
      await file?.close();
      await sftp?.close();
    }
  }

  /// The same two tools on this device, over `dart:io` instead of SFTP.
  ///
  /// Not `cat` and `tee` through the shell: those would go through the same
  /// review as any other command, and reading a file is not a command. Same
  /// limits as the remote ones, so a model gets one answer whichever machine
  /// it asked about.
  Future<AgentToolExecutionResult> _readLocalFile(
    AskAiCommand proposal,
    Stopwatch watch,
    String path,
  ) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('No such file on this device: $path');
    }
    final size = await file.length();
    final truncated = size > _maxReadBytes;
    // Only what is going to be shown. A log the size of memory is a plausible
    // thing to point this at.
    final data = truncated
        ? await _firstBytes(file, _maxReadBytes)
        : await file.readAsBytes();
    return AgentToolExecutionResult(
      toolName: proposal.toolName,
      serverId: null,
      summary: truncated
          ? 'Read the first $_maxReadBytes bytes of $path on this device.'
          : 'Read $path on this device.',
      succeeded: true,
      duration: watch.elapsed,
      truncated: truncated,
      data: {
        'path': path,
        'size_bytes': size,
        'content': utf8.decode(data, allowMalformed: true),
      },
    );
  }

  Future<Uint8List> _firstBytes(File file, int count) async {
    final handle = await file.open();
    try {
      return await handle.read(count);
    } finally {
      await handle.close();
    }
  }

  Future<AgentToolExecutionResult> _writeLocalFile(
    AskAiCommand proposal,
    Stopwatch watch,
    String path,
    Uint8List bytes,
  ) async {
    if (bytes.length > _maxWriteBytes) {
      throw StateError(
        'File content exceeds the $_maxWriteBytes byte Agent limit.',
      );
    }
    // Written beside the target and moved onto it, the way the remote one is:
    // a write that fails halfway leaves the original file rather than half of
    // a new one.
    final temporary = File('$path.${ShortId.generate()}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(path);
    } catch (_) {
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {
          // Best effort; the failure below is what the caller needs.
        }
      }
      rethrow;
    }
    return AgentToolExecutionResult(
      toolName: proposal.toolName,
      serverId: null,
      summary: 'Wrote ${bytes.length} bytes to $path on this device.',
      succeeded: true,
      duration: watch.elapsed,
      data: {'path': path, 'bytes_written': bytes.length},
    );
  }

  Future<AgentToolExecutionResult> _writeFile(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final (:exec, :client, :serverId) = await _shellFor(proposal);
    final path = proposal.path;
    final content = proposal.arguments['content'];
    if (path == null) throw const FormatException('path is required');
    if (content is! String) throw const FormatException('content is required');
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (exec is LocalExec) {
      return _writeLocalFile(proposal, watch, path, bytes);
    }
    if (client == null) throw _noSftp;
    if (bytes.length > _maxWriteBytes) {
      throw StateError(
        'File content exceeds the $_maxWriteBytes byte Agent limit.',
      );
    }
    SftpClient? sftp;
    SftpFile? file;
    String? temporaryPath;
    try {
      sftp = await client.sftp().timeout(_sftpTimeout);
      final tempPath = _temporaryRemotePath(path);
      temporaryPath = tempPath;
      file = await sftp
          .open(
            tempPath,
            mode:
                SftpFileOpenMode.truncate |
                SftpFileOpenMode.create |
                SftpFileOpenMode.write,
          )
          .timeout(_sftpTimeout);
      final writer = file.write(Stream<Uint8List>.value(bytes));
      await writer.done.timeout(_operationTimeout);
      await file.close();
      file = null;
      await sftp.rename(tempPath, path).timeout(_sftpTimeout);
      temporaryPath = null;
      return AgentToolExecutionResult(
        toolName: proposal.toolName,
        serverId: serverId,
        summary: 'Wrote ${bytes.length} bytes to $path.',
        succeeded: true,
        duration: watch.elapsed,
        data: {'path': path, 'bytes_written': bytes.length},
      );
    } finally {
      try {
        await file?.close();
      } finally {
        if (temporaryPath != null && sftp != null) {
          try {
            await sftp.remove(temporaryPath).timeout(_sftpTimeout);
          } catch (_) {
            // Best-effort cleanup keeps the original write error intact.
          }
        }
        await sftp?.close();
      }
    }
  }

  String _temporaryRemotePath(String path) {
    final slash = path.lastIndexOf('/');
    final backslash = path.lastIndexOf('\\');
    final separator = slash > backslash ? slash : backslash;
    final directory = separator < 0 ? '' : path.substring(0, separator + 1);
    final filename = separator < 0 ? path : path.substring(separator + 1);
    final sequence = _temporaryFileSequence++;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '$directory.$filename.serverbox-agent-$timestamp-$sequence.tmp';
  }

  /// Connects to a host the app does not know about.
  ///
  /// Three things are deliberately not in the model's hands here. The password
  /// is asked for by the app, so it never enters the conversation. The host
  /// key is asked about by [genClient]'s own prompt — this passes no handler
  /// for it, because agreement inside a conversation is not agreement by the
  /// user, and the model has no way to express the latter. And the `Spi` is
  /// given a real id now rather than when the host is saved, so the key the
  /// user accepts is filed where a saved server would look for it.
  Future<AgentToolExecutionResult> _sshConnect(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final host = proposal.argumentString('host');
    final user = proposal.argumentString('user');
    if (host == null) throw const FormatException('host is required');
    if (user == null) throw const FormatException('user is required');
    final rawPort = proposal.arguments['port'];
    final port = rawPort is num ? rawPort.toInt() : 22;
    if (port <= 0 || port > 65535) {
      throw FormatException('port $port is not a port');
    }

    // Before the dialogs, not after: this may be running while the Agent tab
    // is not the one on screen, and a password prompt with no visible sign of
    // what asked for it is a prompt nobody should answer.
    _ref.read(agentShellProvider.notifier).show();

    final credential = await promptAdHocSshCredential(
      user: user,
      host: host,
      port: port,
    );
    if (credential == null) {
      return AgentToolExecutionResult(
        toolName: proposal.toolName,
        summary: 'The user did not provide credentials for $user@$host:$port.',
        succeeded: false,
        cancelled: true,
        duration: watch.elapsed,
        data: {'host': host, 'port': port, 'user': user},
      );
    }

    final spi = AdHocSshSession.spiFor(
      host: host,
      port: port,
      user: user,
      credential: credential,
    );
    String? fingerprint;
    SSHClient? opened;
    try {
      opened = await genClient(
        spi,
        timeout: Duration(seconds: Stores.setting.timeout.fetch()),
        onKeyboardInteractive: KeyboardInteractiveAuth.handle,
        // Wraps rather than replaces the default, which is what writes the
        // key to storage. Only called when the user was actually asked, so a
        // host already known reports no fingerprint.
        onHostKeyAccepted: (storageKey, hex) {
          fingerprint = hex;
          persistHostKeyFingerprint(storageKey, hex);
        },
      );
      // `genClient` hands back a client before it has authenticated; without
      // this a wrong password is a session id that fails on first use.
      await opened.authenticated;
    } catch (e) {
      // The socket is up by the time authentication fails, and nothing else
      // holds this client — it never reached the registry.
      opened?.close();
      throw StateError('Cannot connect to $user@$host:$port: $e');
    }
    final client = opened;

    final session = AdHocSshSession(
      id: ShortId.generate(),
      spi: spi,
      client: client,
      fingerprint: fingerprint,
    );
    _ref.read(adHocSshSessionsProvider.notifier).add(session);
    return AgentToolExecutionResult(
      toolName: proposal.toolName,
      summary: 'Connected to $user@$host:$port.',
      succeeded: true,
      duration: watch.elapsed,
      // The password is not here, and must not be added: this map is written
      // into the conversation and sent back to the model on every later turn.
      data: {
        'session_id': session.id,
        'host': host,
        'port': port,
        'user': user,
        'accepted_host_key': ?fingerprint,
      },
    );
  }

  AgentToolExecutionResult _sshDisconnect(
    AskAiCommand proposal,
    Stopwatch watch,
  ) {
    final sessionId = proposal.sessionId;
    if (sessionId == null) {
      throw const FormatException('session_id is required');
    }
    final session = _ref.read(adHocSshSessionsProvider)[sessionId];
    _ref.read(adHocSshSessionsProvider.notifier).close(sessionId);
    return AgentToolExecutionResult(
      toolName: proposal.toolName,
      // Closing one that has already gone is not a failure — it is the state
      // the call was asking for.
      summary: session == null
          ? 'No connection with id $sessionId was open.'
          : 'Closed the connection to ${session.label}.',
      succeeded: true,
      duration: watch.elapsed,
      data: {'session_id': sessionId},
    );
  }

  /// Keeps an ad-hoc connection as a configured server.
  ///
  /// The `Spi` saved is the one the session has been using, name aside, so the
  /// host key the user accepted at `ssh_connect` stays filed under the same id
  /// and they are not asked about the same machine twice.
  ///
  /// The connection is closed before the server is added rather than handed
  /// over. `addServer` refreshes, which connects; leaving the ad-hoc client
  /// open would mean two SSH connections to one host, one of which nothing
  /// would ever close. The cost is a single reconnect.
  Future<AgentToolExecutionResult> _addServer(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final sessionId = proposal.sessionId;
    if (sessionId == null) {
      throw const FormatException('session_id is required for add_server');
    }
    final session = _ref.read(adHocSshSessionsProvider)[sessionId];
    if (session == null) {
      throw StateError(
        'No open connection with id $sessionId. Ad-hoc connections are not '
        'kept across app restarts; open a new one with ssh_connect.',
      );
    }

    final existing = _ref
        .read(serversProvider)
        .servers
        .values
        .where((spi) => spi.isSameAs(session.spi))
        .firstOrNull;
    if (existing != null) {
      throw StateError(
        '${session.label} is already configured as "${existing.name}" '
        '(id ${existing.id}). Use that server instead of adding it again.',
      );
    }

    _ref.read(agentShellProvider.notifier).show();
    final saved = await promptSaveAdHocServer(
      suggestedName: proposal.argumentString('name') ?? session.spi.name,
      suggestedMonitorAddr: proposal.argumentString('monitor_addr'),
    );
    if (saved == null) {
      return AgentToolExecutionResult(
        toolName: proposal.toolName,
        summary: 'The user chose not to save ${session.label}.',
        succeeded: false,
        cancelled: true,
        duration: watch.elapsed,
        data: {'session_id': sessionId},
      );
    }

    final monitorAddr = saved.monitorAddr;
    final spi = session.spi.copyWith(
      name: saved.name,
      monitorHttp: monitorAddr == null
          ? null
          : MonitorHttpCredential(
              addr: monitorAddr,
              user: saved.monitorUser,
              pwd: saved.monitorPwd,
            ),
    );

    // The host key the user accepted stays: the saved server carries the same
    // `Spi.id`, and asking about the same machine twice is the one thing this
    // whole id arrangement exists to avoid.
    _ref
        .read(adHocSshSessionsProvider.notifier)
        .close(sessionId, keepHostKey: true);
    _ref.read(serversProvider.notifier).addServer(spi);

    return AgentToolExecutionResult(
      toolName: proposal.toolName,
      serverId: spi.id,
      summary: 'Saved ${session.label} as "${spi.name}".',
      succeeded: true,
      duration: watch.elapsed,
      // No credential of any kind: this is written into the conversation.
      data: {
        'id': spi.id,
        'name': spi.name,
        'session_id': sessionId,
        'session_closed': true,
        'has_monitor': monitorAddr != null,
      },
    );
  }

  Future<AgentToolExecutionResult> _runServerBox(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final action = proposal.action;
    switch (action) {
      case 'list_servers':
        return AgentToolExecutionResult(
          toolName: proposal.toolName,
          summary: 'Listed configured servers.',
          succeeded: true,
          duration: watch.elapsed,
          data: serverContexts()
              .map(
                (server) => {
                  'id': server.id,
                  'name': server.name,
                  'connection': server.connection,
                  'system': server.system,
                },
              )
              .toList(growable: false),
        );
      case 'get_status':
        final state = _server(proposal.serverId);
        return AgentToolExecutionResult(
          toolName: proposal.toolName,
          serverId: state.spi.id,
          summary: 'Read the current ServerBox status for ${state.spi.name}.',
          succeeded: true,
          duration: watch.elapsed,
          data: _statusJson(state),
        );
      case 'connect':
      case 'refresh':
        final state = _server(proposal.serverId);
        // Same reason as the shell path: connecting is what asks about a host
        // key, and the question needs something on screen to have come from.
        _ref.read(agentShellProvider.notifier).show();
        await _ref
            .read(serversProvider.notifier)
            .refresh(spi: state.spi)
            .timeout(_operationTimeout);
        final refreshed = _ref.read(serverProvider(state.spi.id));
        return AgentToolExecutionResult(
          toolName: proposal.toolName,
          serverId: state.spi.id,
          summary: action == 'connect'
              ? 'Connected to ${state.spi.name} and refreshed its status.'
              : 'Refreshed ${state.spi.name}.',
          succeeded: !(refreshed.conn < ServerConn.connected),
          duration: watch.elapsed,
          data: _statusJson(refreshed),
        );
      case 'open_server':
        final state = _server(proposal.serverId);
        // The request is set before the tab switch, not after: a tab that has
        // never been visited does not exist yet, and the one that is about to
        // be built drains this as it appears.
        _ref.read(serverDetailRequestProvider.notifier).go(state.spi.id);
        _ref.read(homeTabRequestProvider.notifier).go(AppTab.server);
        // The conversation comes along, or the page it just opened is the last
        // the user sees of this turn — and whatever the Agent proposes next
        // would be waiting on a tab nobody is looking at.
        _ref.read(agentShellProvider.notifier).show();
        return AgentToolExecutionResult(
          toolName: proposal.toolName,
          serverId: state.spi.id,
          summary: 'Opened ${state.spi.name} in the app.',
          succeeded: true,
          duration: watch.elapsed,
          data: _statusJson(state),
        );
      case 'add_server':
        return await _addServer(proposal, watch);
      case 'disconnect':
        final state = _server(proposal.serverId);
        _ref.read(serversProvider.notifier).closeOneServer(state.spi.id);
        final disconnected = _ref.read(serverProvider(state.spi.id));
        return AgentToolExecutionResult(
          toolName: proposal.toolName,
          serverId: state.spi.id,
          summary: 'Disconnected ${state.spi.name}.',
          succeeded: disconnected.conn == ServerConn.disconnected,
          duration: watch.elapsed,
          data: _statusJson(disconnected),
        );
      default:
        throw FormatException('Unsupported serverbox action: $action');
    }
  }

  Map<String, dynamic> _statusJson(ServerState state) {
    final status = state.status;
    final cpuUsedPercent = _jsonSafePercent(status.cpu.usedPercent());
    final memoryUsedPercent = _jsonSafePercent(status.mem.usedPercent * 100);
    return {
      'id': state.spi.id,
      'name': state.spi.name,
      'connection': state.conn.name,
      'system': status.system.name,
      'cpu_used_percent': cpuUsedPercent,
      'memory_used_percent': memoryUsedPercent,
      'network': {
        'download': status.netSpeed.cachedVals.speedIn,
        'upload': status.netSpeed.cachedVals.speedOut,
      },
      'disks': [
        for (final disk in status.disk)
          {
            'path': disk.path,
            'mount': disk.mount,
            'used_percent': disk.usedPercent,
          },
      ],
      if (status.err != null) 'error': status.err.toString(),
    };
  }

  /// `null` stays `null`: a CPU with no usable sampling window yet has no
  /// reading, and reporting it as 0 would tell the agent the machine is idle.
  double? _jsonSafePercent(num? value) {
    if (value == null) return null;
    final percent = value.toDouble();
    if (!percent.isFinite) return null;
    return double.parse(percent.toStringAsFixed(1));
  }
}
