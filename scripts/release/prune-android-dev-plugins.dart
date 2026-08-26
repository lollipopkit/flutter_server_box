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
  if (removed.isNotEmpty) {
    stdout.writeln('Excluded Android dev plugins: ${removed.join(', ')}');
  }
}
