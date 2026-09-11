import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:server_box/core/utils/local_exec.dart';

/// API protocol used for one Agent conversation.
enum AskAiProtocol {
  auto,
  chatCompletions,
  responses;

  /// What the vendor calls it, or null for [auto], which is a word rather
  /// than a name and belongs to whoever is displaying it.
  ///
  /// Not localised: these are two OpenAI API surfaces, spelled this way in
  /// every language's documentation. A translated one is a word nobody could
  /// search for.
  ///
  /// On the enum rather than at the two call sites, which had the same switch
  /// written out twice.
  String? get vendorName => switch (this) {
    AskAiProtocol.auto => null,
    AskAiProtocol.chatCompletions => 'Chat Completions',
    AskAiProtocol.responses => 'Responses',
  };
}

AskAiProtocol parseAskAiProtocol(Object? value) {
  final name = value?.toString();
  return AskAiProtocol.values.firstWhere(
    (protocol) => protocol.name == name,
    orElse: () => AskAiProtocol.auto,
  );
}

enum AskAiMessageRole { user, assistant }

/// Protocol-neutral item stored in an Agent conversation.
///
/// Chat Completions codecs regroup adjacent assistant messages and function
/// calls into a single message. Responses codecs replay the typed output items
/// directly, including encrypted reasoning data when it is available.
@immutable
sealed class AskAiConversationItem {
  const AskAiConversationItem();

  String get persistenceKind;
  int get estimatedCharacters;
  Map<String, dynamic> toJson();

  static AskAiConversationItem? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    return switch (json['kind']) {
      'message' => AskAiMessageItem.fromJson(json),
      'function_call' => AskAiFunctionCallItem.fromJson(json),
      'function_output' => AskAiFunctionOutputItem.fromJson(json),
      'reasoning' => AskAiReasoningItem.fromJson(json),
      'raw_response' => AskAiRawResponseItem.fromJson(json),
      'summary' => AskAiSummaryItem.fromJson(json),
      _ => null,
    };
  }
}

@immutable
class AskAiMessageItem extends AskAiConversationItem {
  const AskAiMessageItem({
    required this.role,
    required this.content,
    this.reasoningContent,
    this.rawResponseItem,
  });

  const AskAiMessageItem.user(String content)
    : this(role: AskAiMessageRole.user, content: content);

  const AskAiMessageItem.assistant(
    String content, {
    String? reasoningContent,
    Map<String, dynamic>? rawResponseItem,
  }) : this(
         role: AskAiMessageRole.assistant,
         content: content,
         reasoningContent: reasoningContent,
         rawResponseItem: rawResponseItem,
       );

  factory AskAiMessageItem.fromJson(Map<String, dynamic> json) {
    return AskAiMessageItem(
      role: AskAiMessageRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => AskAiMessageRole.user,
      ),
      content: json['content'] as String? ?? '',
      reasoningContent: json['reasoning_content'] as String?,
      rawResponseItem: _mapOrNull(json['raw_response_item']),
    );
  }

  final AskAiMessageRole role;
  final String content;
  final String? reasoningContent;
  final Map<String, dynamic>? rawResponseItem;

  @override
  String get persistenceKind => 'message';

  @override
  int get estimatedCharacters =>
      content.length + (reasoningContent?.length ?? 0);

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'role': role.name,
    'content': content,
    if (reasoningContent?.isNotEmpty == true)
      'reasoning_content': reasoningContent,
    if (rawResponseItem != null) 'raw_response_item': rawResponseItem,
  };
}

@immutable
class AskAiFunctionCallItem extends AskAiConversationItem {
  const AskAiFunctionCallItem({
    required this.command,
    this.responseItemId,
    this.rawResponseItem,
  });

  factory AskAiFunctionCallItem.fromJson(Map<String, dynamic> json) {
    return AskAiFunctionCallItem(
      command: AskAiCommand.fromJson(
        Map<String, dynamic>.from(json['command'] as Map? ?? const {}),
      ),
      responseItemId: json['response_item_id'] as String?,
      rawResponseItem: _mapOrNull(json['raw_response_item']),
    );
  }

