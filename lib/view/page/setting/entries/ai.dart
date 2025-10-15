part of '../entry.dart';

extension _AI on _AppSettingsPageState {
  Widget _buildAskAiConfig() {
    return ExpandTile(
      leading: const Icon(LineAwesome.robot_solid, size: _kIconSize),
      title: TipText('Ask AI', 'Used in SSH Terminal'),
      children: [
        _setting.askAiBaseUrl.listenable().listenVal((val) {
          final display = val.isEmpty ? libL10n.empty : val;
          return ListTile(
            leading: const Icon(MingCute.link_2_line),
            title: const Text('Base URL'),
            subtitle: Text(display, style: UIs.textGrey, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => _showAskAiFieldDialog(
              prop: _setting.askAiBaseUrl,
              title: 'Base URL',
              hint: 'https://api.openai.com',
            ),
          );
        }),
        _setting.askAiModel.listenable().listenVal((val) {
          final display = val.isEmpty ? libL10n.empty : val;
          return ListTile(
            leading: const Icon(Icons.view_module),
            title: const Text('Model'),
            subtitle: Text(display, style: UIs.textGrey),
            onTap: () => _showAskAiFieldDialog(
              prop: _setting.askAiModel,
              title: 'Model',
              hint: 'gpt-4o-mini',
            ),
          );
        }),
        _setting.askAiApiKey.listenable().listenVal((val) {
          final hasKey = val.isNotEmpty;
          return ListTile(
            leading: const Icon(MingCute.key_2_line),
            title: const Text('API Key'),
            subtitle: Text(hasKey ? '••••••••' : libL10n.empty, style: UIs.textGrey),
            onTap: () => _showAskAiFieldDialog(
              prop: _setting.askAiApiKey,
              title: 'API Key',
              hint: 'sk-...',
              obscure: true,
            ),
          );
        }),
      ],
    ).cardx;
  }


  Future<void> _showAskAiFieldDialog({
    required HiveProp<String> prop,
    required String title,
    required String hint,
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
        child: Input(
          controller: ctrl,
          autoFocus: true,
          label: title,
          hint: hint,
          icon: obscure ? MingCute.key_2_line : Icons.edit,
          obscureText: obscure,
          suggestion: !obscure,
          onSubmitted: (_) => onSave(),
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