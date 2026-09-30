import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/host.dart';

/// The skill the Agent ships with: read from the assets, which are the files
/// in `.claude/skills/`, and pointing at documentation that exists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('serverbox-help is shipped whole', () async {
    final skills = await LlmHost.builtinSkills();
    expect(skills.map((s) => s.name), ['serverbox-help']);
    expect(
      skills.single.files.keys,
      unorderedEquals(['SKILL.md', 'references/app.md', 'references/monitor.md']),
      reason: 'a file added to the skill needs its directory in pubspec.yaml',
    );
  });

  test('every documentation page it links to exists', () async {
    final skill = (await LlmHost.builtinSkills()).single;
    final text = skill.files.values.map(utf8.decode).join('\n');
    final links = RegExp(r'(?:https://serverbox\.lollipopkit\.com)?(/docs/[a-z0-9/-]+/)').allMatches(text);
    final pages = {for (final m in links) m[1]!};
    expect(pages, isNotEmpty);
    for (final page in pages) {
      final path = 'docs/src/content/docs/${page.substring('/docs/'.length, page.length - 1)}';
      // A page, or a section's index.
      final exists = page == '/docs/' ||
          ['.md', '.mdx', '/index.md', '/index.mdx'].any((ext) => File('$path$ext').existsSync());
      expect(exists, isTrue, reason: '$page has no $path.md(x)');
    }
  });
}