  final AskAiCommand command;
  final String? responseItemId;
  final Map<String, dynamic>? rawResponseItem;

  @override
  String get persistenceKind => 'function_call';

  @override
  int get estimatedCharacters =>
      command.rawArguments.length + command.description.length;

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'command': command.toJson(),
    if (responseItemId != null) 'response_item_id': responseItemId,
    if (rawResponseItem != null) 'raw_response_item': rawResponseItem,
  };
}

@immutable
class AskAiFunctionOutputItem extends AskAiConversationItem {
  const AskAiFunctionOutputItem({required this.callId, required this.output});

  factory AskAiFunctionOutputItem.fromJson(Map<String, dynamic> json) {
    return AskAiFunctionOutputItem(
      callId: json['call_id'] as String? ?? '',
      output: json['output'] as String? ?? '',
    );
  }

  final String callId;
  final String output;

  @override
  String get persistenceKind => 'function_output';

  @override
  int get estimatedCharacters => output.length;

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'call_id': callId,
    'output': output,
  };
}

@immutable
class AskAiReasoningItem extends AskAiConversationItem {
  const AskAiReasoningItem({required this.rawResponseItem, this.summaryText});

  factory AskAiReasoningItem.fromJson(Map<String, dynamic> json) {
    return AskAiReasoningItem(
      rawResponseItem: _mapOrNull(json['raw_response_item']) ?? const {},
      summaryText: json['summary_text'] as String?,
    );
  }

  final Map<String, dynamic> rawResponseItem;
  final String? summaryText;

  @override
  String get persistenceKind => 'reasoning';

  @override
  int get estimatedCharacters =>
      jsonEncode(rawResponseItem).length + (summaryText?.length ?? 0);

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'raw_response_item': rawResponseItem,
    if (summaryText?.isNotEmpty == true) 'summary_text': summaryText,
  };
}

/// Preserves output item types not yet rendered by ServerBox.
@immutable
class AskAiRawResponseItem extends AskAiConversationItem {
  const AskAiRawResponseItem({required this.rawResponseItem});

  factory AskAiRawResponseItem.fromJson(Map<String, dynamic> json) {
    return AskAiRawResponseItem(
      rawResponseItem: _mapOrNull(json['raw_response_item']) ?? const {},
    );
  }

  final Map<String, dynamic> rawResponseItem;

  @override
  String get persistenceKind => 'raw_response';

  @override
  int get estimatedCharacters => jsonEncode(rawResponseItem).length;

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'raw_response_item': rawResponseItem,
  };
}

/// What the turns before it amounted to, written by the model.
///
/// Stored *beside* the items it stands for, never in place of them. The
/// timeline the user reads is replayed from this same list, and a conversation
/// that deleted its own history to save room would be a worse fault than the
/// one this exists to fix. Only a request substitutes it: everything before
/// the newest summary is left out and the summary goes instead.
///
/// Which means the position in the list is the whole of the bookkeeping. There
/// is no range to record and nothing to keep in step — a second summary covers
/// the first the same way it covers everything else behind it.
@immutable
class AskAiSummaryItem extends AskAiConversationItem {
  const AskAiSummaryItem({required this.summary, this.coveredItems = 0});

  factory AskAiSummaryItem.fromJson(Map<String, dynamic> json) {
    final covered = json['covered_items'];
    return AskAiSummaryItem(
      summary: json['summary'] as String? ?? '',
      coveredItems: covered is num ? covered.toInt() : 0,
    );
  }

  final String summary;

  /// How many items went into it. Shown to the reader, and used by nothing —
  /// see the note above about position being the bookkeeping.
  final int coveredItems;

  @override
  String get persistenceKind => 'summary';

  @override
  int get estimatedCharacters => summary.length;

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'summary': summary,
    'covered_items': coveredItems,
  };
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

