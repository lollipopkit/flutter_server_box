import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/ai_safety.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';

@immutable
enum AiApplyBehavior {
  /// Apply means "insert" into an input (terminal/editor).
  insert,

  /// Apply means "open SSH and prefill initCmd".
  openSsh,

  /// Apply means "copy to clipboard".
  copy,
}

@immutable
class AiAssistArgs {
  const AiAssistArgs({
    required this.title,
    required this.contextBlocks,
    required this.scenario,
    required this.applyLabel,
    required this.applyBehavior,
    this.localeHint,
    this.redacted = true,
    this.onInsert,
    this.onOpenSsh,
  });

  final String title;
  final List<String> contextBlocks;
  final AskAiScenario scenario;
  final String applyLabel;
  final AiApplyBehavior applyBehavior;
  final String? localeHint;

  /// If true, apply a conservative redaction before sending.
  final bool redacted;

  final ValueChanged<String>? onInsert;
  final ValueChanged<String>? onOpenSsh;
}

Future<void> showAiAssistSheet(BuildContext context, AiAssistArgs args) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AiAssistSheet(args: args),
  );
}

class AiAssistSheet extends ConsumerStatefulWidget {
  const AiAssistSheet({super.key, required this.args});

  final AiAssistArgs args;

  @override
  ConsumerState<AiAssistSheet> createState() => _AiAssistSheetState();
}

enum _ChatEntryType { user, assistant, command }

class _ChatEntry {
  const _ChatEntry._({required this.type, this.content, this.command, this.risk});

  const _ChatEntry.user(String content) : this._(type: _ChatEntryType.user, content: content);

  const _ChatEntry.assistant(String content) : this._(type: _ChatEntryType.assistant, content: content);

  const _ChatEntry.command(AskAiCommand command, AiCommandRisk risk)
    : this._(type: _ChatEntryType.command, command: command, risk: risk);

  final _ChatEntryType type;
  final String? content;
  final AskAiCommand? command;
  final AiCommandRisk? risk;
}

class _AiAssistSheetState extends ConsumerState<AiAssistSheet> {
  StreamSubscription<AskAiEvent>? _subscription;
  final _chatEntries = <_ChatEntry>[];
  final _history = <AskAiMessage>[];
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _seenCommands = <String>{};
  String? _streamingContent;
  String? _error;
  bool _isStreaming = false;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
    _startStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<String> get _preparedBlocks {
    final blocks = widget.args.contextBlocks;
    if (!widget.args.redacted) return blocks;

    // Best-effort: redact without Spi. Pages that have Spi should pass already-redacted
    // blocks or avoid including secrets directly.
    return AiSafety.redactBlocks(blocks);
  }

