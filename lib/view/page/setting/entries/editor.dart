part of '../entry.dart';

extension _Editor on _AppSettingsPageState {
  Future<void> _pickEditorTheme(SqliteProp<String> property) async {
    final selected = await context.showPickSingleDialog(
      title: libL10n.theme,
      items: themeMap.keys.toList(),
      display: (p0) => p0,
      initial: property.fetch(),
    );
    if (selected != null) {
      property.put(selected);
    }
  }

  List<SettingsGroup> _buildEditor() {
    return [
      SettingsGroup(libL10n.general, [
        _buildEditorWrap(),
        _buildEditorHighlight(),
        _buildEditorCloseAfterEdit(),
      ]),
      SettingsGroup(libL10n.font, [
        _buildEditorFontFamily(),
        _buildEditorFontSize(),
      ]),
      SettingsGroup(libL10n.theme, [
        _buildEditorTheme(),
        _buildEditorDarkTheme(),
      ]),
    ];
  }

  SettingsRow _buildEditorCloseAfterEdit() {
    final label = l10n.closeAfterSave;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.edit_fill),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.closeAfterSave),
      ),
    );
  }

  SettingsRow _buildEditorHighlight() {
    final label = libL10n.highlight;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.code_line),
        title: TipText(label, l10n.editorHighlightTip),
        trailing: StoreSwitch(prop: _setting.editorHighlight),
      ),
      keywords: l10n.editorHighlightTip,
    );
  }

  SettingsRow _buildEditorTheme() {
    final label = '${libL10n.bright} ${libL10n.theme.toLowerCase()}';
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.sun_fill),
        title: Text(label),
        trailing: ValBuilder(
          listenable: _setting.editorTheme.listenable(),
          builder: (val) => Text(val, style: UIs.text15),
        ),
        onTap: () => _pickEditorTheme(_setting.editorTheme),
      ),
    );
  }

  SettingsRow _buildEditorDarkTheme() {
    final label = '${libL10n.dark} ${libL10n.theme.toLowerCase()}';
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.moon_stars_fill),
        title: Text(label),
        trailing: ValBuilder(
          listenable: _setting.editorDarkTheme.listenable(),
          builder: (val) => Text(val, style: UIs.text15),
        ),
        onTap: () => _pickEditorTheme(_setting.editorDarkTheme),
      ),
    );
  }

  SettingsRow _buildEditorWrap() {
    final label = libL10n.softWrap;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.align_center_line),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.editorSoftWrap),
      ),
    );
  }

  SettingsRow _buildEditorFontSize() {
    final label = libL10n.fontSize;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.font_size_line),
        title: Text(label),
        trailing: ValBuilder(
          listenable: _setting.editorFontSize.listenable(),
          builder: (val) => Text(val.toString(), style: UIs.text15),
        ),
        onTap: () => _showFontSizeDialog(_setting.editorFontSize),
      ),
    );
  }

  SettingsRow _buildEditorFontFamily() {
    final label = libL10n.font;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.font_fill),
        title: Text(label),
        trailing: ValBuilder(
          listenable: _setting.editorFontFamily.listenable(),
          builder: (val) => Text(
            val.isEmpty ? libL10n.auto.toLowerCase() : val,
            style: UIs.text15,
          ),
        ),
        onTap: () => _showFontFamilyDialog(_setting.editorFontFamily),
      ),
    );
  }

  void _showFontFamilyDialog(SqliteProp<String> property) {
    showTextSettingDialog(
      title: libL10n.font,
      initialValue: property.fetch() ?? '',
      label: libL10n.font,
      hint: 'monospace / Consolas / Fira Code ...',
      icon: Icons.font_download,
      onSave: property.put,
    );
  }

  void _showFontSizeDialog(SqliteProp<double> property) {
    final ctrl = TextEditingController(text: property.fetch().toString());
    void onSave() {
      context.popDialog();
      final fontSize = double.tryParse(ctrl.text);
      if (fontSize == null) {
        context.showRoundDialog(
          title: libL10n.fail,
          child: Text('${libL10n.invalid}: ${ctrl.text}'),
        );
        return;
      }
      property.set(fontSize);
    }

    context.showRoundDialog(
      title: libL10n.fontSize,
      child: Input(
        controller: ctrl,
        autoFocus: true,
        type: TextInputType.number,
        icon: Icons.font_download,
        suggestion: false,
        onSubmitted: (_) => onSave(),
      ),
      actions: Btn.ok(onTap: onSave).toList,
    );
  }
}
