import 'package:server_box/data/model/file/file_backend.dart';

/// One entry of the agent's files API, as its `EntryView` describes it: what
/// the file browser shows, and the `version` a conditional write names.
final class MonitorFsEntry {
  const MonitorFsEntry(this.entry, {this.version});

  factory MonitorFsEntry.fromJson(Map<String, dynamic> json) {
    final modified = json['modified'];
    return MonitorFsEntry(
      FileEntry(
        name: json['name'] as String? ?? '',
        kind: switch (json['kind']) {
          'dir' => FileKind.dir,
          'file' => FileKind.file,
          'link' => FileKind.link,
          _ => FileKind.other,
        },
        size: (json['size'] as num?)?.toInt(),
        // Seconds on the wire, as SFTP reports them, so both remote backends
        // speak one unit.
        modified: modified is num
            ? DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000)
            : null,
        mode: (json['mode'] as num?)?.toInt(),
        linkTarget: json['link_target'] as String?,
      ),
      version: json['version'] as String?,
    );
  }

  final FileEntry entry;

  /// Null from an agent that does not report one.
  final String? version;
}
