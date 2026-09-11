part of '../entry.dart';

extension _AI on _AppSettingsPageState {
  /// One row for a value the user types, in the same shape as every other
  /// settings row that opens something: title, the current value under it, and
  /// a chevron saying there is more behind the tap.
  Widget _buildAskAiTextTile({
    required StorePropDefault<String> prop,
    required Widget leading,
    required String title,
    required String hint,
    required String Function(String value) displayBuilder,
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
          displayBuilder: (val) => val.isEmpty ? libL10n.empty : val,
        ),
        // Under the address, because it is a property of the address. Shown
        // always rather than only for an `http://` one: it is the answer to
        // "why is my local model rejected", and a switch that appears only once
        // the rejected value has been saved is found after the giving up.
        ListTile(
          leading: const Icon(Icons.lock_open, size: _kIconSize),
          title: TipText(
            l10n.askAiAllowInsecure,
            l10n.askAiAllowInsecureTip,
          ),
          trailing: StoreSwitch(prop: _setting.askAiAllowInsecure),
        ),
        _buildAskAiTextTile(
          prop: _setting.askAiModel,
          leading: const Icon(Icons.view_module, size: _kIconSize),
          title: libL10n.askAiModel,
          hint: 'gpt-5.6-luna',
          displayBuilder: (val) => val.isEmpty ? libL10n.empty : val,
        ),
        _buildAskAiTextTile(
          prop: _setting.askAiApiKey,
          leading: const Icon(MingCute.key_2_line, size: _kIconSize),
          title: libL10n.apiKey,
          hint: 'sk-...',
          obscure: true,
          displayBuilder: (val) =>
              val.isNotEmpty ? libL10n.configured : l10n.askAiApiKeyOptional,
        ),
        _buildCompactAt(l10n),
        _buildContextTokens(l10n),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  /// How full the context gets before the conversation is summarised.
  Widget _buildCompactAt(AppLocalizations l10n) {
    return _buildAskAiIntTile(
      prop: _setting.askAiCompactAtPercent,
      leading: const Icon(Icons.compress, size: _kIconSize),
      title: l10n.askAiCompactAt,
      description: l10n.askAiCompactAtTip,
      hint: '90',
      // A summary is only useful while there is still room to send it and the
      // turn it is for, so the top of the range is short of the limit itself.
      sanitize: (value) => value.clamp(10, 99),
      displayBuilder: (val) => '$val%',
    );
  }

  /// What the model holds, when the shipped table is wrong about it.
  Widget _buildContextTokens(AppLocalizations l10n) {
    return _buildAskAiIntTile(
      prop: _setting.askAiContextTokens,
      leading: const Icon(Icons.straighten, size: _kIconSize),
      title: l10n.askAiContextTokens,
      description: l10n.askAiContextTokensTip,
      hint: '0',
      sanitize: (value) => value < 0 ? 0 : value,
      displayBuilder: (val) => val <= 0 ? libL10n.auto : '$val',
    );
  }

  /// The same row as [_buildAskAiTextTile] over a number.
  ///
  /// [sanitize] rather than validation in the dialog: a value out of range is
  /// a typo, and refusing it would leave the user to guess the range. Pulling
  /// it into range and showing the result says what the range is.
  Widget _buildAskAiIntTile({
    required StorePropDefault<int> prop,
    required Widget leading,
    required String title,
    required String hint,
    required String Function(int value) displayBuilder,
    required int Function(int value) sanitize,
    String? description,
  }) {
    return prop.listenable().listenVal((val) {
      return ListTile(
        leading: leading,
        title: TipText(title, description ?? title),
        subtitle: Text(displayBuilder(val), style: UIs.textGrey),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => withTextFieldController((ctrl) async {
          ctrl.text = '${prop.get()}';

          void onSave() {
            final parsed = int.tryParse(ctrl.text.trim());
            if (parsed != null) {
              unawaited(_persist(prop.set(sanitize(parsed))));
            }
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
                  type: TextInputType.number,
                  label: title,
                  hint: hint,
                  icon: Icons.edit,
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
                onPressed: context.popDialog,
                child: Text(libL10n.cancel),
              ),
              TextButton(onPressed: onSave, child: Text(libL10n.ok)),
            ],
          );
        }),
      );
    });
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

  /// Surfaces a write that did not land.
  ///
  /// `StoreProp.set` throws a `StateError` when the store answers `false`, and
  /// the dialog closes before the future completes — so without this the only
  /// sign is a line in the log.
  static Future<void> _persist(Future<void> write) async {
    try {
      await write;
    } catch (e, s) {
      Loggers.app.warning('Saving a setting failed', e, s);
      Toast.error('$e');
    }
  }

  Future<void> _showAskAiFieldDialog({
    required StorePropDefault<String> prop,
    required String title,
    required String hint,
    String? description,
    bool obscure = false,
  }) async {
    return withTextFieldController((ctrl) async {
      final fetched = prop.get();
      if (fetched.isNotEmpty) ctrl.text = fetched;

      // Reported rather than dropped: `StoreProp.set` throws when the write
      // does not land, and unawaited that reaches the zone handler as a
      // generic error while the dialog has already closed as though it
      // worked. The old `put` could not fail, so this path is new.
      void onSave() {
        unawaited(_persist(prop.set(ctrl.text.trim())));
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
              // Back to the default rather than off the map: a grouped field
              // has no row of its own to delete, and for these the default is
              // what an absent row read as anyway.
              unawaited(_persist(prop.remove()));
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
