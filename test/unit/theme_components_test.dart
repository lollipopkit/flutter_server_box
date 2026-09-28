import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
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

  test('button is the primary button only; the others have their own', () {
    final theme = ThemeComponents.parse(<String, dynamic>{
      'button': {'backgroundColor': 'primary', 'minHeight': 44},
      'textButton': {'foregroundColor': 'tertiary', 'minHeight': 28},
      'iconButton': {'iconSize': 18, 'minHeight': 36},
    }).apply(ThemeData());
    final scheme = theme.colorScheme;
    for (final style in [
      theme.elevatedButtonTheme.style!,
      theme.filledButtonTheme.style!,
    ]) {
      expect(style.backgroundColor!.resolve({}), scheme.primary);
      expect(
        style.minimumSize!.resolve({}),
        const Size(64, 44),
        reason: 'a height, and Material\'s own minimum width',
      );
    }
    final text = theme.textButtonTheme.style!;
    expect(text.backgroundColor, isNull, reason: 'a text button stays flat');
    expect(text.foregroundColor!.resolve({}), scheme.tertiary);
    expect(text.minimumSize!.resolve({}), const Size(64, 28));
    expect(theme.outlinedButtonTheme.style, isNull);
    expect(theme.iconButtonTheme.style!.iconSize!.resolve({}), 18);
    expect(
      theme.iconButtonTheme.style!.minimumSize!.resolve({}),
      const Size(40, 36),
    );

    // A width the app's own style already sets is kept.
    final kept = ThemeComponents.parse(<String, dynamic>{
      'textButton': {'minHeight': 30},
    }).apply(
      ThemeData(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(20, 50)),
        ),
      ),
    );
    expect(
      kept.textButtonTheme.style!.minimumSize!.resolve({}),
      const Size(20, 30),
    );
  });

  test('a field inside a search pill ignores the input theme', () {
    // One Dark Pro's settings search: `input` sets enabledBorder and a fill,
    // and a field that only said `border: InputBorder.none` drew a box inside
    // the pill it sits in.
    final field = ThemeComponents.parse(<String, dynamic>{
      'input': {
        'filled': true,
        'fillColor': 'surfaceContainer',
        'borderColor': 'outline',
        'focusedBorderColor': 'primary',
      },
    }).apply(ThemeData()).inputDecorationTheme;
    final bare = bareInputDecoration(hintText: 'Search').applyDefaults(field);
    expect(bare.filled, isFalse);
    for (final border in [
      bare.border,
      bare.enabledBorder,
      bare.focusedBorder,
      bare.errorBorder,
      bare.focusedErrorBorder,
      bare.disabledBorder,
    ]) {
      expect(border, InputBorder.none);
    }
  });

  test('a border of width 0, or none at all, draws no line', () {
    // Flutter draws a solid `BorderSide(width: 0)` as a one-pixel hairline, so
    // a tile given only a radius came out outlined.
    final theme = ThemeComponents.parse(<String, dynamic>{
      'tile': {'radius': 14},
      'card': {'radius': 0, 'borderWidth': 0, 'borderColor': 'outline'},
      'button': {'borderWidth': 0},
      'tooltip': {'borderWidth': 0},
    }).apply(ThemeData());
    RoundedRectangleBorder rounded(ShapeBorder? s) => s! as RoundedRectangleBorder;
    expect(rounded(theme.listTileTheme.shape).side, BorderSide.none);
    expect(
      rounded(theme.listTileTheme.shape).borderRadius,
      BorderRadius.circular(14),
    );
    expect(rounded(theme.cardTheme.shape).side, BorderSide.none);
    expect(theme.elevatedButtonTheme.style!.side!.resolve({}), BorderSide.none);
    expect(
      (theme.tooltipTheme.decoration! as BoxDecoration).border,
      const Border.fromBorderSide(BorderSide.none),
    );
  });

  test('schema 3 is needed past what schema 2 had', () {
    int needed(Map<String, dynamic> raw, {Object? layout}) =>
        ThemeComponents.parse(raw, layout: layout).neededSchema;
    expect(needed({}), 1);
    expect(
      needed({
        'card': {'radius': 4},
        'button': {
          'radius': 4,
          'hovered': {'elevation': 2},
        },
        'dark': {
          'sheet': {'radius': 4},
        },
      }),
      1,
    );
    expect(needed({'search': {'height': 30}}), 3);
    expect(needed({'button': {'minHeight': 30}}), 3);
    expect(
      needed({
        'button': {
          'hovered': {'minHeight': 30},
        },
      }),
      3,
      reason: 'a new field inside a state table',
    );
    expect(
      needed({
        'light': {
          'divider': {'thickness': 1},
        },
      }),
      3,
    );
    expect(needed({}, layout: {'density': 'compact'}), 3);
  });

  test('layout density applies and roundtrips; bad layouts fail', () {
    final config = ThemeComponents.parse(null, layout: {'density': 'compact'});
    expect(config.density, ThemeDensity.compact);
    expect(config.layoutMap(), {'density': 'compact'});
    expect(
      config.apply(ThemeData()).visualDensity,
      VisualDensity.compact,
    );
    expect(ThemeComponents.parse(null, layout: <String, dynamic>{}).layoutMap(),
        isNull);
    for (final layout in <Object>[
      [],
      {'density': 'tiny'},
      {'density': 1},
      {'gap': 4},
    ]) {
      expect(
        () => ThemeComponents.parse(null, layout: layout),
        throwsFormatException,
        reason: '$layout',
      );
    }
  });

  test('schema 3 components reach their Material themes', () {
    final theme = ThemeComponents.parse(<String, dynamic>{
      'appBar': {'backgroundColor': 'surface', 'iconColor': 'primary'},
      'segmented': {'selectedColor': 'secondaryContainer', 'radius': 6},
      'menu': {'backgroundColor': 'surfaceContainer', 'radius': 5},
      'tooltip': {'backgroundColor': 'tertiary', 'padding': [1, 2, 3, 4]},
      'toast': {'backgroundColor': 'inverseSurface', 'radius': 7},
      'switch': {'thumbColor': 'outline', 'selectedThumbColor': 'onPrimary'},
      'slider': {'trackHeight': 3},
      'progress': {'thickness': 5, 'trackColor': 'surfaceContainerHighest'},
      'badge': {'backgroundColor': 'error', 'largeSize': 18},
      'chip': {'selectedColor': 'secondaryContainer', 'borderWidth': 1},
      'divider': {'color': 'outlineVariant', 'thickness': 2},
      'scrollbar': {'thickness': 6, 'radius': 3},
    }).apply(ThemeData());
    final scheme = theme.colorScheme;
    expect(theme.appBarTheme.backgroundColor, scheme.surface);
    expect(theme.appBarTheme.actionsIconTheme!.color, scheme.primary);
    expect(
      theme.segmentedButtonTheme.style!.backgroundColor!.resolve({
        WidgetState.selected,
      }),
      scheme.secondaryContainer,
    );
    expect(theme.popupMenuTheme.color, scheme.surfaceContainer);
    expect(
      (theme.popupMenuTheme.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(5),
    );
    expect(
      (theme.tooltipTheme.decoration! as BoxDecoration).color,
      scheme.tertiary,
    );
    expect(theme.tooltipTheme.padding, const EdgeInsets.fromLTRB(1, 2, 3, 4));
    expect(theme.snackBarTheme.backgroundColor, scheme.inverseSurface);
    expect(theme.switchTheme.thumbColor!.resolve({}), scheme.outline);
    expect(
      theme.switchTheme.thumbColor!.resolve({WidgetState.selected}),
      scheme.onPrimary,
    );
    expect(theme.sliderTheme.trackHeight, 3);
    expect(theme.progressIndicatorTheme.linearMinHeight, 5);
    expect(theme.badgeTheme.backgroundColor, scheme.error);
    expect(theme.badgeTheme.largeSize, 18);
    expect(theme.chipTheme.selectedColor, scheme.secondaryContainer);
    expect(theme.dividerTheme.color, scheme.outlineVariant);
    expect(theme.dividerTheme.thickness, 2);
    expect(theme.scrollbarTheme.thickness!.resolve({}), 6);

    final styles = theme.extension<ComponentStyles>()!;
    expect(styles.segmented.selectedColor, scheme.secondaryContainer);
    expect(styles.segmented.radius, 6);
    expect(styles.toast.radius, 7);
  });

  test('the library styles follow the brightness, and replace a stale one', () {
    final config = ThemeComponents.parse(<String, dynamic>{
      'search': {'height': 30},
      'dark': {
        'search': {'backgroundColor': 'surfaceContainerHigh'},
      },
    });
    final dark = config.apply(
      ThemeData(
        brightness: Brightness.dark,
        extensions: const [ComponentStyles(search: SearchFieldStyle(height: 1))],
      ),
    );
    final styles = dark.extensions.values.whereType<ComponentStyles>();
    expect(styles, hasLength(1));
    expect(styles.single.search.height, 30);
    expect(
      styles.single.search.backgroundColor,
      dark.colorScheme.surfaceContainerHigh,
    );
    final light = config.apply(ThemeData());
    expect(light.extension<ComponentStyles>()!.search.backgroundColor, isNull);
  });

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
      {
        'search': {'height': 97},
      },
      {
        'divider': {'thickness': 17},
      },
      {
        'appBar': {'height': 40},
      },
      {
        'textButton': {
          'hovered': {'iconSize': 20},
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
