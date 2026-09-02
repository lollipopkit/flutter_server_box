/// Shared tar safety helpers used by both Android and iOS rootfs installers.
///
/// Both installers unpack foreign tarballs into a per-profile directory. A
/// crafted archive can escape that directory (`../`, absolute `/`, or a symlink
/// ancestor), so every entry is vetted before it is written. The two
/// implementations were identical; this is the single source.

/// The components [name] names inside the root, or null where it escapes.
///
/// Strips leading `./` (many rootfs archives prefix with it), rejects absolute
/// `/`, and resolves `.` / `..` lexically. Empty list means the archive root
/// itself (`./`), which is neither safe nor unsafe — it just names the root.
List<String>? safeTarParts(String name) {
  var value = name;
  while (value.startsWith('./')) {
    value = value.substring(2);
  }
  if (value.startsWith('/')) return null;
  final parts = <String>[];
  for (final segment in value.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
    } else {
      parts.add(segment);
    }
  }
  return parts;
}

/// Whether any ancestor of [parts] (excluding the leaf) is in [links].
///
/// Guards against writing through a symlink that was itself unpacked earlier
/// in the same archive.
bool hasLinkAncestor(List<String> parts, Set<String> links) {
  for (var i = 1; i < parts.length; i++) {
    if (links.contains(parts.take(i).join('/'))) return true;
  }
  return false;
}

/// `name` without its leading `./`, if present.
String tarPath(String name) => name.startsWith('./') ? name.substring(2) : name;

/// Whether [name] is the archive root (`./`).
bool isTarRoot(String name) => safeTarParts(name)?.isEmpty ?? false;

/// Whether [name] can be written somewhere under the root.
bool isSafeTarEntry(String name) {
  final parts = safeTarParts(name);
  return parts != null && parts.isNotEmpty;
}
