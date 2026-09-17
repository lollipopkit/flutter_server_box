import 'dart:convert';

/// What `system df` answers: how many images the runtime holds, and how many
/// bytes a full prune would give back.
///
/// Fetched on its own rather than with `ps`/`stats`: on a host with many
/// images the command walks the whole image store, which is several hundred
/// milliseconds it would otherwise add to every poll.
final class ContainerDiskUsage {
  const ContainerDiskUsage({this.imageCount, this.reclaimableBytes});

  /// Total images, active and dangling alike. Null when the runtime did not
  /// report an `Images` row.
  final int? imageCount;

  /// Summed over every type the runtime reported — images, stopped
  /// containers, unused volumes and build cache — because that is what the
  /// prune actions on this page between them reclaim.
  final int? reclaimableBytes;

  bool get isEmpty => imageCount == null && reclaimableBytes == null;

  /// Reads both Docker's newline-delimited objects and Podman's JSON array.
  ///
  /// Every field is a human-readable string on at least one of the two
  /// runtimes (`"12"`, `"809MB (56%)"`), so nothing here assumes a number.
  static ContainerDiskUsage? parse(String raw) {
    final rows = _rows(raw);
    if (rows.isEmpty) return null;

    int? imageCount;
    int? reclaimable;
    for (final row in rows) {
      final type = row['Type']?.toString().toLowerCase();
      if (type == 'images') {
        imageCount = _asCount(row['TotalCount'] ?? row['Total']);
      }
      final bytes = parseSize(row['Reclaimable']?.toString());
      if (bytes != null) reclaimable = (reclaimable ?? 0) + bytes;
    }

    final usage = ContainerDiskUsage(
      imageCount: imageCount,
      reclaimableBytes: reclaimable,
    );
    return usage.isEmpty ? null : usage;
  }

  static List<Map<String, dynamic>> _rows(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    // Podman answers one array; Docker answers one object per line.
    try {
      final decoded = json.decode(trimmed);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      if (decoded is Map<String, dynamic>) return [decoded];
    } on FormatException {
      // Not a single document — fall through to the line-by-line read.
    }

    final rows = <Map<String, dynamic>>[];
    for (final line in trimmed.split('\n')) {
      final value = line.trim();
      if (value.isEmpty) continue;
      try {
        final decoded = json.decode(value);
        if (decoded is Map<String, dynamic>) rows.add(decoded);
      } on FormatException {
        continue;
      }
    }
    return rows;
  }

  static int? _asCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  /// `809MB (56%)` → 809000000. Returns null for anything unparseable, which
  /// is how a runtime that reported nothing stays distinguishable from one
  /// that reported zero.
  ///
  /// Both runtimes print decimal units (`kB`, `MB`) through Go's
  /// `units.HumanSize`, so a plain unit is 1000-based and only the `i` forms
  /// are 1024-based.
  static int? parseSize(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final match = RegExp(
      r'^([\d.]+)\s*([kKMGTP]?i?)B',
    ).firstMatch(value);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null) return null;

    final unit = match.group(2) ?? '';
    final binary = unit.endsWith('i');
    final base = binary ? 1024 : 1000;
    final exponent = switch (unit.isEmpty ? '' : unit[0].toUpperCase()) {
      'K' => 1,
      'M' => 2,
      'G' => 3,
      'T' => 4,
      'P' => 5,
      _ => 0,
    };
    var multiplier = 1;
    for (var i = 0; i < exponent; i++) {
      multiplier *= base;
    }
    return (amount * multiplier).round();
  }

  @override
  bool operator ==(Object other) =>
      other is ContainerDiskUsage &&
      other.imageCount == imageCount &&
      other.reclaimableBytes == reclaimableBytes;

  @override
  int get hashCode => Object.hash(imageCount, reclaimableBytes);

  @override
  String toString() =>
      'ContainerDiskUsage(images: $imageCount, reclaimable: $reclaimableBytes)';
}
