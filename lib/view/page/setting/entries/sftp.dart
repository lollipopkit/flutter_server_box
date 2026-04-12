part of '../entry.dart';

extension _SFTP on _AppSettingsPageState {
  Widget _buildSFTP() {
    return Column(
      children: [
        _buildSftpEditor(),
        _buildSftpRmrDir(),
        _buildSftpOpenLastPath(),
        _buildSftpShowFoldersFirst(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildSftpOpenLastPath() {
    return ListTile(
      leading: const Icon(MingCute.history_line),
      // title: Text(l10n.openLastPath),
      // subtitle: Text(l10n.openLastPathTip, style: UIs.textGrey),
      title: TipText(l10n.openLastPath, l10n.openLastPathTip),
      trailing: StoreSwitch(prop: _setting.sftpOpenLastPath),
    );
  }

  Widget _buildSftpShowFoldersFirst() {
    return ListTile(
      leading: const Icon(MingCute.folder_fill),
      title: Text(l10n.sftpShowFoldersFirst),
      trailing: StoreSwitch(prop: _setting.sftpShowFoldersFirst),
    );
  }

  Widget _buildSftpRmrDir() {
    return ListTile(
      leading: const Icon(MingCute.delete_2_fill),
      title: TipText('rm -r', l10n.sftpRmrDirSummary),
      trailing: StoreSwitch(prop: _setting.sftpRmrDir),
    );
  }

  Widget _buildSftpEditor() {
    return _setting.sftpEditor.listenable().listenVal((val) {
      return ListTile(
        leading: const Icon(MingCute.edit_fill),
        title: TipText(libL10n.editor, l10n.sftpEditorTip),
        trailing: Text(val.isEmpty ? libL10n.inner : val, style: UIs.text15),
        onTap: () => showTextSettingDialog(
          title: libL10n.select,
          initialValue: val,
          label: libL10n.editor,
          hint: '\$EDITOR / vim / nano ...',
          icon: Icons.edit,
          onSave: _setting.sftpEditor.put,
        ),
      );
    });
  }
}