  void _startStream() {
    _subscription?.cancel();
    setState(() {
      _isStreaming = true;
      _error = null;
      _streamingContent = '';
    });

    final messages = List<AskAiMessage>.from(_history);

    _subscription = ref
        .read(askAiRepositoryProvider)
        .ask(
          scenario: widget.args.scenario,
          contextBlocks: _preparedBlocks,
          localeHint: widget.args.localeHint,
          conversation: messages,
        )
        .listen(
          _handleEvent,
          onError: (error, stack) {
            if (!mounted) return;
            setState(() {
              _error = _describeError(error);
              _isStreaming = false;
              _streamingContent = null;
            });
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _isStreaming = false;
            });
          },
        );
  }

  void _handleEvent(AskAiEvent event) {
    if (!mounted) return;
    var shouldScroll = false;
    setState(() {
      if (event is AskAiContentDelta) {
        _streamingContent = (_streamingContent ?? '') + event.delta;
        shouldScroll = true;
      } else if (event is AskAiToolSuggestion) {
        final inserted = _seenCommands.add(event.command.command);
        if (inserted) {
          final risk = event.command.risk != null
              ? (AiCommandRiskX.tryParse(event.command.risk) ?? AiSafety.classifyRisk(event.command.command))
              : AiSafety.classifyRisk(event.command.command);
          _chatEntries.add(_ChatEntry.command(event.command, risk));
          shouldScroll = true;
        }
      } else if (event is AskAiCompleted) {
        final fullText = event.fullText.isNotEmpty ? event.fullText : (_streamingContent ?? '');
        if (fullText.trim().isNotEmpty) {
          final message = AskAiMessage(role: AskAiMessageRole.assistant, content: fullText);
          _history.add(message);
          _chatEntries.add(_ChatEntry.assistant(fullText));
        }
        for (final command in event.commands) {
          final inserted = _seenCommands.add(command.command);
          if (inserted) {
            final risk = command.risk != null
                ? (AiCommandRiskX.tryParse(command.risk) ?? AiSafety.classifyRisk(command.command))
                : AiSafety.classifyRisk(command.command);
            _chatEntries.add(_ChatEntry.command(command, risk));
          }
        }
        _streamingContent = null;
        _isStreaming = false;
        shouldScroll = true;
      } else if (event is AskAiStreamError) {
        _error = _describeError(event.error);
        _streamingContent = null;
        _isStreaming = false;
      }
    });

    if (shouldScroll) {
      _scheduleAutoScroll();
    }
  }

  void _scheduleAutoScroll() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _describeError(Object error) {
    final l10n = context.l10n;
    if (error is AskAiConfigException) {
      if (error.missingFields.isEmpty) {
        if (error.hasInvalidBaseUrl) {
          return 'Invalid Ask AI base URL: ${error.invalidBaseUrl}';
        }
        return error.toString();
      }
      final locale = Localizations.maybeLocaleOf(context);
      final separator = switch (locale?.languageCode) {
        'zh' => '、',
        'ja' => '、',
        _ => ', ',
      };
      final formattedFields = error.missingFields
          .map(
            (field) => switch (field) {
              AskAiConfigField.baseUrl => l10n.askAiBaseUrl,
              AskAiConfigField.apiKey => l10n.askAiApiKey,
              AskAiConfigField.model => l10n.askAiModel,
            },
          )
          .join(separator);
      final message = l10n.askAiConfigMissing(formattedFields);
      if (error.hasInvalidBaseUrl) {
        return '$message (invalid URL: ${error.invalidBaseUrl})';
      }
      return message;
    }
    if (error is AskAiNetworkException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _confirmAndApplyCommand(AskAiCommand command, AiCommandRisk risk) async {
    final l10n = context.l10n;

    final needsCountdown = risk == AiCommandRisk.high || command.needsConfirmation == true;

    final actions = <Widget>[Btn.cancel()];

    if (needsCountdown) {
      actions.add(
        CountDownBtn(
          seconds: 3,
          onTap: () => context.pop(true),
          text: libL10n.ok,
          afterColor: Colors.red,
        ),
      );
    } else {
      actions.add(TextButton(onPressed: () => context.pop(true), child: Text(libL10n.ok)));
    }

    final confirmed = await context.showRoundDialog<bool>(
      title: needsCountdown ? libL10n.attention : l10n.askAiConfirmExecute,
      child: SimpleMarkdown(data: '```shell\n${command.command}\n```'),
      actions: actions,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _applyCommand(command.command);
  }

  Future<void> _applyCommand(String cmd) async {
    final text = cmd.trim();
    if (text.isEmpty) return;

    switch (widget.args.applyBehavior) {
      case AiApplyBehavior.insert:
        widget.args.onInsert?.call(text);
        if (!mounted) return;
        context.showSnackBar(context.l10n.askAiCommandInserted);
        break;
      case AiApplyBehavior.openSsh:
        widget.args.onOpenSsh?.call(text);
        break;
      case AiApplyBehavior.copy:
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        context.showSnackBar(libL10n.success);
        break;
    }
  }

  Future<void> _copyCommand(AskAiCommand command) async {
    await Clipboard.setData(ClipboardData(text: command.command));
    if (!mounted) return;
    context.showSnackBar(libL10n.success);
  }

  Future<void> _copyText(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    context.showSnackBar(libL10n.success);
  }

  void _sendMessage() {
    if (_isStreaming) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      final message = AskAiMessage(role: AskAiMessageRole.user, content: text);
      _history.add(message);
      _chatEntries.add(_ChatEntry.user(text));
      _inputController.clear();
    });
    _startStream();
    _scheduleAutoScroll();
  }

  List<Widget> _buildConversationWidgets(BuildContext context, ThemeData theme) {
    final widgets = <Widget>[];
    for (final entry in _chatEntries) {
      widgets.add(_buildChatItem(context, theme, entry));
      widgets.add(const SizedBox(height: 12));
    }

    if (_streamingContent != null) {
      widgets.add(_buildAssistantBubble(theme, content: _streamingContent!, streaming: true));
      widgets.add(const SizedBox(height: 12));
    } else if (_chatEntries.isEmpty && _error == null) {
      widgets.add(_buildAssistantBubble(theme, content: '', streaming: true));
      widgets.add(const SizedBox(height: 12));
    }

    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  Widget _buildChatItem(BuildContext context, ThemeData theme, _ChatEntry entry) {
    switch (entry.type) {
      case _ChatEntryType.user:
        return Align(
          alignment: Alignment.centerRight,
          child: CardX(
            child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(entry.content ?? '')),
          ),
        );
      case _ChatEntryType.assistant:
        return _buildAssistantBubble(theme, content: entry.content ?? '');
      case _ChatEntryType.command:
        final command = entry.command!;
        final risk = entry.risk ?? AiSafety.classifyRisk(command.command);
        return _buildCommandBubble(context, theme, command, risk);
    }
  }

  Widget _buildAssistantBubble(ThemeData theme, {required String content, bool streaming = false}) {
    final trimmed = content.trim();
    final l10n = context.l10n;
    final child = trimmed.isEmpty
        ? Text(
            streaming ? l10n.askAiAwaitingResponse : l10n.askAiNoResponse,
            style: theme.textTheme.bodySmall,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SimpleMarkdown(data: content),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _copyText(content),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(libL10n.copy),
                  ),
                ],
              ),
            ],
          );
    return Align(
      alignment: Alignment.centerLeft,
      child: CardX(
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }

  Widget _buildRiskTag(ThemeData theme, AiCommandRisk risk) {
    final (label, color) = switch (risk) {
      AiCommandRisk.low => ('LOW', Colors.green),
      AiCommandRisk.medium => ('MED', Colors.orange),
      AiCommandRisk.high => ('HIGH', Colors.red),
    };

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ).paddingSymmetric(horizontal: 6, vertical: 2),
    );
  }

  Widget _buildCommandBubble(BuildContext context, ThemeData theme, AskAiCommand command, AiCommandRisk risk) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: CardX(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.askAiRecommendedCommand, style: theme.textTheme.labelMedium),
                  const SizedBox(width: 8),
                  _buildRiskTag(theme, risk),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(command.command, style: const TextStyle(fontFamily: 'monospace')),
              if (command.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(command.description, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _copyCommand(command),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(libL10n.copy),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _confirmAndApplyCommand(command, risk),
                    icon: const Icon(Icons.terminal, size: 18),
                    label: Text(widget.args.applyLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final heightFactor = _isMinimized ? 0.18 : 0.85;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: heightFactor),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, animatedHeightFactor, child) {
        return ClipRect(
          child: FractionallySizedBox(
            heightFactor: animatedHeightFactor,
            child: child,
          ),
        );
      },
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text(widget.args.title, style: theme.textTheme.titleLarge),
                  const SizedBox(width: 8),
                  if (_isStreaming)
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_isMinimized ? Icons.unfold_more : Icons.unfold_less),
                    tooltip: libL10n.fold,
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _isMinimized = !_isMinimized;
                      });
                    },
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            if (!_isMinimized) ...[
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      Text(context.l10n.askAiSelectedContent, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      CardX(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final block in widget.args.contextBlocks) ...[
                                SelectableText(block, style: const TextStyle(fontFamily: 'monospace')),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(context.l10n.askAiConversation, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      ..._buildConversationWidgets(context, theme),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        CardX(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                          ),
                        ),
                      ],
                      if (_isStreaming) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  context.l10n.askAiDisclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Input(
                        controller: _inputController,
                        minLines: 1,
                        maxLines: 4,
                        hint: context.l10n.askAiFollowUpHint,
                        action: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Btn.icon(
                      onTap: _isStreaming || _inputController.text.trim().isEmpty ? null : _sendMessage,
                      icon: const Icon(Icons.send, size: 18),
                    ),
                  ],
                ).cardx,
              ),
            ] else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
