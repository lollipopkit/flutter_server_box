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

  /// The section, in named groups.
  ///
  /// It used to be one `ExpandTile` holding bare tiles, then a column of
  /// one-row cards. Neither said which of these rows belong together, and
  /// three of them are about one endpoint.
  List<SettingsGroup> _buildAskAiConfig() {
    final l10n = context.l10n;
    final local = LocalExec.forThisDevice();
    return [
      SettingsGroup(libL10n.general, [
        _buildAskAiProtocol(l10n),
        _buildAskAiAutoRun(l10n),
        // Absent where it could not be honoured: the sandboxed macOS build is
        // the App Store one, and an iOS build without the engine has no guest
        // to run in. Where the local target *is* a userland, a build that
        // cannot install one has nothing to offer either. A switch that turns
        // on nothing is worse than no switch.
        if (local != null && (!local.inRootfs || Rootfs.isAvailable))
          _buildAskAiLocalExec(l10n, local),
        _buildAskAiSendOnEnter(l10n),
      ]),
      SettingsGroup(libL10n.conn, [
        _buildAskAiBaseUrl(l10n),
        // Under the address, because it is a property of the address. Shown
        // always rather than only for an `http://` one: it is the answer to
        // "why is my local model rejected", and a switch that appears only
        // once the rejected value has been saved is found after the giving up.
        _buildAskAiAllowInsecure(l10n),
        _buildAskAiModel(),
        _buildAskAiApiKey(l10n),
      ]),
      SettingsGroup(libL10n.content, [
        _buildCompactAt(l10n),
        _buildContextTokens(l10n),
        _buildModelTable(l10n),
      ]),
    ];
  }

  SettingsRow _buildAskAiAutoRun(AppLocalizations l10n) {
    final label = l10n.askAiAutoRunSafeCommands;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: TipText(label, l10n.askAiAutoRunSafeCommandsTip),
        trailing: StoreSwitch(prop: _setting.askAiAutoRunSafeCommands),
      ),
      keywords: l10n.askAiAutoRunSafeCommandsTip,
    );
  }

  SettingsRow _buildAskAiLocalExec(AppLocalizations l10n, LocalExec local) {
    final label = l10n.agentLocalExec;
    // Two different machines: a container the app installed, or the computer
    // itself with the app's own data on it.
    final tip = local.inRootfs
        ? l10n.agentLocalExecRootfsTip
        : l10n.agentLocalExecTip;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.computer_outlined),
        title: TipText(label, tip),
        trailing: StoreSwitch(prop: _setting.agentLocalExec),
      ),
      keywords: tip,
    );
  }

  SettingsRow _buildAskAiSendOnEnter(AppLocalizations l10n) {
    final label = l10n.askAiSendOnEnter;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.keyboard_return),
        title: TipText(label, l10n.askAiSendOnEnterTip),
        trailing: StoreSwitch(prop: _setting.askAiSendOnEnter),
      ),
      keywords: l10n.askAiSendOnEnterTip,
    );
  }

  SettingsRow _buildAskAiAllowInsecure(AppLocalizations l10n) {
    final label = l10n.askAiAllowInsecure;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.lock_open),
        title: TipText(label, l10n.askAiAllowInsecureTip),
        trailing: StoreSwitch(prop: _setting.askAiAllowInsecure),
      ),
      keywords: 'http ${l10n.askAiAllowInsecureTip}',
    );
  }

  SettingsRow _buildAskAiBaseUrl(AppLocalizations l10n) {
    final label = libL10n.apiEndpoint;
    return SettingsRow(
      label,
      () => _buildAskAiTextTile(
        prop: _setting.askAiBaseUrl,
        leading: const Icon(MingCute.link_2_line),
        title: label,
        hint: 'https://api.openai.com/v1',
        description: l10n.askAiEndpointTip,
        displayBuilder: (val) => val.isEmpty ? libL10n.empty : val,
      ),
      keywords: l10n.askAiEndpointTip,
    );
  }

  SettingsRow _buildAskAiModel() {
    final label = libL10n.askAiModel;
    return SettingsRow(
      label,
      () => _buildAskAiTextTile(
        prop: _setting.askAiModel,
        leading: const Icon(Icons.view_module),
        title: label,
        hint: 'gpt-5.6-luna',
        displayBuilder: (val) => val.isEmpty ? libL10n.empty : val,
      ),
    );
  }

  SettingsRow _buildAskAiApiKey(AppLocalizations l10n) {
    final label = libL10n.apiKey;
    return SettingsRow(
      label,
      () => _buildAskAiTextTile(
        prop: _setting.askAiApiKey,
        leading: const Icon(MingCute.key_2_line),
        title: label,
        hint: 'sk-...',
        obscure: true,
        displayBuilder: (val) =>
            val.isNotEmpty ? libL10n.configured : l10n.askAiApiKeyOptional,
      ),
      keywords: 'token secret',
    );
  }

  /// How full the context gets before the conversation is summarised.
  SettingsRow _buildCompactAt(AppLocalizations l10n) {
    final label = l10n.askAiCompactAt;
    return SettingsRow(
      label,
      () => _buildAskAiIntTile(
        prop: _setting.askAiCompactAtPercent,
        leading: const Icon(Icons.compress),
        title: label,
        description: l10n.askAiCompactAtTip,
        hint: '90',
        // A summary is only useful while there is still room to send it and
        // the turn it is for, so the top of the range is short of the limit.
        sanitize: (value) => value.clamp(10, 99),
        displayBuilder: (val) => '$val%',
      ),
      keywords: l10n.askAiCompactAtTip,
    );
  }

  /// What this model, on this endpoint, holds — where the table is wrong.
  ///
  /// Bound to the pair rather than to a single number: one provider serves
  /// many models with different windows, and one model name is served by many
  /// providers with different windows. A single value followed the user to
  /// whatever they switched to next, which is the wrong answer twice over.
  SettingsRow _buildContextTokens(AppLocalizations l10n) {
    final label = l10n.askAiContextTokens;
    return SettingsRow(
      label,
      () => _setting.askAi.listenable().listenVal((config) {
      final baseUrl = config.baseUrl;
      final model = config.model;
      final override = config.contextOverrideFor(baseUrl, model);
      final resolved = ModelContextTable.shared.contextFor(model, override: override);

      return ListTile(
        leading: const Icon(Icons.straighten),
        title: TipText(l10n.askAiContextTokens, l10n.askAiContextTokensTip),
        // What will actually be used, and where it came from. A row that only
        // said "automatic" left the user to guess whether the table had
        // recognised their model at all.
        subtitle: Text(
          override > 0
              ? '$resolved'
              : '$resolved · ${ModelContextTable.shared.lookup(model) == null ? l10n.askAiContextFallback : libL10n.auto}',
          style: UIs.textGrey,
        ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => _showContextTokensDialog(l10n, baseUrl, model),
        );
      }),
      keywords: l10n.askAiContextTokensTip,
    );
  }

  Future<void> _showContextTokensDialog(
    AppLocalizations l10n,
    String baseUrl,
    String model,
  ) async {
    return withTextFieldController((ctrl) async {
      final config = _setting.askAi.fetch();
      final current = config.contextOverrideFor(baseUrl, model);
      if (current > 0) ctrl.text = '$current';

      void onSave(BuildContext dialog) {
        final parsed = int.tryParse(ctrl.text.trim()) ?? 0;
        unawaited(
          _persist(
            _setting.askAiContextOverrides.set(
              _setting.askAi
                  .fetch()
                  .withContextOverride(baseUrl, model, parsed < 0 ? 0 : parsed),
            ),
          ),
        );
        dialog.pop();
      }

      // Closed through the dialog's own context: the settings page can be
      // gone by the time a button is pressed, and its context with it.
      await context.showRoundDialog(
        title: l10n.askAiContextTokens,
        childBuilder: (dialog) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Input(
              controller: ctrl,
              autoFocus: true,
              type: TextInputType.number,
              label: l10n.askAiContextTokens,
              hint: '0',
              icon: Icons.edit,
              onSubmitted: (_) => onSave(dialog),
            ),
            const SizedBox(height: 8),
            // Which pair this is about. The dialog is reached from a row that
            // showed a number, and the number is only true for these two.
            Text('$model · $baseUrl', style: UIs.textGrey),
            const SizedBox(height: 4),
            Text(l10n.askAiContextTokensTip, style: UIs.textGrey),
          ],
        ),
        actionsBuilder: (dialog) => [
          TextButton(onPressed: dialog.pop, child: Text(libL10n.cancel)),
          TextButton(
            onPressed: () => onSave(dialog),
            child: Text(libL10n.ok),
          ),
        ],
      );
    });
  }

  /// The table itself: how old it is, and a way to fetch a newer one.
  SettingsRow _buildModelTable(AppLocalizations l10n) {
    final label = l10n.askAiModelTable;
    // Followed from the table rather than kept here. This row is rebuilt
    // whenever any AI setting changes, and a flag in this method came back
    // false mid-fetch — the spinner vanished and the button went live again.
    return SettingsRow(
      label,
      () => ModelContextTable.shared.refreshing.listenVal((refreshing) {
      final generated = ModelContextTable.shared.generated;
      return ListTile(
        leading: const Icon(Icons.dataset_outlined),
        title: TipText(l10n.askAiModelTable, l10n.askAiModelTableTip),
        // The bar goes under the line that says what the table is, inside the
        // row rather than across the page: it is this row that is working, and
        // a page-wide bar would not say which.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              generated == null
                  ? libL10n.empty
                  : '${ModelContextTable.shared.modelCount} · $generated',
              style: UIs.textGrey,
            ),
            if (refreshing) ...[
              const SizedBox(height: 7),
              ModelContextTable.shared.progress.listenVal(
                (value) => ProgressLine(value: value),
              ),
            ],
          ],
        ),
        trailing: refreshing
            ? SizedLoading.small
            : const Icon(Icons.refresh),
        onTap: refreshing
            ? null
            : () async {
                try {
                  final count = await ModelContextTable.shared.refresh();
                  Toast.success('${l10n.askAiModelTable}: $count');
                } catch (error) {
                  // Reported, not swallowed: the user pressed a button and is
                  // owed an answer. The old table is still in use.
                  Toast.error('$error');
                }
              },
        );
      }),
      keywords: l10n.askAiModelTableTip,
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

          void onSave(BuildContext dialog) {
            final parsed = int.tryParse(ctrl.text.trim());
            if (parsed != null) {
              unawaited(_persist(prop.set(sanitize(parsed))));
            }
            dialog.pop();
          }

          await context.showRoundDialog(
            title: title,
            childBuilder: (dialog) => Column(
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
                  onSubmitted: (_) => onSave(dialog),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(description, style: UIs.textGrey),
                ],
              ],
            ),
            actionsBuilder: (dialog) => [
              TextButton(onPressed: dialog.pop, child: Text(libL10n.cancel)),
              TextButton(
                onPressed: () => onSave(dialog),
                child: Text(libL10n.ok),
              ),
            ],
          );
        }),
      );
    });
  }

  /// The value on the right and a dialog behind the tap, which is how every
  /// other "pick one of these" row on this page behaves — a `PopupMenuButton`
  /// wrapped around a tile was the only one that dropped a menu instead.
  SettingsRow _buildAskAiProtocol(AppLocalizations l10n) {
    String name(AskAiProtocol protocol) => protocol.vendorName ?? libL10n.auto;

    return SettingsRow(
      libL10n.apiProtocol,
      () => ListTile(
        leading: const Icon(Icons.swap_calls_outlined),
        title: TipText(libL10n.apiProtocol, l10n.askAiProtocolTip),
        trailing: ValBuilder(
          listenable: _setting.askAiProtocol.listenable(),
          builder: (val) =>
              Text(name(parseAskAiProtocol(val)), style: UIs.text15),
        ),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: libL10n.apiProtocol,
            items: AskAiProtocol.values,
            display: name,
            initial: parseAskAiProtocol(_setting.askAiProtocol.fetch()),
          );
          if (selected != null) _setting.askAiProtocol.put(selected.name);
        },
      ),
      keywords: l10n.askAiProtocolTip,
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
      void onSave(BuildContext dialog) {
        unawaited(_persist(prop.set(ctrl.text.trim())));
        dialog.pop();
      }

      await context.showRoundDialog(
        title: title,
        childBuilder: (dialog) => Column(
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
              onSubmitted: (_) => onSave(dialog),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description, style: UIs.textGrey),
            ],
          ],
        ),
        actionsBuilder: (dialog) => [
          TextButton(
            onPressed: () {
              // Back to the default rather than off the map: a grouped field
              // has no row of its own to delete, and for these the default is
              // what an absent row read as anyway.
              unawaited(_persist(prop.remove()));
              dialog.pop();
            },
            child: Text(libL10n.clear),
          ),
          TextButton(
            onPressed: () => onSave(dialog),
            child: Text(libL10n.ok),
          ),
        ],
      );
    });
  }
}
