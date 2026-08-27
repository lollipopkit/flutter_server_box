import 'dart:async';
import 'dart:collection';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

typedef SSHKeyboardInteractiveHandler =
    FutureOr<List<String>?> Function(Spi server, SSHUserInfoRequest request);

abstract final class KeyboardInteractiveAuth {
  static const promptTimeout = Duration(minutes: 3);

  static final _dialogQueue = Queue<_QueuedKeyboardInteractiveRequest>();
  static bool _isDrainingQueue = false;
  static _QueuedKeyboardInteractiveRequest? _activeRequest;

  static FutureOr<List<String>?> handle(
    Spi spi,
    SSHUserInfoRequest request, {
    BuildContext? context,
    Duration timeout = promptTimeout,
  }) {
    final prepared = _prepareRequest(spi, request);
    if (prepared.pendingPrompts.isEmpty) {
      return prepared.merge(const <String>[]);
    }

    final queued = _QueuedKeyboardInteractiveRequest(
      spi: spi,
      request: SSHUserInfoRequest(
        request.name,
        request.instruction,
        prepared.pendingPrompts,
      ),
      prepared: prepared,
      preferredContext: context,
    );
    _dialogQueue.add(queued);
    queued.timeoutTimer = Timer(timeout, () => _cancelRequest(queued));
    unawaited(_drainQueue());
    return queued.result.future;
  }

  static void _cancelRequest(_QueuedKeyboardInteractiveRequest request) {
    _dialogQueue.remove(request);
    request.cancel();
  }

  static Future<void> _showQueuedRequest(
    _QueuedKeyboardInteractiveRequest queued,
  ) async {
    if (queued.result.isCompleted) return;

    _activeRequest = queued;
    try {
      final pendingResponses = await _showDialog(
        queued.spi,
        queued.request,
        preferredContext: queued.preferredContext,
        onDismissReady: (dismiss) {
          queued.dismiss = dismiss;
          if (queued.result.isCompleted) dismiss();
        },
      );
      if (queued.result.isCompleted) return;
      queued.result.complete(
        pendingResponses == null
            ? null
            : queued.prepared.merge(pendingResponses),
      );
    } catch (e, s) {
      if (!queued.result.isCompleted) queued.result.completeError(e, s);
    } finally {
      queued.timeoutTimer?.cancel();
      queued.dismiss = null;
      if (identical(_activeRequest, queued)) _activeRequest = null;
    }
  }

  static Future<void> _drainQueue() async {
    if (_isDrainingQueue) return;
    _isDrainingQueue = true;
    try {
      while (_dialogQueue.isNotEmpty) {
        final queued = _dialogQueue.removeFirst();
        await _showQueuedRequest(queued);
      }
    } finally {
      _isDrainingQueue = false;
      if (_dialogQueue.isNotEmpty) unawaited(_drainQueue());
    }
  }

  static _PreparedKeyboardInteractiveRequest _prepareRequest(
    Spi spi,
    SSHUserInfoRequest request,
  ) {
    final responses = List<String?>.filled(request.prompts.length, null);
    final pendingIndexes = <int>[];
    final pendingPrompts = <SSHUserInfoPrompt>[];
    final password = spi.ssh?.pwd;
    var usedStoredPassword = false;

    for (var i = 0; i < request.prompts.length; i++) {
      final prompt = request.prompts[i];
      if (!usedStoredPassword &&
          password != null &&
          password.isNotEmpty &&
          _isAccountPasswordPrompt(prompt)) {
        responses[i] = password;
        usedStoredPassword = true;
      } else {
        pendingIndexes.add(i);
        pendingPrompts.add(prompt);
      }
    }

    return _PreparedKeyboardInteractiveRequest(
      responses: responses,
      pendingIndexes: pendingIndexes,
      pendingPrompts: pendingPrompts,
    );
  }

  static bool _isAccountPasswordPrompt(SSHUserInfoPrompt prompt) {
    if (prompt.echo) return false;

    final normalized = _normalizePrompt(prompt.promptText);
    if (normalized.isEmpty) return false;

    if (_isOtpPrompt(prompt)) return false;

    const passwordChangeMarkers = [
      'new password',
      'confirm password',
      'repeat password',
      'retype password',
      'again',
      '新密码',
      '新密碼',
      '确认密码',
      '確認密碼',
    ];
    if (passwordChangeMarkers.any(normalized.contains)) return false;

    const passwordMarkers = [
      'password',
      'passwort',
      'mot de passe',
      'contraseña',
      'senha',
      'wachtwoord',
      'kata sandi',
      'пароль',
      'parola',
      'şifre',
      '密码',
      '密碼',
      'パスワード',
      '비밀번호',
      '암호',
    ];
    return passwordMarkers.any(normalized.contains);
  }

  static bool _isOtpPrompt(SSHUserInfoPrompt prompt) {
    final normalized = _normalizePrompt(prompt.promptText);
    const otpMarkers = [
      'one-time',
      'one time',
      'otp',
      'verification',
      'authenticator',
      'token',
      'passcode',
      'code',
      '动态',
      '動態',
      '验证码',
      '驗證碼',
      '確認コード',
      '인증 코드',
    ];
    return otpMarkers.any(normalized.contains);
  }

  static String _normalizePrompt(String value) {
    return _sanitize(
      value,
    ).toLowerCase().replaceAll(RegExp(r'[\s:：]+'), ' ').trim();
  }

