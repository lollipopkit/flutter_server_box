/// One blob as a monitor agent's store lists it.
///
/// The agent answers a name, a size and a timestamp, never the bytes: what is
/// in a blob is the encrypted backup this app wrote, and an agent holds it
/// without being able to read it. That is the point of the store, so there is
/// nothing here to decrypt and nothing to show.
///
/// Hand-written rather than generated, for `PortForwardConfig`'s reason: three
/// fields whose names the agent fixed, read in one place, do not need a
/// `build_runner` pass and a `.g.dart` that would then have to be kept in step.
final class MonitorBackupBlob {
  const MonitorBackupBlob({
    required this.name,
    required this.size,
    required this.updatedAt,
  });

  /// The name the blob is stored under. The app's own file is
  /// `Miscs.bakFileName`, and it is the same name on the agent.
  final String name;

  /// Bytes, as the agent's file system holds it.
  final int size;

  /// RFC 3339 with an offset, from the file's own timestamp on the agent.
  final String updatedAt;

  /// What a sync compares to decide whether the remote copy moved.
  ///
  /// A size and a timestamp rather than a hash: the agent does not read a blob,
  /// so it has nothing to hash, and a sync only ever asks whether the token it
  /// ended on is the token it finds — never which of two is newer.
  String get versionTag => '$updatedAt/$size';

  /// Reads one entry. A field this build does not know is ignored, and one it
  /// needs but did not get reads as absent rather than throwing: an agent that
  /// added a field is not an agent this app cannot talk to.
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
