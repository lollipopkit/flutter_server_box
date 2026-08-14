part of '../entry.dart';

extension _AI on _AppSettingsPageState {
  Widget _buildAskAiTextTile({
    required HiveProp<String> prop,
    required Widget leading,
    required String title,
    required String hint,
    required String Function(String? value) displayBuilder,
    String? description,
    bool obscure = false,
  }) {
    return prop.listenable().listenVal((val) {
      return ListTile(
        leading: leading,
        title: Text(title),
        subtitle: Text(
          displayBuilder(val),
          style: UIs.textGrey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => _showAskAiFieldDialog(
          prop: prop,
          title: title,
          hint: hint,
          description: description,
          obscure: obscure,
        ),
      );
    });
  }

  Widget _buildAskAiConfig() {
    final l10n = context.l10n;
    return Column(
      children: [
        _buildAskAiProtocol(l10n),
        ListTile(
          leading: const Icon(Icons.verified_user_outlined, size: _kIconSize),
          title: TipText(
            l10n.askAiAutoRunSafeCommands,
            l10n.askAiAutoRunSafeCommandsTip,
          ),
          trailing: StoreSwitch(prop: _setting.askAiAutoRunSafeCommands),
        ),
        _buildAskAiTextTile(
          prop: _setting.askAiBaseUrl,
          leading: const Icon(MingCute.link_2_line, size: _kIconSize),
          title: l10n.askAiBaseUrl,
          hint: 'https://api.openai.com',
          description: l10n.askAiEndpointTip,
          displayBuilder: (val) =>
              (val == null || val.isEmpty) ? libL10n.empty : val,
        ),
        _buildAskAiTextTile(
          prop: _setting.askAiModel,
          leading: const Icon(Icons.view_module, size: _kIconSize),
          title: libL10n.askAiModel,
          hint: 'gpt-5.4-mini',
          displayBuilder: (val) =>
              (val == null || val.isEmpty) ? libL10n.empty : val,
        ),
        _buildAskAiTextTile(
          prop: _setting.askAiApiKey,
          leading: const Icon(MingCute.key_2_line, size: _kIconSize),
          title: l10n.askAiApiKey,
          hint: 'sk-...',
          obscure: true,
          displayBuilder: (val) => val?.isNotEmpty == true
              ? l10n.configured
              : l10n.askAiApiKeyOptional,
        ),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildAskAiProtocol(AppLocalizations l10n) {
    String label(AskAiProtocol protocol) => switch (protocol) {
      AskAiProtocol.auto => l10n.askAiProtocolAuto,
      AskAiProtocol.chatCompletions => l10n.askAiProtocolChatCompletions,
      AskAiProtocol.responses => l10n.askAiProtocolResponses,
    };

    return ListTile(
      leading: const Icon(Icons.swap_calls_outlined, size: _kIconSize),
      title: TipText(l10n.askAiProtocol, l10n.askAiProtocolTip),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValBuilder(
            listenable: _setting.askAiProtocol.listenable(),
            builder: (val) =>
                Text(label(parseAskAiProtocol(val)), style: UIs.text15),
          ),
          const Icon(Icons.keyboard_arrow_right),
        ],
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.askAiProtocol,
          items: AskAiProtocol.values,
          display: label,
          initial: parseAskAiProtocol(_setting.askAiProtocol.fetch()),
        );
        if (selected != null) _setting.askAiProtocol.put(selected.name);
      },
    );
  }

  Future<void> _showAskAiFieldDialog({
    required HiveProp<String> prop,
    required String title,
    required String hint,
    String? description,
    bool obscure = false,
  }) async {
    return withTextFieldController((ctrl) async {
      final fetched = prop.fetch();
      if (fetched != null && fetched.isNotEmpty) ctrl.text = fetched;

      void onSave() {
        prop.put(ctrl.text.trim());
        context.pop();
      }

      await context.showRoundDialog(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Input(
              controller: ctrl,
              autoFocus: true,
              label: title,
              hint: hint,
              icon: obscure ? MingCute.key_2_line : Icons.edit,
              obscureText: obscure,
              suggestion: !obscure,
              onSubmitted: (_) => onSave(),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description, style: UIs.textGrey),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              prop.delete();
              context.pop();
            },
            child: Text(libL10n.clear),
          ),
          TextButton(onPressed: onSave, child: Text(libL10n.ok)),
        ],
      );
    });
  }
}
