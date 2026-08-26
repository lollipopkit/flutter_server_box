import 'dart:convert';
import 'dart:io';

void main() {
  const packageName = 'server_box_generated_plugin_registrant';
  const packageConfigPath = '.dart_tool/package_config.json';

  final packageConfigFile = File(packageConfigPath);
  if (!packageConfigFile.existsSync()) {
    stderr.writeln('missing $packageConfigPath; run flutter pub get first');
    exitCode = 1;
    return;
  }

  final root =
      jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = root['packages'] as List<dynamic>;
  packages.removeWhere(
    (entry) => (entry as Map<String, dynamic>)['name'] == packageName,
  );
  packages.add({
    'name': packageName,
    'rootUri': 'flutter_build/',
    'packageUri': './',
  });
  packageConfigFile.writeAsStringSync('${jsonEncode(root)}\n');

  stdout.writeln(
    'Mapped Dart plugin registrant to '
    'package:$packageName/dart_plugin_registrant.dart',
  );
}