/// How much of a command the local check could actually establish.
///
/// An allowlist, not a blocklist: [readOnly] is the only verdict that says
/// something positive about the command. [unknown] is what nothing matched —
/// which is a reason to withhold auto-running, and not a claim about what the
/// command does. Saying "changes the system" there contradicts the model's own
/// description of a `sleep`, and the contradiction is the app's fault.
///
/// [unvettedHost] is the same withholding for an unrelated reason: the command
/// was recognised as read-only and the *host* is what nobody has accepted yet.
/// A value of its own rather than a flag beside [unknown], so a badge can read
/// the verdict and say what it means — two causes under one name is how the
/// contradiction above happened in the first place.
///
/// Never serialised: [AskAiCommand.risk] is computed from the call every time,
/// so adding a value here migrates nothing.
enum AskAiCommandRisk { readOnly, unknown, unvettedHost, caution, destructive }

/// Protocol-neutral function tool definition used by both Chat Completions and
/// Responses requests.
@immutable
class AskAiToolDefinition {
  const AskAiToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  static const runShellCommand = AskAiToolDefinition(
    name: 'run_shell_command',
    description:
        'Propose one non-interactive shell command to run on the current SSH server.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['command', 'description', 'safe_to_run', 'destructive'],
      'properties': {
        'command': {
          'type': 'string',
          'description': 'A complete, non-interactive shell command.',
        },
        'description': {
          'type': 'string',
          'description':
              'A concise explanation of the command and any relevant risk.',
        },
        'safe_to_run': {
          'type': 'boolean',
          'description':
              'True only for clearly read-only, idempotent, non-destructive commands.',
        },
        'destructive': {
          'type': 'boolean',
          'description':
              'True when running this could lose data or take a service down: '
              'deleting, overwriting, formatting, killing, rebooting, or '
              'anything else that cannot simply be undone. The app has its own '
              'list of such commands and asks when either of you says so, so '
              'say so for what a list cannot see — a path that matters, a '
              'script whose name says nothing about what it does.',
        },
      },
    },
  );

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toRequestJson(AskAiProtocol protocol) {
    final definition = <String, dynamic>{
      'name': name,
      'description': description,
      'parameters': parameters,
    };
    return protocol == AskAiProtocol.responses
        ? {'type': 'function', ...definition, 'strict': true}
        : {'type': 'function', 'function': definition};
  }
}

/// A command proposal returned by the AI tool call.
@immutable
class AskAiCommand {
  const AskAiCommand({
    required this.command,
    this.id = 'run-shell-command',
    this.description = '',
    this.toolName = 'run_shell_command',
    this.rawArguments = '',
    this.modelSafeToRun = false,
    this.modelDestructive = false,
  });

  factory AskAiCommand.fromJson(Map<String, dynamic> json) {
    return AskAiCommand(
      id: json['id'] as String? ?? 'run-shell-command',
      command: json['command'] as String? ?? '',
      description: json['description'] as String? ?? '',
      toolName: json['tool_name'] as String? ?? 'run_shell_command',
      rawArguments: json['raw_arguments'] as String? ?? '',
      modelSafeToRun: json['model_safe_to_run'] as bool? ?? false,
      // Absent in every conversation written before the field existed, and
      // false is what those calls were treated as at the time.
      modelDestructive: json['model_destructive'] as bool? ?? false,
    );
  }

  final String id;
  final String command;
  final String description;
  final String toolName;
  final String rawArguments;

  /// This is advisory only. Local risk classification must also consider the
  /// command safe before the app may auto-run it.
  final bool modelSafeToRun;

  /// The model's own answer to "would this destroy something".
  ///
  /// Not the opposite of [modelSafeToRun], and not redundant with it. That one
  /// is a floor — it withholds auto-running, and most commands that change
  /// anything set it false — while this one is a ceiling, and asks. Between
  /// them sits everything ordinary: `mkdir`, `systemctl restart`, a package
  /// install. Reading `!modelSafeToRun` as "dangerous" would put a
  /// confirmation in front of all of those and teach people to tap through it.
  ///
  /// Taken together with [classifyRisk] rather than instead of it: the local
  /// list sees a shape, `rm -rf /var/lib/postgresql`, and the model sees what
  /// it is about to do to a machine it has been reading for several turns.
  /// Either one is enough — see [risk].
  final bool modelDestructive;

