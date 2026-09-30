import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// `docs/schemas/fsbt-manifest.schema.json` is what an editor reads while a
/// manifest is typed; the parser is what an install runs. Nothing else holds
/// the two together, so a value the schema offers and this build refuses
/// arrives as a valid-looking manifest that fails after the download.
void main() {
  final raw =
      jsonDecode(File('docs/schemas/fsbt-manifest.schema.json').readAsStringSync())
          as Map<String, dynamic>;
  final properties = _map(raw['properties']);
  final definitions = _map(raw['definitions']);

  /// The fields a schema node's object declares.
  Set<String> keysOf(dynamic node) => _map(_map(node)['properties']).keys.toSet();

  Set<String> enumOf(dynamic node) =>
      (node as Map<String, dynamic>)['enum']!.cast<String>().toSet();

  num bound(dynamic node, String key) =>
      (node as Map<String, dynamic>)[key] as num;

  group('top level', () {
    test('the schema names the tables the parser accepts', () {
      expect(properties.keys.toSet(), unorderedEquals(ThemePackages.sections));
    });

    test('the schema requires the keys that have no default', () {
      expect(
        raw['required'],
        unorderedEquals(['id', 'name', 'modes', 'schema']),
      );
    });

    test('an id is the same pattern a repository file is named by', () {
      expect(properties['id']['pattern'], ThemePackages.idPattern.pattern);
    });

    test('a variant takes the tables the parser merges, keyed as it reads', () {
      final variants = _map(properties['variants']);
      expect(variants['maxProperties'], ThemePackages.maxVariants);
      expect(
        _map(variants['propertyNames'])['pattern'],
        ThemePackages.variantKeyPattern.pattern,
      );
      final variant = _map(variants['additionalProperties']);
      expect(keysOf(variant), unorderedEquals(ThemePackages.variantFields));
      expect(variant['required'], ['name']);
      final name = _map(_map(variant['properties'])['name']);
      expect(name['maxLength'], ThemePackages.maxNameLength);
      expect(name['pattern'], properties['name']['pattern']);
    });

    test('a name is the same label the parser accepts', () {
      expect(properties['name']['maxLength'], ThemePackages.maxNameLength);
      expect(
        properties['name']['pattern'],
        r'^[^\u0000-\u001f]+$',
        reason: 'the parser refuses a control character anywhere in a name',
      );
    });
  });

  group('enums', () {
    test('modes, icon styles and background styles', () {
      expect(enumOf(properties['modes']['items']), ThemePackages.modes);
      expect(enumOf(properties['icons']['properties']['style']),
          ThemePackages.iconStyles);
      expect(enumOf(properties['background']['properties']['type']),
          ThemePackages.backgroundStyles);
    });

    test('the fixed file names', () {
      expect(
        enumOf(properties['background']['properties']['image']),
        ThemePackages.backgroundImages,
      );
      expect(
        enumOf(properties['splash']['properties']['logo']),
        ThemePackages.splashLogos,
      );
    });

    test('palette roles, in the palette and in a color reference', () {
      final color = _map(definitions['color']);
      final byName = (color['oneOf'] as List).whereType<Map<String, dynamic>>()
          .firstWhere((branch) => branch.containsKey('enum'));
      expect(enumOf(byName), ThemePalette.roles);
      expect(enumOf(definitions['roleName']), ThemePalette.roles);
    });
  });

  test('icon keys, and the file name each maps to', () {
    final images = _map(properties['icons']['properties']['images']);
    expect(images['additionalProperties'], false);
    expect(images['properties'].keys.toSet(), ThemePackages.iconKeys);
    expect(
      _map(properties['icons']['properties']['colors'])['properties']
          .keys
          .toSet(),
      ThemePackages.iconKeys,
      reason: 'a color for a key no image carries is refused anyway',
    );
    for (final entry in _map(images['properties']).entries) {
      final key = entry.key;
      expect(enumOf(entry.value), {
        'icons/${key.replaceAll('.', '_')}.png',
        'icons/${key.replaceAll('.', '_')}.svg',
      }, reason: key);
    }
  });

  group('bounds', () {
    test('shape and component numbers', () {
      expect(bound(definitions['ratio'], 'maximum'),
          ThemeComponents.maxRadius);
      expect(bound(definitions['borderWidth'], 'maximum'),
          ThemeComponents.maxBorderWidth);
      expect(bound(definitions['elevation'], 'maximum'),
          ThemeComponents.maxElevation);
      expect(bound(definitions['size'], 'maximum'), ThemeComponents.maxSize);
      expect(bound(definitions['thickness'], 'maximum'),
          ThemeComponents.maxThickness);
      expect(bound(_map(definitions['inset'])['items'], 'maximum'),
          ThemeComponents.maxInset);
      for (final node in [
        definitions['ratio'],
        definitions['borderWidth'],
        definitions['elevation'],
        definitions['size'],
        definitions['thickness'],
        definitions['inset']['items'],
      ]) {
        expect(bound(node, 'minimum'), 0);
      }
    });

    test('background opacity and blur', () {
      final background = _map(properties['background']['properties']);
      expect(bound(background['opacity'], 'maximum'),
          ThemePackages.maxBackgroundOpacity);
      expect(bound(background['blur'], 'maximum'),
          ThemePackages.maxBackgroundBlur);
      expect(bound(background['tile'], 'minimum'),
          ThemePackages.minBackgroundTile);
      expect(bound(background['tile'], 'maximum'),
          ThemePackages.maxBackgroundTile);
      expect(background.keys.toSet(), ThemePackages.backgroundFields);
    });

    test('splash duration', () {
      final duration = _map(properties['splash']['properties']['duration']);
      expect(bound(duration, 'minimum'), ThemeSplash.minDuration);
      expect(bound(duration, 'maximum'), ThemeSplash.maxDuration);
    });
  });

  group('components', () {
    test('the schema offers exactly the components the parser knows', () {
      expect(
        keysOf(properties['components']),
        unorderedEquals({...ThemeComponents.fields.keys, 'light', 'dark'}),
      );
      expect(
        keysOf(definitions['brightnessGroup']),
        unorderedEquals(ThemeComponents.fields.keys),
      );
    });

    for (final MapEntry(key: name, value: kinds) in ThemeComponents.kinds.entries) {
      test('$name takes the fields the parser accepts, each of its kind', () {
        final node = _map(_map(definitions[name])['properties']);
        final fields = {
          for (final MapEntry(:key, :value) in node.entries)
            if (!ThemeComponents.states.contains(key) ||
                !ThemeComponents.stateful.contains(name))
              key: value,
        };
        expect(fields.keys, unorderedEquals(kinds.keys));
        for (final MapEntry(key: field, value: kind) in kinds.entries) {
          expect(
            fields[field]['\$ref'],
            '#/definitions/${kind.definition}',
            reason: '$name.$field',
          );
        }
      });
    }

    test('the stateful components hold one table per state', () {
      for (final name in ThemeComponents.stateful) {
        final node = _map(_map(definitions[name])['properties']);
        for (final state in ThemeComponents.states) {
          expect(node[state]['\$ref'], '#/definitions/${name}State');
        }
        expect(
          keysOf(definitions['${name}State']),
          unorderedEquals(ThemeComponents.fields[name]!),
          reason: 'a state table takes the same fields without nesting',
        );
      }
    });

    test('every kind names a definition', () {
      for (final kind in ThemeFieldKind.values) {
        expect(definitions, contains(kind.definition), reason: kind.name);
      }
    });

    test('layout', () {
      expect(keysOf(properties['layout']),
          unorderedEquals(ThemeComponents.layoutFields));
      expect(
        enumOf(properties['layout']['properties']['density']),
        ThemeDensity.values.map((d) => d.name).toSet(),
      );
    });

    test('the component tables name the fields the parser accepts', () {
      final fields = keysOf(properties['icons']);
      expect(fields, unorderedEquals(ThemePackages.iconFields));
      final splash = keysOf(properties['splash']);
      expect(splash, unorderedEquals(ThemePackages.splashFields));
    });
  });
}

Map<String, dynamic> _map(dynamic value) => (value as Map).cast<String, dynamic>();
