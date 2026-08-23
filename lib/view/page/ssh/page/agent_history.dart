part of 'page.dart';

extension _AgentHistoryActions on _AskAiPanelState {
  Future<void> _showConversationHistory() async {
    if (ref.read(agentSessionProvider(widget.serverId)).isWorking) return;

    Widget historyView() => _AgentHistoryView(
      serverId: widget.serverId,
      onNew: _notifier.beginNewConversation,
      onSelect: _notifier.activateConversation,
      onRename: _renameConversation,
      onDelete: _deleteConversation,
      onClear: _clearConversationHistory,
    );

    final presentation = askAiHistoryPresentationForWidth(
      MediaQuery.sizeOf(context).width,
    );
    if (presentation == AskAiHistoryPresentation.bottomSheet) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        // The same motion as the Agent tab's own history sheet — see
        // `agentSheetAnimation`, which is where the reasoning is.
        sheetAnimationStyle: agentSheetAnimation,
        builder: (sheetContext) =>
            FractionallySizedBox(heightFactor: 0.82, child: historyView()),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final availableHeight = MediaQuery.sizeOf(dialogContext).height - 64;
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 460,
            height: availableHeight.clamp(320.0, 680.0).toDouble(),
            child: historyView(),
          ),
        );
      },
    );
  }

  /// The three that ask before they act stay here; the rest are the session's
  /// own methods, passed straight through. A confirmation is a dialog, and the
  /// session has no `BuildContext` to put one on.
  Future<void> _renameConversation(AgentConversation conversation) async {
    final controller = TextEditingController(text: conversation.title)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: conversation.title.length,
      );
    try {
      final title = await context.showRoundDialog<String>(
        title: context.l10n.askAiRenameConversation,
        child: Input(
          controller: controller,
          autoFocus: true,
          label: context.l10n.askAiRenameConversation,
          onSubmitted: (_) => context.popDialog(controller.text.trim()),
        ),
        actions: [
          TextButton(onPressed: context.popDialog, child: Text(libL10n.cancel)),
          FilledButton(
            onPressed: () => context.popDialog(controller.text.trim()),
            child: Text(libL10n.ok),
          ),
        ],
      );
      if (title == null || title.trim().isEmpty) return;
      await _notifier.renameConversation(conversation.id, title);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteConversation(AgentConversation conversation) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: context.l10n.askAiDeleteConversationTitle,
      child: Text(context.l10n.askAiDeleteConversationTip),
      actions: [
        TextButton(onPressed: context.popDialog, child: Text(libL10n.cancel)),
        FilledButton.tonal(
          onPressed: () => context.popDialog(true),
          child: Text(libL10n.delete),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await _notifier.deleteConversation(conversation.id);
  }

  Future<void> _clearConversationHistory() async {
    final confirmed = await context.showRoundDialog<bool>(
      title: context.l10n.askAiClearHistoryTitle,
      child: Text(context.l10n.askAiClearHistoryTip),
      actions: [
        TextButton(onPressed: context.popDialog, child: Text(libL10n.cancel)),
        FilledButton.tonal(
          onPressed: () => context.popDialog(true),
          child: Text(libL10n.clearHistory),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await _notifier.clearConversationHistory();
  }
}

enum _AgentHistoryItemAction { rename, delete }

class _AgentHistoryView extends StatefulWidget {
  const _AgentHistoryView({
    required this.serverId,
    required this.onNew,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
    required this.onClear,
  });

  final String serverId;
  final Future<void> Function() onNew;
  final Future<void> Function(AgentConversation conversation) onSelect;
  final Future<void> Function(AgentConversation conversation) onRename;
  final Future<void> Function(AgentConversation conversation) onDelete;
  final Future<void> Function() onClear;

  @override
  State<_AgentHistoryView> createState() => _AgentHistoryViewState();
}

class _AgentHistoryViewState extends State<_AgentHistoryView> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _preview(AgentConversation conversation) {
    for (final item in conversation.items.reversed) {
      if (item is! AskAiMessageItem || item.content.trim().isEmpty) continue;
      return item.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return context.l10n.askAiNoHistoryMessages;
  }

  String _updatedLabel(AgentConversation conversation) {
    final local = conversation.updatedAt.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatShortDate(local);
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final protocol = conversation.protocol.vendorName ?? libL10n.auto;
    return '$date $time · $protocol · ${conversation.model}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 430;
    final conversations = Stores.agentConversation.fetchForServer(
      widget.serverId,
    );
    final activeId = Stores.agentConversation.activeConversationId(
      widget.serverId,
    );
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.askAiHistory,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (conversations.isNotEmpty)
                  IconButton(
                    tooltip: libL10n.clearHistory,
                    onPressed: _busy ? null : () => _run(widget.onClear),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                if (compact)
                  IconButton.filled(
                    tooltip: context.l10n.askAiNewConversation,
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await widget.onNew();
                            if (mounted) Navigator.of(context).pop();
                          }),
                    icon: const Icon(Icons.add),
                  )
                else
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await widget.onNew();
                            if (mounted) Navigator.of(context).pop();
                          }),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.askAiNewConversation),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.l10n.askAiNoHistory,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final active = conversation.id == activeId;
                      final title = conversation.title.trim().isEmpty
                          ? context.l10n.askAiUntitledConversation
                          : conversation.title;
                      return ListTile(
                        selected: active,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.45),
                        leading: CircleAvatar(
                          backgroundColor: active
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            active
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _preview(conversation),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _updatedLabel(conversation),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: _busy
                            ? null
                            : () => _run(() async {
                                await widget.onSelect(conversation);
                                if (mounted) Navigator.of(context).pop();
                              }),
                        trailing: PopupMenuButton<_AgentHistoryItemAction>(
                          enabled: !_busy,
                          onSelected: (action) => _run(() async {
                            switch (action) {
                              case _AgentHistoryItemAction.rename:
                                await widget.onRename(conversation);
                                break;
                              case _AgentHistoryItemAction.delete:
                                await widget.onDelete(conversation);
                                break;
                            }
                          }),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _AgentHistoryItemAction.rename,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.edit_outlined),
                                title: Text(
                                  context.l10n.askAiRenameConversation,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: _AgentHistoryItemAction.delete,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.delete_outline),
                                title: Text(libL10n.delete),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
