/// What a manager shows of a failed command's output: its last non-empty line.
String lastOutputLine(String output, String fallback) {
  final lines = output.trim().split('\n').where((line) => line.trim().isNotEmpty);
  return lines.isEmpty ? fallback : lines.last.trim();
}

/// The first line of [output] without its `\r`, or null when empty.
String? firstOutputLine(String output) {
  final line = output.split('\n').first;
  final value = line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
  return value.isEmpty ? null : value;
}