  static Future<List<String>?> _showDialog(
    Spi spi,
    SSHUserInfoRequest request, {
    BuildContext? preferredContext,
    required ValueChanged<VoidCallback> onDismissReady,
  }) async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return null;
    }

    final context = preferredContext?.mounted == true
        ? preferredContext
        : AppNavigator.context;
    if (context == null || !context.mounted) return null;

    final fieldsKey = GlobalKey<_KeyboardInteractiveFieldsState>();
    final requestName = _sanitize(request.name);
    final instruction = _sanitize(request.instruction);
    final title = requestName.isNotEmpty ? requestName : libL10n.authRequired;

    return await context.showRoundDialog<List<String>>(
      title: title,
      titleMaxLines: 2,
      barrierDismiss: false,
      childBuilder: (dialogContext) {
        onDismissReady(() {
          if (!dialogContext.mounted) return;
          final route = ModalRoute.of(dialogContext);
          if (route?.isCurrent == true) Navigator.of(dialogContext).pop();
        });
        return _KeyboardInteractiveFields(
          key: fieldsKey,
          spi: spi,
          instruction: instruction,
          prompts: request.prompts,
          onSubmit: () => Navigator.of(
            dialogContext,
          ).pop(fieldsKey.currentState?.responses),
        );
      },
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(fieldsKey.currentState?.responses),
          child: Text(libL10n.ok),
        ),
      ],
    );
  }

  static String _promptLabel(SSHUserInfoPrompt prompt, int index) {
    if (_isOtpPrompt(prompt)) return l10n.sshVerificationCode;
    if (_isAccountPasswordPrompt(prompt)) return libL10n.pwd;

    final label = _sanitize(prompt.promptText);
    if (label.isNotEmpty) return label;
    return '${libL10n.authRequired} ${index + 1}';
  }

  static String? _promptHint(SSHUserInfoPrompt prompt) {
    if (!_isOtpPrompt(prompt) && !_isAccountPasswordPrompt(prompt)) return null;
    final hint = _sanitize(prompt.promptText);
    return hint.isEmpty ? null : hint;
  }

  static String _sanitize(String value) {
    final sanitized = value.replaceAll(
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
      '',
    );
    if (sanitized.length <= 1024) return sanitized;
    return sanitized.substring(0, 1024);
  }
}

class _QueuedKeyboardInteractiveRequest {
  final Spi spi;
  final SSHUserInfoRequest request;
  final _PreparedKeyboardInteractiveRequest prepared;
  final BuildContext? preferredContext;
  final result = Completer<List<String>?>();

  Timer? timeoutTimer;
  VoidCallback? dismiss;

  _QueuedKeyboardInteractiveRequest({
    required this.spi,
    required this.request,
    required this.prepared,
    required this.preferredContext,
  });

  void cancel() {
    timeoutTimer?.cancel();
    if (!result.isCompleted) result.complete(null);
    dismiss?.call();
  }
}

class _PreparedKeyboardInteractiveRequest {
  final List<String?> responses;
  final List<int> pendingIndexes;
  final List<SSHUserInfoPrompt> pendingPrompts;

  const _PreparedKeyboardInteractiveRequest({
    required this.responses,
    required this.pendingIndexes,
    required this.pendingPrompts,
  });

  List<String> merge(List<String> pendingResponses) {
    if (pendingResponses.length != pendingIndexes.length) {
      throw ArgumentError(
        'pendingResponses.length (${pendingResponses.length}) != '
        'pendingIndexes.length (${pendingIndexes.length})',
      );
    }

    final merged = List<String?>.of(responses);
    for (var i = 0; i < pendingIndexes.length; i++) {
      merged[pendingIndexes[i]] = pendingResponses[i];
    }
    return [for (final response in merged) response!];
  }
}

class _KeyboardInteractiveFields extends StatefulWidget {
  final Spi spi;
  final String instruction;
  final List<SSHUserInfoPrompt> prompts;
  final VoidCallback onSubmit;

  const _KeyboardInteractiveFields({
    super.key,
    required this.spi,
    required this.instruction,
    required this.prompts,
    required this.onSubmit,
  });

  @override
  State<_KeyboardInteractiveFields> createState() =>
      _KeyboardInteractiveFieldsState();
}

class _KeyboardInteractiveFieldsState
    extends State<_KeyboardInteractiveFields> {
  late final List<TextEditingController> _controllers = [
    for (var i = 0; i < widget.prompts.length; i++) TextEditingController(),
  ];

  List<String> get responses => [
    for (final controller in _controllers) controller.text,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${libL10n.server}: ${widget.spi.name}'),
            if (widget.instruction.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(widget.instruction),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < widget.prompts.length; i++) ...[
              Input(
                key: ValueKey('ssh-keyboard-interactive-$i'),
                controller: _controllers[i],
                label: KeyboardInteractiveAuth._promptLabel(
                  widget.prompts[i],
                  i,
                ),
                hint: KeyboardInteractiveAuth._promptHint(widget.prompts[i]),
                autoFocus: i == 0,
                obscureText: !widget.prompts[i].echo,
                type: widget.prompts[i].echo
                    ? TextInputType.text
                    : TextInputType.visiblePassword,
                action: i == widget.prompts.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                suggestion: false,
                onSubmitted: i == widget.prompts.length - 1
                    ? (_) => widget.onSubmit()
                    : null,
              ),
              if (i != widget.prompts.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
