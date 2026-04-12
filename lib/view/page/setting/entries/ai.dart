part of '../entry.dart';

extension _AI on _AppSettingsPageState {
  Widget _buildAskAiTextTile({
    required HiveProp<String> prop,
    required Widget leading,
    required String title,
    required String hint,
    required String Function(String? value) displayBuilder,
    bool obscure = false,
  }) {
    return prop.listenable().listenVal((val) {
      return ListTile(
        leading: leading,
        title: Text(title),
        subtitle: Text(
          displayBuilder(val),
          style: UIs.textGrey,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _showAskAiFieldDialog(
          prop: prop,
          title: title,
          hint: hint,
          obscure: obscure,
        ),
      );
    });
  }

  Widget _buildAskAiConfig() {
    final l10n = context.l10n;
    return ExpandTile(
      leading: const Icon(LineAwesome.robot_solid, size: _kIconSize),
      title: TipText(l10n.askAi, l10n.askAiUsageHint),
      children: [
        _buildAskAiTextTile(
          prop: _setting.askAiBaseUrl,
          leading: const Icon(MingCute.link_2_line),
          title: l10n.askAiBaseUrl,
          hint: 'https://api.openai.com',
          displayBuilder: (val) =>
              (val == null || val.isEmpty) ? libL10n.empty : val,
        ),
        _buildAskAiTextTile(
          prop: _setting.askAiModel,
          leading: const Icon(Icons.view_module),
          title: libL10n.askAiModel,
          hint: 'gpt-4o-mini',
          displayBuilder: (val) =>
              (val == null || val.isEmpty) ? libL10n.empty : val,
        ),
        _buildAskAiTextTile(
          prop: _setting.askAiApiKey,
          leading: const Icon(MingCute.key_2_line),
          title: l10n.askAiApiKey,
          hint: 'sk-...',
          obscure: true,
          displayBuilder: (val) =>
              val?.isNotEmpty == true ? l10n.configured : libL10n.empty,
        ),
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
