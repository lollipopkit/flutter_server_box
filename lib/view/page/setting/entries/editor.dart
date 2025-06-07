part of '../entry.dart';

extension _Editor on _AppSettingsPageState {
  Widget _buildEditor() {
    return Column(
      children: [
        _buildEditorWrap(),
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
      title: Text('${libL10n.bright} ${l10n.theme.toLowerCase()}'),
      trailing: ValBuilder(
        listenable: _setting.editorTheme.listenable(),
        builder: (val) => Text(val, style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.theme,
          items: themeMap.keys.toList(),
          display: (p0) => p0,
          initial: _setting.editorTheme.fetch(),
        );
        if (selected != null) {
          _setting.editorTheme.put(selected);
        }
      },
    );
  }

  Widget _buildEditorDarkTheme() {
    return ListTile(
      leading: const Icon(MingCute.moon_stars_fill),
      title: Text('${libL10n.dark} ${l10n.theme.toLowerCase()}'),
      trailing: ValBuilder(
        listenable: _setting.editorDarkTheme.listenable(),
        builder: (val) => Text(val, style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.theme,
          items: themeMap.keys.toList(),
          display: (p0) => p0,
          initial: _setting.editorDarkTheme.fetch(),
        );
        if (selected != null) {
          _setting.editorDarkTheme.put(selected);
        }
      },
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