  Map<String, dynamic> get arguments {
    if (rawArguments.isEmpty) return const {};
    try {
      final value = jsonDecode(rawArguments);
      return value is Map ? Map<String, dynamic>.from(value) : const {};
    } on FormatException {
      return const {};
    } on TypeError {
      return const {};
    }
  }

  String? argumentString(String name) {
    final value = arguments[name];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String? get serverId => argumentString('server_id');

  /// The ad-hoc SSH connection this call is about, if it is about one rather
  /// than about a configured server.
  String? get sessionId => argumentString('session_id');

  String? get path => argumentString('path');

  String? get action => argumentString('action');

  String get displayValue => switch (toolName) {
    'read_file' || 'write_file' => path ?? command,
    'serverbox' => action ?? command,
    'ssh_connect' => _sshTarget ?? command,
    'ssh_disconnect' => sessionId ?? command,
    _ => command,
  };

  String? get _sshTarget {
    final host = argumentString('host');
    if (host == null) return null;
    final user = argumentString('user');
    final port = arguments['port'];
    final portSuffix = port is num ? ':${port.toInt()}' : '';
    return '${user == null ? '' : '$user@'}$host$portSuffix';
  }

  /// What the call would be worth on a machine the user has already accepted:
  /// a property of the call itself, and nothing to do with where it runs.
  AskAiCommandRisk get intrinsicRisk => switch (toolName) {
    'read_file' => AskAiCommandRisk.readOnly,
    'write_file' => AskAiCommandRisk.caution,
    // Reaching a machine nobody has vetted, with credentials, is the most
    // consequential thing the Agent can propose — whatever it plans to do
    // there afterwards.
    'ssh_connect' => AskAiCommandRisk.destructive,
    'ssh_disconnect' => AskAiCommandRisk.caution,
    'serverbox' => switch (action) {
      'list_servers' || 'get_status' => AskAiCommandRisk.readOnly,
      _ => AskAiCommandRisk.caution,
    },
    _ => classifyRisk(command),
  };

  /// Only the tools that name a machine are floored.
  ///
  /// `serverbox` acts on the app — listing its servers, opening a page — and
  /// carries a `session_id` for `add_server` without running anything on that
  /// host, so flooring it labelled app-level calls "unvetted host". The floor
  /// belongs to the tools whose risk is a question of where they run.
  static const _targetedTools = {
    'run_shell_command',
    'read_file',
    'write_file',
  };

  /// What the app asks about, decided by two readers that answer separately.
  ///
  /// [classifyRisk] matches a shape and knows nothing about the machine;
  /// [modelDestructive] is the model's own reading of a call it has context
  /// for and no pattern would catch. Either one saying so is enough, because
  /// the cost of asking is a tap and the cost of not asking is whatever the
  /// command does — there is no argument for making them agree first.
  AskAiCommandRisk get risk {
    final local = _targetedTools.contains(toolName)
        ? _unvettedFloor(intrinsicRisk)
        : intrinsicRisk;
    return modelDestructive ? AskAiCommandRisk.destructive : local;
  }

  /// Nothing runs unattended on a host met this conversation.
  ///
  /// Auto-running is a convenience for machines already accepted into the app;
  /// on one the user has only just handed a password to, a read-only command
  /// still deserves the half-second it takes to look at it.
  ///
  /// Lifts to [AskAiCommandRisk.unvettedHost], which is neither a claim about
  /// the command nor a shrug: the command really is read-only, and the host is
  /// what has not been vetted. `caution` would say "changes the system" over a
  /// command the model has just described as not doing that, and `unknown`
  /// would say nothing was recognised when something was. All the lift does is
  /// withhold [canAutoRun].
  AskAiCommandRisk _unvettedFloor(AskAiCommandRisk risk) {
    if (sessionId == null) return risk;
    return risk == AskAiCommandRisk.readOnly
        ? AskAiCommandRisk.unvettedHost
        : risk;
  }

  /// Never on this device, whatever the command looks like.
  ///
  /// `askAiAutoRunSafeCommands` is a convenience for machines the user added
  /// on purpose and that are somewhere else. This one holds the app's own
  /// stores, the user's keys and their files, and a read-only command there is
  /// still a command they did not see.
  bool get onThisDevice => serverId == LocalExec.deviceId;

  bool get canAutoRun =>
      modelSafeToRun && risk == AskAiCommandRisk.readOnly && !onThisDevice;

  Map<String, dynamic> toJson() => {
    'id': id,
    'command': command,
    'description': description,
    'tool_name': toolName,
    'raw_arguments': rawArguments,
    'model_safe_to_run': modelSafeToRun,
    'model_destructive': modelDestructive,
  };

  Map<String, dynamic> toToolCallJson() {
    final arguments = rawArguments.isNotEmpty
        ? rawArguments
        : jsonEncode({
            'command': command,
            'description': description,
            'safe_to_run': modelSafeToRun,
            'destructive': modelDestructive,
          });
    return {
      'id': id,
      'type': 'function',
      'function': {'name': toolName, 'arguments': arguments},
    };
  }

  Map<String, dynamic> toResponsesFunctionCallJson({String? itemId}) {
    final arguments = rawArguments.isNotEmpty
        ? rawArguments
        : jsonEncode({
            'command': command,
            'description': description,
            'safe_to_run': modelSafeToRun,
            'destructive': modelDestructive,
          });
    return {
      if (itemId != null && itemId.isNotEmpty) 'id': itemId,
      'type': 'function_call',
      'call_id': id,
      'name': toolName,
      'arguments': arguments,
    };
  }

  @visibleForTesting
  static AskAiCommandRisk classifyRisk(String command) {
    var normalized = command.trim().toLowerCase();
    if (normalized.isEmpty) return AskAiCommandRisk.caution;

    // Read-only inspection commands commonly silence expected errors. Ignore
    // only these exact redirections before checking for writes.
    normalized = normalized.replaceAll(
      RegExp(r'\b[012]?>>?\s*/dev/null\b'),
      '',
    );

    final destructivePatterns = <RegExp>[
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?rm\s'),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?(shred|wipefs|mkfs(\.[a-z0-9]+)?)\b'),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?dd\s+.*\bof='),
      RegExp(r'\b(find|xargs)\b.*\b-delete\b'),
      RegExp(r'\b(find|xargs)\b.*\brm\b'),
      RegExp(r'\b(git\s+reset\s+--hard|git\s+clean\s+-[^\s]*f)\b'),
      RegExp(r'\b(docker|podman)\s+(system\s+)?prune\b'),
      RegExp(r'\bkubectl\s+delete\b'),
      RegExp(r'\b(drop|truncate)\s+(database|table)\b'),
      RegExp(r'\bdelete\s+from\b'),
      RegExp(r'(^|[;&|]\s*)(shutdown|reboot|poweroff|halt)\b'),
      RegExp(r'\b(remove-item|format-volume|clear-disk)\b'),
      RegExp(r'(^|[;&|]\s*)(del|rmdir)\s'),
      RegExp(r':\s*\(\s*\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:'),
    ];
    if (destructivePatterns.any((pattern) => pattern.hasMatch(normalized))) {
      return AskAiCommandRisk.destructive;
    }

    final mutatingPatterns = <RegExp>[
      RegExp(r'(^|[^<])>>?\s*[^&]'),
      RegExp(
        r'\|\s*(sudo\s+)?(sh|bash|zsh|fish|python\d*|perl|ruby|node|pwsh|powershell|cmd)\b',
      ),
      RegExp(r'(^|[;&|]\s*)(eval|source)\b|(^|[;&|]\s*)\.\s+'),
      RegExp(r'\$\(|`'),
      RegExp(r'(^|[;&|]\s*)(sh|bash|zsh|fish)\s+-c\b'),
      RegExp(r'\bfind\b.*\s-exec(dir)?\b'),
      RegExp(r'\bawk\b.*\bsystem\s*\('),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?(mv|cp|touch|mkdir|chmod|chown|ln)\s'),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?tee\b'),
      RegExp(r'\bsed\s+[^;&|]*\s-i([.\s]|$)'),
      RegExp(
        r'\b(systemctl|service)\s+(start|stop|restart|reload|enable|disable|mask|unmask)\b',
      ),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?(kill|pkill|killall)\b'),
      RegExp(
        r'\b(apt|apt-get|dnf|yum|pacman|zypper|apk|brew)\s+(install|remove|erase|upgrade|update)\b',
      ),
      RegExp(
        r'\b(docker|podman)\s+(start|stop|restart|rm|rmi|pull|push|build|run|exec)\b',
      ),
      RegExp(r'\b(docker|podman)\s+compose\s+(up|down|restart|pull|build)\b'),
      RegExp(
        r'\bkubectl\s+(apply|create|edit|patch|replace|scale|rollout|set)\b',
      ),
      RegExp(
        r'\bgit\s+(add|commit|push|pull|merge|rebase|checkout|switch|restore|tag)\b',
      ),
      RegExp(
        r'\b(curl|wget)\b.*\s(-o|--output|-x\s+(post|put|patch|delete)|--request\s+(post|put|patch|delete))\b',
      ),
      RegExp(
        r'\b(set-content|add-content|new-item|copy-item|move-item|rename-item|start-service|stop-service|restart-service)\b',
      ),
    ];
    if (mutatingPatterns.any((pattern) => pattern.hasMatch(normalized))) {
      return AskAiCommandRisk.caution;
    }

