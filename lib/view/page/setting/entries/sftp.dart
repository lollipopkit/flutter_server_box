part of '../entry.dart';

extension _SFTP on _AppSettingsPageState {
  List<SettingsGroup> _buildSFTP() {
    return [
      SettingsGroup(libL10n.general, [
        _buildSftpEditor(),
        _buildSftpRmrDir(),
        _buildSftpOpenLastPath(),
        _buildSftpShowFoldersFirst(),
      ]),
    ];
  }

  SettingsRow _buildSftpOpenLastPath() {
    final label = l10n.openLastPath;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.history_line),
        title: TipText(label, l10n.openLastPathTip),
        trailing: StoreSwitch(prop: _setting.sftpOpenLastPath),
      ),
      keywords: l10n.openLastPathTip,
    );
  }

  SettingsRow _buildSftpShowFoldersFirst() {
    final label = l10n.sftpShowFoldersFirst;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.folder_fill),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.sftpShowFoldersFirst),
      ),
    );
  }

  SettingsRow _buildSftpRmrDir() {
    const label = 'rm -r';
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.delete_2_fill),
        title: TipText(label, l10n.sftpRmrDirSummary),
        trailing: StoreSwitch(prop: _setting.sftpRmrDir),
      ),
      keywords: l10n.sftpRmrDirSummary,
    );
  }

  SettingsRow _buildSftpEditor() {
    final label = libL10n.editor;
    return SettingsRow(
      label,
      () => _setting.sftpEditor.listenable().listenVal((val) {
        return ListTile(
          leading: const Icon(MingCute.edit_fill),
          title: TipText(label, l10n.sftpEditorTip),
          trailing: Text(val.isEmpty ? libL10n.inner : val, style: UIs.text15),
          onTap: () => showTextSettingDialog(
            title: libL10n.select,
            initialValue: val,
            label: label,
            hint: '\$EDITOR / vim / nano ...',
            icon: Icons.edit,
            onSave: _setting.sftpEditor.put,
          ),
        );
      }),
      keywords: l10n.sftpEditorTip,
    );
  }
}
