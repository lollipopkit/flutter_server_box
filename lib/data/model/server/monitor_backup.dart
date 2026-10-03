/// One blob as a monitor agent's backup store lists it: a name, a size and a
/// timestamp, never the bytes.
///
/// Hand-written rather than generated: three fields whose names the agent
/// fixed, read in one place.
final class MonitorBackupBlob {
  const MonitorBackupBlob({
    required this.name,
    required this.size,
    required this.updatedAt,
  });

  final String name;

  /// Bytes.
  final int size;

  /// RFC 3339, as the agent wrote it.
  final String updatedAt;

  /// What a sync compares to decide whether the remote copy changed. The
  /// agent does not read a blob, so it has no hash to offer.
  String get versionTag => '$updatedAt/$size';

  factory MonitorBackupBlob.fromJson(Map<String, dynamic> json) {
    return MonitorBackupBlob(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  @override
  String toString() => 'MonitorBackupBlob($name, $size bytes, $updatedAt)';
}

/// `GET /api/v1/backup`: the blobs, and the most one may be.
final class MonitorBackupList {
  const MonitorBackupList({required this.blobs, this.maxBytes});

  final List<MonitorBackupBlob> blobs;

  /// Null when the agent did not say.
  final int? maxBytes;

  factory MonitorBackupList.fromJson(Map<String, dynamic> json) {
    final raw = json['blobs'];
    return MonitorBackupList(
      blobs: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(MonitorBackupBlob.fromJson)
                .toList()
          : const [],
      maxBytes: (json['max_bytes'] as num?)?.toInt(),
    );
  }
}
