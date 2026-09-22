import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// Reads and writes backup content through a user-selected destination.
abstract class BackupSource {
  /// Reads backup content for a restore.
  Future<String?> getContent();

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
  Future<String?> getContent() async {
    return await Pfs.pickFileString();
  }

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
  Future<String?> getContent() async {
    final text = await Pfs.paste();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text.trim();
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