    final readOnlyStarts = <RegExp>[
      RegExp(r'^(ls|pwd|whoami|id|groups|uname|hostname|uptime|date|cal)\b'),
      RegExp(
        r'^(cat|head|tail|less|more|grep|egrep|fgrep|rg|awk|cut|sort|uniq|wc|tr|sed\s+(?!.*\s-i))\b',
      ),
      RegExp(
        r'^(df|du|free|vmstat|iostat|mpstat|top|ps|pgrep|lsof|stat|file|readlink|realpath)\b',
      ),
      RegExp(r'^(find|locate|which|whereis|type|command\s+-v)\b'),
      RegExp(
        r'^(ip|ss|netstat|ifconfig|route|ping|traceroute|tracepath|dig|nslookup|host)\b',
      ),
      RegExp(
        r'^(journalctl|dmesg|systemctl\s+(status|show|is-active|is-enabled|list-)|service\s+[^\s]+\s+status)\b',
      ),
      RegExp(
        r'^(docker|podman)\s+(ps|images|inspect|logs|stats|info|version)\b',
      ),
      RegExp(r'^(docker|podman)\s+compose\s+(ps|logs|config|ls)\b'),
      RegExp(
        r'^kubectl\s+(get|describe|logs|api-resources|api-versions|cluster-info|version)\b',
      ),
      RegExp(
        r'^git\s+(status|diff|log|show|branch|remote|rev-parse|ls-files|ls-tree)\b',
      ),
      RegExp(
        r'^(get-[a-z0-9-]+|test-[a-z0-9-]+|select-[a-z0-9-]+|where-object|measure-object|compare-object|tasklist|systeminfo|dir|type)\b',
      ),
    ];

