import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_components.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/service/theme_palette.dart';
import 'package:toml/toml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Aurora documents every palette role and component field', () {
    final manifest = TomlDocument.parse(
      File('docs/examples/aurora/manifest.toml').readAsStringSync(),
    ).toMap();
    final palette = (manifest['colors'] as Map)['palette'] as Map;
    for (final mode in ['light', 'dark']) {
      expect((palette[mode] as Map).keys, unorderedEquals(ThemePalette.roles));
    }
    final components = manifest['components'] as Map;
    for (final entry in ThemeComponents.fields.entries) {
      final keys = (components[entry.key] as Map).keys.cast<String>().where(
        (key) => !ThemeComponents.states.contains(key),
      );
      expect(keys, unorderedEquals(entry.value), reason: entry.key);
    }
  });

  test('omitted components preserve the original theme', () {
    final base = ThemeData();
    expect(ThemeComponents.parse(null).apply(base), same(base));
    expect(ThemeComponents.parse(<String, dynamic>{}).apply(base), same(base));
  });

  test('common and dark styles merge, references use the active palette', () {
    final config = ThemeComponents.parse(<String, dynamic>{
      'card': {
        'radius': 17,
        'borderWidth': 2,
        'borderColor': 'outline',
        'elevation': 4,
      },
      'button': {
        'radius': 8,
        'foregroundColor': 'onPrimary',
        'backgroundColor': 'primary',
        'hovered': {'radius': 12, 'elevation': 5},
        'disabled': {'foregroundColor': 'outline'},
      },
      'dark': {
        'card': {'backgroundColor': 'surfaceContainer'},
        'button': {
          'hovered': {'backgroundColor': 'secondary'},
          'pressed': {'radius': 3},
        },
      },
    });
    final dark = config.apply(ThemeData(brightness: Brightness.dark));
    final light = config.apply(ThemeData(brightness: Brightness.light));
    expect(light.cardTheme.color, isNull);
    expect(dark.cardTheme.color, dark.colorScheme.surfaceContainer);
    expect(dark.cardTheme.elevation, 4);
    final shape = dark.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(17));
    expect(shape.side, BorderSide(color: dark.colorScheme.outline, width: 2));
    final button = dark.elevatedButtonTheme.style!;
    expect(
      button.backgroundColor!.resolve({WidgetState.hovered}),
      dark.colorScheme.secondary,
    );
    expect(button.elevation!.resolve({WidgetState.hovered}), 5);
    expect(
      (button.shape!.resolve({WidgetState.hovered, WidgetState.pressed})!
              as RoundedRectangleBorder)
          .borderRadius,
      BorderRadius.circular(3),
    );
    expect(
      button.foregroundColor!.resolve({
        WidgetState.disabled,
        WidgetState.hovered,
      }),
      dark.colorScheme.outline,
    );
    expect(button.backgroundColor!.resolve({}), dark.colorScheme.primary);
    expect(
      light.elevatedButtonTheme.style!.backgroundColor!.resolve({
        WidgetState.hovered,
      }),
      light.colorScheme.primary,
    );
  });

  test(
    'component overrides reach input, navigation, tile, dialog and sheet',
    () {
      final config = ThemeComponents.parse(<String, dynamic>{
        'input': {
          'filled': true,
          'fillColor': 'surfaceContainer',
          'radius': 9,
          'focusedBorderColor': 'primary',
          'errorBorderColor': 'error',
          'disabledBorderColor': 'outlineVariant',
          'borderWidth': 2,
          'padding': [1, 2, 3, 4],
        },
        'navigation': {
          'indicatorColor': 'tertiary',
          'indicatorRadius': 10,
          'selectedIconColor': 'onTertiary',
          'unselectedLabelColor': 'onSurfaceVariant',
          'elevation': 3,
        },
        'tile': {
          'textColor': 'secondary',
          'selectedTileColor': 'secondaryContainer',
          'padding': [4, 5, 6, 7],
        },
        'dialog': {
          'backgroundColor': 'surface',
          'radius': 18,
          'insetPadding': [8, 9, 10, 11],
          'barrierColor': 0x80000000,
        },
        'sheet': {
          'backgroundColor': 'surfaceContainer',
          'radius': 24,
          'elevation': 0,
          'dragHandleColor': 'outline',
          'barrierColor': 0x40000000,
        },
      });
      final theme = config.apply(ThemeData());
      final input = theme.inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.contentPadding, const EdgeInsets.fromLTRB(1, 2, 3, 4));
      expect(input.focusedBorder!.borderSide.color, theme.colorScheme.primary);
      expect(input.errorBorder!.borderSide.color, theme.colorScheme.error);
      expect(
        input.disabledBorder!.borderSide.color,
        theme.colorScheme.outlineVariant,
      );
      expect(
        theme.navigationRailTheme.indicatorColor,
        theme.colorScheme.tertiary,
      );
      expect(
        theme.navigationBarTheme.iconTheme!.resolve({
          WidgetState.selected,
        })!.color,
        theme.colorScheme.onTertiary,
      );
      expect(theme.listTileTheme.textColor, theme.colorScheme.secondary);
      expect(
        theme.dialogTheme.insetPadding,
        const EdgeInsets.fromLTRB(8, 9, 10, 11),
      );
      expect(theme.dialogTheme.barrierColor, const Color(0x80000000));
      expect(
        theme.bottomSheetTheme.modalBackgroundColor,
        theme.colorScheme.surfaceContainer,
      );
      expect(theme.bottomSheetTheme.modalElevation, 0);
      expect(theme.bottomSheetTheme.dragHandleColor, theme.colorScheme.outline);
    },
  );

  test(
    'partial button states preserve existing shape and resolver fallbacks',
    () {
      final base = ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? Colors.grey
                  : Colors.blue,
            ),
          ),
        ),
      );
      final result = ThemeComponents.parse(<String, dynamic>{
        'button': {
          'hovered': {'borderColor': 'primary', 'backgroundColor': 'secondary'},
        },
      }).apply(base).elevatedButtonTheme.style!;
      expect(result.backgroundColor!.resolve({}), Colors.blue);
      expect(
        result.backgroundColor!.resolve({WidgetState.disabled}),
        Colors.grey,
      );
      expect(
        (result.shape!.resolve({WidgetState.hovered})!
                as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(27),
      );
    },
  );

  test('invalid component fields, colors, states and numeric bounds fail', () {
    for (final raw in <Object?>[
      [],
      {'unknown': {}},
      {
        'light': {'dark': {}},
      },
      {
        'card': {'unknown': 1},
      },
      {
        'card': {'radius': double.nan},
      },
      {
        'card': {'radius': -1},
      },
      {
        'card': {'elevation': 25},
      },
      {
        'card': {'borderWidth': 9},
      },
      {
        'card': {'backgroundColor': 0x100000000},
      },
      {
        'card': {'backgroundColor': 'notAColor'},
      },
      {
        'card': {'backgroundColor': null},
      },
      {
        'input': {'filled': 1},
      },
      {
        'tile': {
          'padding': [1, 2],
        },
      },
      {
        'tile': {
          'padding': [1, 2, 3, double.infinity],
        },
      },
      {
        'button': {
          'hovered': {'pressed': {}},
        },
      },
      {
        'button': {
          'hovered': {'radius': '10'},
        },
      },
      {
        'sheet': {
          'hovered': {'backgroundColor': 'primary'},
        },
      },
    ]) {
      expect(
        () => ThemeComponents.parse(raw),
        throwsFormatException,
        reason: '$raw',
      );
    }
  });

  test(
    'all supported palette roles roundtrip and apply to ColorScheme',
    () async {
      final root = await Directory.systemTemp.createTemp('theme-components-');
      addTearDown(() => root.delete(recursive: true));
      final palette = <String, int>{
        for (final (index, role) in ThemePalette.roles.indexed)
          role: 0xff000000 + index,
      };
      final source = TomlDocument.fromMap({
        'id': 'test.components',
        'name': 'Components',
        'modes': ['light', 'dark'],
        'schema': {'min': 1, 'max': 1},
        'colors': {
          'palette': {'dark': palette},
        },
        'components': {
          'card': {'radius': 20},
          'dark': {
            'card': {'backgroundColor': 'tertiary'},
          },
        },
      }).toString();
      final installed = await ThemePackages.installAssets({
        'manifest.toml': Uint8List.fromList(utf8.encode(source)),
      }, rootDirectory: root.path);
      final restored = ThemePackages.installed(
        installed.installationId,
        rootDirectory: root.path,
      )!;
      final scheme = ThemePackages.applyPalette(
        ColorScheme.fromSeed(seedColor: Colors.blue),
        restored.paletteDark,
      );
      expect(ThemePalette.roles.length, 46);
      for (final role in palette.keys) {
        expect(ThemePalette.resolve(scheme, role).toARGB32(), palette[role]);
      }
      final styled = restored.components.apply(
        ThemeData(colorScheme: scheme.copyWith(brightness: Brightness.dark)),
      );
      expect(styled.cardTheme.color, scheme.tertiary);
      expect(
        (styled.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(20),
      );
    },
  );
}
