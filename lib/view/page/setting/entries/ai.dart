part of '../entry.dart';

extension _AI on _AppSettingsPageState {
  /// One row for a value the user types, in the same shape as every other
  /// settings row that opens something: title, the current value under it, and
  /// a chevron saying there is more behind the tap.
  Widget _buildAskAiTextTile({
    required SqliteProp<String> prop,
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

  /// Rows in cards of their own, like every other section on this page.
  ///
  /// It used to be one `ExpandTile` holding bare tiles, which made this the
  /// only block on the page that read as a single card, and the only one whose
  /// explanations were paragraphs under each row rather than a tip beside the
  /// title. Its header also said "Ask AI" directly under the section heading
  /// that already says "AI".
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
        // Absent where it could not be honoured: the sandboxed macOS build is
        // the App Store one, and an iOS build without the engine has no guest
        // to run in. Where the local target *is* a userland, a build that
        // cannot install one has nothing to offer either. A switch that turns
        // on nothing is worse than no switch.
        if (LocalExec.forThisDevice() case final local?
            when !local.inRootfs || Rootfs.isAvailable)
          ListTile(
            leading: const Icon(Icons.computer_outlined, size: _kIconSize),
            title: TipText(
              l10n.agentLocalExec,
              // Two different machines: a container the app installed, or the
              // computer itself with the app's own data on it.
              local.inRootfs
                  ? l10n.agentLocalExecRootfsTip
                  : l10n.agentLocalExecTip,
            ),
            trailing: StoreSwitch(prop: _setting.agentLocalExec),
          ),
        ListTile(
          leading: const Icon(Icons.keyboard_return, size: _kIconSize),
          title: TipText(l10n.askAiSendOnEnter, l10n.askAiSendOnEnterTip),
          trailing: StoreSwitch(prop: _setting.askAiSendOnEnter),
        ),
        _buildAskAiTextTile(
          prop: _setting.askAiBaseUrl,
          leading: const Icon(MingCute.link_2_line, size: _kIconSize),
          title: libL10n.apiEndpoint,
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
          title: libL10n.apiKey,
          hint: 'sk-...',
          obscure: true,
          displayBuilder: (val) => val?.isNotEmpty == true
              ? libL10n.configured
              : l10n.askAiApiKeyOptional,
        ),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  /// The value on the right and a dialog behind the tap, which is how every
  /// other "pick one of these" row on this page behaves — a `PopupMenuButton`
  /// wrapped around a tile was the only one that dropped a menu instead.
  Widget _buildAskAiProtocol(AppLocalizations l10n) {
    String label(AskAiProtocol protocol) => protocol.vendorName ?? libL10n.auto;

    return ListTile(
      leading: const Icon(Icons.swap_calls_outlined, size: _kIconSize),
      title: TipText(libL10n.apiProtocol, l10n.askAiProtocolTip),
      trailing: ValBuilder(
        listenable: _setting.askAiProtocol.listenable(),
        builder: (val) =>
            Text(label(parseAskAiProtocol(val)), style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: libL10n.apiProtocol,
          items: AskAiProtocol.values,
          display: label,
          initial: parseAskAiProtocol(_setting.askAiProtocol.fetch()),
        );
        if (selected != null) _setting.askAiProtocol.put(selected.name);
      },
    );
  }

  Future<void> _showAskAiFieldDialog({
    required SqliteProp<String> prop,
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
        context.popDialog();
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
              context.popDialog();
            },
            child: Text(libL10n.clear),
          ),
          TextButton(onPressed: onSave, child: Text(libL10n.ok)),
        ],
      );
    });
  }
}