    bool isReadOnlySegment(String segment) {
      final stripped = segment
          .trim()
          .replaceFirst(RegExp(r'^sudo\s+'), '')
          .replaceFirst(RegExp(r'^(env\s+)?([a-z_][a-z0-9_]*=[^\s]+\s+)+'), '');
      return readOnlyStarts.any((pattern) => pattern.hasMatch(stripped));
    }

    // Chained commands are not taken apart, so nothing can be established
    // about them — including that they change anything. `ls && pwd` is as
    // unanalysed here as `ls && rm -rf /`, and only the first of those two
    // would be a lie to call a system change.
    final chainCandidate = normalized.replaceAll(RegExp(r'\d*>&\d+'), '');
    if (RegExp(r'&&|\|\||[;\r\n]|&').hasMatch(chainCandidate)) {
      return AskAiCommandRisk.unknown;
    }

    final pipelineSegments = normalized.split('|');
    if (pipelineSegments.every(
      (segment) => segment.trim().isNotEmpty && isReadOnlySegment(segment),
    )) {
      return AskAiCommandRisk.readOnly;
    }
    // Matched nothing at all — not a known mutation, not a known read. `sleep`
    // lands here, and so does anything the lists have never heard of.
    return AskAiCommandRisk.unknown;
  }
}

