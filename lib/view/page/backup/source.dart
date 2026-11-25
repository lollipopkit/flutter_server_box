import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// Reads and writes backup content through a user-selected destination.
abstract class BackupSource {
  /// Reads backup content for a restore: as bytes, since an age file from
  /// the `age` CLI is binary unless armored.
  Future<Uint8List?> getContent();

  /// Writes the backup at [filePath] to this destination.
  Future<void> saveContent(String filePath);

  /// Localized name shown for this destination.
  String get displayName;

  /// Icon shown for this destination.
  IconData get icon;
}

/// Shares backup files and reads files selected by the user.
class FileBackupSource implements BackupSource {
  @override
  Future<Uint8List?> getContent() => Pfs.pickFileBytes();

  @override
  Future<void> saveContent(String filePath) async {
    await Pfs.sharePaths(paths: [filePath]);
  }

  @override
  String get displayName => libL10n.file;

  @override
  IconData get icon => Icons.file_open;
}

/// Copies backups to and restores backups from the clipboard.
class ClipboardBackupSource implements BackupSource {
  @override
  Future<Uint8List?> getContent() async {
    final text = await Pfs.paste();
    if (text == null || text.isEmpty) {
      return null;
    }
    return utf8.encode(text.trim());
  }

  @override
  Future<void> saveContent(String filePath) async {
    final content = await File(filePath).readAsString();
    Pfs.copy(content);
  }

  @override
  String get displayName => libL10n.clipboard;

  @override
  IconData get icon => Icons.content_paste;
}
