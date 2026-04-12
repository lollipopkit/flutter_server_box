part of '../entry.dart';

extension _Editor on _AppSettingsPageState {
  Future<void> _pickEditorTheme(HiveProp<String> property) async {
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

  Widget _buildEditor() {
    return Column(
      children: [
        _buildEditorWrap(),
        _buildEditorFontFamily(),
        _buildEditorFontSize(),
        _buildEditorTheme(),
        _buildEditorDarkTheme(),
        _buildEditorHighlight(),
        _buildEditorCloseAfterEdit(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildEditorCloseAfterEdit() {
    return ListTile(
      leading: const Icon(MingCute.edit_fill),
      title: Text(l10n.closeAfterSave),
      trailing: StoreSwitch(prop: _setting.closeAfterSave),
    );
  }

  Widget _buildEditorHighlight() {
    return ListTile(
      leading: const Icon(MingCute.code_line, size: _kIconSize),
      // title: Text(l10n.highlight),
      // subtitle: Text(l10n.editorHighlightTip, style: UIs.textGrey),
      title: TipText(l10n.highlight, l10n.editorHighlightTip),
      trailing: StoreSwitch(prop: _setting.editorHighlight),
    );
  }

  Widget _buildEditorTheme() {
    return ListTile(
      leading: const Icon(MingCute.sun_fill),
      title: Text('${libL10n.bright} ${libL10n.theme.toLowerCase()}'),
      trailing: ValBuilder(
        listenable: _setting.editorTheme.listenable(),
        builder: (val) => Text(val, style: UIs.text15),
      ),
      onTap: () => _pickEditorTheme(_setting.editorTheme),
    );
  }

  Widget _buildEditorDarkTheme() {
    return ListTile(
      leading: const Icon(MingCute.moon_stars_fill),
      title: Text('${libL10n.dark} ${libL10n.theme.toLowerCase()}'),
      trailing: ValBuilder(
        listenable: _setting.editorDarkTheme.listenable(),
        builder: (val) => Text(val, style: UIs.text15),
      ),
      onTap: () => _pickEditorTheme(_setting.editorDarkTheme),
    );
  }

  Widget _buildEditorWrap() {
    return ListTile(
      leading: const Icon(MingCute.align_center_line),
      title: Text(l10n.softWrap),
      trailing: StoreSwitch(prop: _setting.editorSoftWrap),
    );
  }

  Widget _buildEditorFontSize() {
    return ListTile(
      leading: const Icon(MingCute.font_size_line),
      title: Text(l10n.fontSize),
      trailing: ValBuilder(
        listenable: _setting.editorFontSize.listenable(),
        builder: (val) => Text(val.toString(), style: UIs.text15),
      ),
      onTap: () => _showFontSizeDialog(_setting.editorFontSize),
    );
  }

  Widget _buildEditorFontFamily() {
    return ListTile(
      leading: const Icon(MingCute.font_fill),
      title: Text(libL10n.font),
      trailing: ValBuilder(
        listenable: _setting.editorFontFamily.listenable(),
        builder: (val) => Text(
          val.isEmpty ? libL10n.auto.toLowerCase() : val,
          style: UIs.text15,
        ),
      ),
      onTap: () => _showFontFamilyDialog(_setting.editorFontFamily),
    );
  }

  void _showFontFamilyDialog(HiveProp<String> property) {
    final ctrl = TextEditingController(text: property.fetch());
    void onSave() {
      context.pop();
      property.put(ctrl.text.trim());
    }

    context.showRoundDialog(
      title: libL10n.font,
      child: Input(
        controller: ctrl,
        autoFocus: true,
        type: TextInputType.text,
        icon: Icons.font_download,
        hint: 'monospace / Consolas / Fira Code ...',
        suggestion: false,
        onSubmitted: (_) => onSave(),
      ),
      actions: Btn.ok(onTap: onSave).toList,
    );
  }

  void _showFontSizeDialog(HiveProp<double> property) {
    final ctrl = TextEditingController(text: property.fetch().toString());
    void onSave() {
      context.pop();
      final fontSize = double.tryParse(ctrl.text);
      if (fontSize == null) {
        context.showRoundDialog(
          title: libL10n.fail,
          child: Text('Parsed failed: ${ctrl.text}'),
        );
        return;
      }
      property.set(fontSize);
    }

    context.showRoundDialog(
      title: l10n.fontSize,
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
