import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';

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
        'Run one complete, non-interactive shell command on a configured server.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['server_id', 'command', 'description', 'safe_to_run'],
      'properties': {
        'server_id': {
          'type': 'string',
          'description': 'The exact ServerBox server ID from the instructions.',
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
    description: 'Read a UTF-8 text file from a configured server over SFTP.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['server_id', 'path', 'description', 'safe_to_run'],
      'properties': {
        'server_id': {
          'type': 'string',
          'description': 'The exact ServerBox server ID from the instructions.',
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
        'Replace a UTF-8 text file on a configured server over SFTP after user review.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'server_id',
        'path',
        'content',
        'description',
        'safe_to_run',
      ],
      'properties': {
        'server_id': {
          'type': 'string',
          'description': 'The exact ServerBox server ID from the instructions.',
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
    name: 'serverbox',
    description:
        'Inspect configured servers and manage their existing ServerBox connection state.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['action', 'server_id', 'description', 'safe_to_run'],
      'properties': {
        'action': {
          'type': 'string',
          'enum': [
            'list_servers',
            'get_status',
            'connect',
            'refresh',
            'disconnect',
          ],
          'description': 'The ServerBox operation to perform.',
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
}) {
  final prompt = StringBuffer()
    ..writeln('You are the application-wide operations Agent in ServerBox.')
    ..writeln(
      'You can inspect and operate configured servers with ServerBox, shell, and remote file tools.',
    )
    ..writeln(
      'Use only exact server IDs listed below. Server names are descriptive and may not be unique.',
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
      'Keep explanations concise and make the target and risks explicit.',
    )
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
  if (localeHint?.trim().isNotEmpty == true) {
    prompt.writeln(
      '\nReply in the user interface language: ${localeHint!.trim()}.',
    );
  }
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
  });

  String get displayData {
    final value = data;
    if (value == null) return '';
    if (value is String) return value;
    return const JsonEncoder.withIndent('  ').convert(value);
  }
}

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
  SSHSession? _activeSession;
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
    final session = _activeSession;
    if (session == null) return;
    try {
      session.kill(SSHSignal.KILL);
    } catch (_) {
      // The session may already have exited.
    } finally {
      session.close();
    }
    try {
      await session.done;
    } catch (_) {
      // Best-effort cancellation.
    }
  }

  /// The server, with a shell open on it.
  ///
  /// Opens one if there is none. A server reached over its monitor agent's
  /// HTTP API holds no SSH client until something needs a shell — that is the
  /// point of polling over HTTP — so demanding an existing client meant every
  /// command on such a server failed, and the `connect` action the error told
  /// the model to use refreshes status over HTTP without producing one, so the
  /// retry failed the same way. Terminal, SFTP and port forwarding all reach a
  /// shell through this same lazy path.
  Future<({ServerState state, SSHClient client})> _connectedServer(
    String? serverId,
  ) async {
    final state = _server(serverId);
    final existing = state.client;
    if (existing != null && !existing.isClosed) {
      return (state: state, client: existing);
    }

    if (state.spi.ssh == null) {
      throw StateError(
        'Server ${state.spi.name} has no SSH credential, so it cannot run '
        'commands. It reports status over its monitor agent only.',
      );
    }

    final SSHClient client;
    try {
      client = await _ref
          .read(serverProvider(state.spi.id).notifier)
          .ensureShellClient();
    } catch (e) {
      throw StateError('Cannot open a shell on ${state.spi.name}: $e');
    }
    // The client that was just connected, not whatever the provider holds by
    // now: a status refresh that failed while this was awaiting drops the
    // client from the state, as does editing or disconnecting the server, and
    // re-reading it then hands back a state whose `client` is null for the
    // caller to assert on.
    return (state: _ref.read(serverProvider(state.spi.id)), client: client);
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

  Future<AgentToolExecutionResult> _runShell(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final (:state, :client) = await _connectedServer(proposal.serverId);
    final command = proposal.argumentString('command');
    if (command == null) throw const FormatException('command is required');
    final session = await client.execute(command);
    _activeSession = session;
    final stdoutCapture = _BoundedTextAccumulator(_maxShellOutputCharacters);
    final stderrCapture = _BoundedTextAccumulator(_maxShellOutputCharacters);
    final stdoutFuture = const Utf8Decoder(
      allowMalformed: true,
    ).bind(session.stdout).forEach(stdoutCapture.add);
    final stderrFuture = const Utf8Decoder(
      allowMalformed: true,
    ).bind(session.stderr).forEach(stderrCapture.add);
    if (_cancelRequested) await cancelCurrent();

    var timedOut = false;
    var stdoutDrainTimedOut = false;
    var stderrDrainTimedOut = false;
    try {
      try {
        await session.done.timeout(_operationTimeout);
      } on TimeoutException {
        timedOut = true;
        await cancelCurrent();
      }
      await stdoutFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () => stdoutDrainTimedOut = true,
      );
      await stderrFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () => stderrDrainTimedOut = true,
      );
      final limited = limitGlobalAgentShellOutput(
        stdoutCapture.text,
        stderrCapture.text,
        stdoutAlreadyTruncated: stdoutCapture.truncated || stdoutDrainTimedOut,
        stderrAlreadyTruncated: stderrCapture.truncated || stderrDrainTimedOut,
        maxCharacters: _maxShellOutputCharacters,
      );
      return AgentToolExecutionResult(
        toolName: proposal.toolName,
        serverId: state.spi.id,
        summary: timedOut
            ? 'Command timed out.'
            : _cancelRequested
            ? 'Command cancelled.'
            : 'Command exited with code ${session.exitCode ?? -1}.',
        succeeded:
            !_cancelRequested && !timedOut && (session.exitCode ?? -1) == 0,
        duration: watch.elapsed,
        cancelled: _cancelRequested,
        truncated: limited.truncated,
        data: {
          'command': command,
          'exit_code': session.exitCode,
          'stdout': limited.stdout,
          'stderr': limited.stderr,
          'timed_out': timedOut,
        },
      );
    } finally {
      if (identical(_activeSession, session)) _activeSession = null;
    }
  }

  Future<AgentToolExecutionResult> _readFile(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final (:state, :client) = await _connectedServer(proposal.serverId);
    final path = proposal.path;
    if (path == null) throw const FormatException('path is required');
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
        serverId: state.spi.id,
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

  Future<AgentToolExecutionResult> _writeFile(
    AskAiCommand proposal,
    Stopwatch watch,
  ) async {
    final (:state, :client) = await _connectedServer(proposal.serverId);
    final path = proposal.path;
    final content = proposal.arguments['content'];
    if (path == null) throw const FormatException('path is required');
    if (content is! String) throw const FormatException('content is required');
    final bytes = Uint8List.fromList(utf8.encode(content));
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
        serverId: state.spi.id,
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