@immutable
class AskAiCommandResult {
  const AskAiCommandResult({
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.exitCode,
    this.cancelled = false,
    this.timedOut = false,
    this.truncated = false,
  });

  static AskAiCommandResult? tryFromToolMessage(
    String message, {
    required String fallbackCommand,
  }) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(message) as Map);
      if (!json.containsKey('stdout') && !json.containsKey('stderr')) {
        return null;
      }
      final exitCode = json['exit_code'];
      final durationMs = json['duration_ms'];
      return AskAiCommandResult(
        command: json['command'] as String? ?? fallbackCommand,
        exitCode: exitCode is num ? exitCode.toInt() : null,
        stdout: json['stdout'] as String? ?? '',
        stderr: json['stderr'] as String? ?? '',
        duration: Duration(
          milliseconds: durationMs is num ? durationMs.toInt() : 0,
        ),
        cancelled: json['cancelled'] as bool? ?? false,
        timedOut: json['timed_out'] as bool? ?? false,
        truncated: json['output_truncated'] as bool? ?? false,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  final String command;
  final int? exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool cancelled;
  final bool timedOut;
  final bool truncated;

  bool get succeeded => !cancelled && !timedOut && exitCode == 0;

  String get displayOutput {
    final buffer = StringBuffer();
    if (stdout.trim().isNotEmpty) buffer.write(stdout.trimRight());
    if (stderr.trim().isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(stderr.trimRight());
    }
    return buffer.toString();
  }

  String toToolMessage() {
    return jsonEncode({
      'command': command,
      'exit_code': exitCode,
      'cancelled': cancelled,
      'timed_out': timedOut,
      'output_truncated': truncated,
      'duration_ms': duration.inMilliseconds,
      'stdout': stdout,
      'stderr': stderr,
    });
  }
}

@immutable
sealed class AskAiEvent {
  const AskAiEvent();
}

/// Incremental text delta emitted while streaming the AI response.
class AskAiContentDelta extends AskAiEvent {
  const AskAiContentDelta(this.delta);
  final String delta;
}

/// Emits when a tool call returns a runnable command proposal.
class AskAiToolSuggestion extends AskAiEvent {
  const AskAiToolSuggestion(this.command);
  final AskAiCommand command;
}

/// Signals that the stream finished successfully.
class AskAiCompleted extends AskAiEvent {
  const AskAiCompleted({
    required this.fullText,
    required this.commands,
    required this.outputItems,
    required this.protocol,
    this.reasoningContent,
    this.responseId,
    this.promptTokens,
  });

  final String fullText;
  final List<AskAiCommand> commands;
  final List<AskAiConversationItem> outputItems;
  final AskAiProtocol protocol;
  final String? reasoningContent;
  final String? responseId;

  /// What the request actually cost, as the provider counted it.
  ///
  /// Null where the provider said nothing — not every OpenAI-compatible server
  /// answers `usage`, and a stream has to ask for it. It is the only honest
  /// measure of how full the context is; everything else is an estimate of
  /// characters standing in for tokens.
  final int? promptTokens;
}

/// Signals that the stream terminated with an error before completion.
class AskAiStreamError extends AskAiEvent {
  const AskAiStreamError(this.error, this.stackTrace);

  final Object error;
  final StackTrace? stackTrace;
}
