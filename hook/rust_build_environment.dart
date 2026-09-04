const _encodedRustFlagSeparator = '\u001f';

/// Cargo environment that keeps host-specific paths out of Rust artifacts.
Map<String, String> reproducibleCargoEnvironment({
  required Map<String, String> environment,
  required String packageRoot,
  required bool isWindows,
}) {
  final flags = <String>[
    if (environment['CARGO_ENCODED_RUSTFLAGS'] case final existing?
        when existing.isNotEmpty)
      existing,
    if (resolveCargoHome(environment, isWindows: isWindows)
        case final cargoHome?)
      _remapFlag(cargoHome, '/cargo', isWindows: isWindows),
    _remapFlag(packageRoot, '/source', isWindows: isWindows),
  ];

  return {'CARGO_ENCODED_RUSTFLAGS': flags.join(_encodedRustFlagSeparator)};
}

/// Resolves Cargo's default home without depending on the current directory.
String? resolveCargoHome(
  Map<String, String> environment, {
  required bool isWindows,
}) {
  final configured = environment['CARGO_HOME'];
  if (configured != null && configured.isNotEmpty) return configured;

  final home = isWindows
      ? _firstNonEmpty(environment['USERPROFILE'], environment['HOME'])
      : _firstNonEmpty(environment['HOME']);
  if (home == null) return null;

  final separator = isWindows ? r'\' : '/';
  return '${_trimTrailingSeparators(home, isWindows: isWindows)}'
      '$separator.cargo';
}

String _remapFlag(
  String source,
  String destination, {
  required bool isWindows,
}) =>
    '--remap-path-prefix='
    '${_trimTrailingSeparators(source, isWindows: isWindows)}=$destination';

String? _firstNonEmpty(String? first, [String? second]) {
  if (first != null && first.isNotEmpty) return first;
  if (second != null && second.isNotEmpty) return second;
  return null;
}

String _trimTrailingSeparators(String path, {required bool isWindows}) {
  var end = path.length;
  while (end > 1) {
    final candidate = path.substring(0, end);
    if (isWindows && RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(candidate)) break;
    final last = path.codeUnitAt(end - 1);
    if (last != 0x2f && last != 0x5c) break;
    end--;
  }
  return path.substring(0, end);
}
