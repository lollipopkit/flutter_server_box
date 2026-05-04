List<int>? parseVersionParts(String raw) {
  final match = RegExp(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(raw);
  if (match == null) return null;
  return [
    int.parse(match.group(1)!),
    int.tryParse(match.group(2) ?? '') ?? 0,
    int.tryParse(match.group(3) ?? '') ?? 0,
  ];
}

bool isVersionLessThan(String raw, List<int> minimum) {
  final version = parseVersionParts(raw);
  if (version == null) return false;

  for (var i = 0; i < minimum.length; i++) {
    final currentPart = i < version.length ? version[i] : 0;
    final minimumPart = minimum[i];
    if (currentPart != minimumPart) {
      return currentPart < minimumPart;
    }
  }
  return false;
}
