import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('.flutter-plugins-dependencies');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final platforms = root['plugins'] as Map<String, dynamic>;
  final androidPlugins = platforms['android'] as List<dynamic>;

  final removed = <String>[];
  androidPlugins.removeWhere((entry) {
    final plugin = entry as Map<String, dynamic>;
    if (plugin['dev_dependency'] != true) return false;
    removed.add(plugin['name'] as String);
    return true;
  });

  file.writeAsStringSync('${jsonEncode(root)}\n');
  _pruneGeneratedAndroidRegistrant(removed.toSet());
  if (removed.isNotEmpty) {
    stdout.writeln('Excluded Android dev plugins: ${removed.join(', ')}');
  }
}

void _pruneGeneratedAndroidRegistrant(Set<String> removedPlugins) {
  if (removedPlugins.isEmpty) return;

  final file = File(
    'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
  );
  if (!file.existsSync()) return;

  final source = file.readAsStringSync();
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  final hasTrailingNewline = source.endsWith('\n');
  final lines = const LineSplitter().convert(source);
  final output = <String>[];

  for (var index = 0; index < lines.length;) {
    if (lines[index] == '    try {') {
      var end = index + 1;
      while (end < lines.length && lines[end] != '    }') {
        end++;
      }
      if (end < lines.length) {
        final block = lines.sublist(index, end + 1);
        final removesBlock = removedPlugins.any(
          (plugin) => block.any(
            (line) => line.contains('Error registering plugin $plugin,'),
          ),
        );
        if (removesBlock) {
          index = end + 1;
          continue;
        }
      }
    }

    output.add(lines[index]);
    index++;
  }

  final rewritten = output.join(newline) + (hasTrailingNewline ? newline : '');
  final remaining = removedPlugins.where(
    (plugin) => rewritten.contains('Error registering plugin $plugin,'),
  );
  if (remaining.isNotEmpty) {
    throw StateError(
      'Could not remove Android registrations for: ${remaining.join(', ')}',
    );
  }
  file.writeAsStringSync(rewritten);
}
