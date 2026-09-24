import 'package:flutter/material.dart';

import 'package:server_box/core/service/theme_palette.dart';

/// Validated component overrides. Common values are merged with Light/Dark
/// overrides, then with the active button state. Missing fields inherit Flutter.
final class ThemeComponents {
  const ThemeComponents.empty() : _data = const {};
  const ThemeComponents._(this._data);

  final Map<String, dynamic> _data;

  static const _shape = {'radius', 'borderColor', 'borderWidth'};
  static const _surface = {
    'backgroundColor',
    'elevation',
    'shadowColor',
    'surfaceTintColor',
  };
  static const _button = {
    ..._shape,
    ..._surface,
    'foregroundColor',
    'overlayColor',
    'padding',
  };
  static const fields = <String, Set<String>>{
    'card': {..._shape, ..._surface, 'margin'},
    'tile': {
      ..._shape,
      'backgroundColor',
      'selectedTileColor',
      'textColor',
      'iconColor',
      'selectedColor',
      'padding',
    },
    'button': _button,
    'input': {
      ..._shape,
      'filled',
      'fillColor',
      'focusedBorderColor',
      'errorBorderColor',
      'disabledBorderColor',
      'padding',
    },
    'navigation': {
      'backgroundColor',
      'indicatorColor',
      'indicatorRadius',
      'selectedIconColor',
      'unselectedIconColor',
      'selectedLabelColor',
      'unselectedLabelColor',
      'elevation',
    },
    'dialog': {..._shape, ..._surface, 'barrierColor', 'insetPadding'},
    'sheet': {..._shape, ..._surface, 'barrierColor', 'dragHandleColor'},
  };
  // Highest-priority active state wins for each property independently.
  static const states = [
    'disabled',
    'pressed',
    'hovered',
    'focused',
    'selected',
  ];

  static ThemeComponents parse(Object? raw) {
    if (raw == null) return const ThemeComponents.empty();
    Map<String, dynamic> table(Object? value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid component table');
      }
      return value;
    }

    Map<String, dynamic> component(
      String name,
      Object? raw, {
      bool state = false,
    }) {
      final allowed = fields[name];
      if (allowed == null) throw FormatException('Unknown component: $name');
      final result = <String, dynamic>{};
      for (final entry in table(raw).entries) {
        final key = entry.key;
        final value = entry.value;
        if (name == 'button' && !state && states.contains(key)) {
          result[key] = component(name, value, state: true);
          continue;
        }
        if (!allowed.contains(key)) {
          throw FormatException('Unknown $name field: $key');
        }
        if (key.endsWith('Color')) {
          if (!(value is int && value >= 0 && value <= 0xffffffff) &&
              !(value is String && ThemePalette.roles.contains(value))) {
            throw FormatException('Invalid $name.$key color');
          }
        } else if (key == 'filled') {
          if (value is! bool) {
            throw const FormatException('Invalid filled flag');
          }
        } else if (key == 'padding' ||
            key == 'margin' ||
            key == 'insetPadding') {
          if (value is! List ||
              value.length != 4 ||
              value.any((v) => v is! num || !v.isFinite || v < 0 || v > 64)) {
            throw FormatException('Invalid $name.$key insets');
          }
          result[key] = List<num>.unmodifiable(value.cast<num>());
          continue;
        } else {
          final max = switch (key) {
            'borderWidth' => 8,
            'elevation' => 24,
            _ => 40,
          };
          if (value is! num || !value.isFinite || value < 0 || value > max) {
            throw FormatException('Invalid $name.$key number');
          }
        }
        result[key] = value;
      }
      return Map.unmodifiable(result);
    }

    Map<String, dynamic> group(Object? raw) => Map.unmodifiable({
      for (final entry in table(raw).entries)
        entry.key: component(entry.key, entry.value),
    });
    final data = <String, dynamic>{};
    for (final entry in table(raw).entries) {
      data[entry.key] = entry.key == 'light' || entry.key == 'dark'
          ? group(entry.value)
          : component(entry.key, entry.value);
    }
    return ThemeComponents._(Map.unmodifiable(data));
  }

  Map<String, dynamic> toMap() => _data;

  _Style _style(String name, ThemeData base) {
    final common = (_data[name] as Map<String, dynamic>?) ?? const {};
    final group = _data[base.brightness.name] as Map<String, dynamic>?;
    final specific = group?[name] as Map<String, dynamic>? ?? const {};
    return _Style({
      ...common,
      ...specific,
      for (final state in states)
        if (common.containsKey(state) || specific.containsKey(state))
          state: {
            ...?common[state] as Map<String, dynamic>?,
            ...?specific[state] as Map<String, dynamic>?,
          },
    }, base.colorScheme);
  }

  ThemeData apply(ThemeData base) {
    if (_data.isEmpty) return base;
    final card = _style('card', base);
    final tile = _style('tile', base);
    final input = _style('input', base);
    final navigation = _style('navigation', base);
    final dialog = _style('dialog', base);
    final sheet = _style('sheet', base);
    final button = _style('button', base);
    final rail = base.navigationRailTheme;
    final bar = base.navigationBarTheme;
    final field = base.inputDecorationTheme;

    InputBorder? inputBorder(String colorKey, InputBorder? fallback) {
      if (!input.hasAny({..._shape, colorKey})) return fallback;
      final border = fallback is OutlineInputBorder ? fallback : null;
      return OutlineInputBorder(
        borderRadius: input.number('radius') != null
            ? BorderRadius.circular(input.number('radius')!)
            : border?.borderRadius ?? BorderRadius.circular(8),
        borderSide: BorderSide(
          color:
              input.color(colorKey) ??
              input.color('borderColor') ??
              border?.borderSide.color ??
              base.colorScheme.outline,
          width: input.number('borderWidth') ?? border?.borderSide.width ?? 1,
        ),
      );
    }

    final indicatorShape = navigation.number('indicatorRadius') != null
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              navigation.number('indicatorRadius')!,
            ),
          )
        : null;
    final navigationIcons =
        navigation.hasAny({'selectedIconColor', 'unselectedIconColor'})
        ? WidgetStateProperty.resolveWith<IconThemeData?>((states) {
            final color = navigation.color(
              states.contains(WidgetState.selected)
                  ? 'selectedIconColor'
                  : 'unselectedIconColor',
            );
            final existing = bar.iconTheme?.resolve(states);
            return color == null
                ? existing
                : (existing ?? const IconThemeData()).copyWith(color: color);
          })
        : null;
    final navigationLabels =
        navigation.hasAny({'selectedLabelColor', 'unselectedLabelColor'})
        ? WidgetStateProperty.resolveWith<TextStyle?>((states) {
            final color = navigation.color(
              states.contains(WidgetState.selected)
                  ? 'selectedLabelColor'
                  : 'unselectedLabelColor',
            );
            final existing = bar.labelTextStyle?.resolve(states);
            return color == null
                ? existing
                : (existing ?? base.textTheme.labelMedium!).copyWith(
                    color: color,
                  );
          })
        : null;

    return base.copyWith(
      cardTheme: base.cardTheme.copyWith(
        color: card.color('backgroundColor'),
        shape: card.shape(base.cardTheme.shape),
        elevation: card.number('elevation'),
        shadowColor: card.color('shadowColor'),
        surfaceTintColor: card.color('surfaceTintColor'),
        margin: card.insets('margin'),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        shape: tile.shape(base.listTileTheme.shape),
        tileColor: tile.color('backgroundColor'),
        selectedTileColor: tile.color('selectedTileColor'),
        textColor: tile.color('textColor'),
        iconColor: tile.color('iconColor'),
        selectedColor: tile.color('selectedColor'),
        contentPadding: tile.insets('padding'),
        titleTextStyle: tile.color('textColor') == null
            ? null
            : base.listTileTheme.titleTextStyle?.copyWith(
                color: tile.color('textColor'),
              ),
        subtitleTextStyle: tile.color('textColor') == null
            ? null
            : base.listTileTheme.subtitleTextStyle?.copyWith(
                color: tile.color('textColor'),
              ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.button(base.elevatedButtonTheme.style),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button.button(base.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.button(base.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: button.button(base.textButtonTheme.style),
      ),
      inputDecorationTheme: field.copyWith(
        filled: input.values['filled'] as bool?,
        fillColor: input.color('fillColor'),
        contentPadding: input.insets('padding'),
        border: inputBorder('borderColor', field.border),
        enabledBorder: inputBorder(
          'borderColor',
          field.enabledBorder ?? field.border,
        ),
        focusedBorder: inputBorder(
          'focusedBorderColor',
          field.focusedBorder ?? field.border,
        ),
        errorBorder: inputBorder(
          'errorBorderColor',
          field.errorBorder ?? field.border,
        ),
        focusedErrorBorder: inputBorder(
          'errorBorderColor',
          field.focusedErrorBorder ?? field.errorBorder ?? field.border,
        ),
        disabledBorder: inputBorder(
          'disabledBorderColor',
          field.disabledBorder ?? field.border,
        ),
      ),
      navigationRailTheme: rail.copyWith(
        backgroundColor: navigation.color('backgroundColor'),
        indicatorColor: navigation.color('indicatorColor'),
        indicatorShape: indicatorShape,
        elevation: navigation.number('elevation'),
        selectedIconTheme: navigation.color('selectedIconColor') == null
            ? null
            : (rail.selectedIconTheme ?? const IconThemeData()).copyWith(
                color: navigation.color('selectedIconColor'),
              ),
        unselectedIconTheme: navigation.color('unselectedIconColor') == null
            ? null
            : (rail.unselectedIconTheme ?? const IconThemeData()).copyWith(
                color: navigation.color('unselectedIconColor'),
              ),
        selectedLabelTextStyle: navigation.color('selectedLabelColor') == null
            ? null
            : (rail.selectedLabelTextStyle ?? base.textTheme.labelMedium!)
                  .copyWith(color: navigation.color('selectedLabelColor')),
        unselectedLabelTextStyle:
            navigation.color('unselectedLabelColor') == null
            ? null
            : (rail.unselectedLabelTextStyle ?? base.textTheme.labelMedium!)
                  .copyWith(color: navigation.color('unselectedLabelColor')),
      ),
      navigationBarTheme: bar.copyWith(
        backgroundColor: navigation.color('backgroundColor'),
        indicatorColor: navigation.color('indicatorColor'),
        indicatorShape: indicatorShape,
        elevation: navigation.number('elevation'),
        iconTheme: navigationIcons,
        labelTextStyle: navigationLabels,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: dialog.color('backgroundColor'),
        shape: dialog.shape(base.dialogTheme.shape),
        elevation: dialog.number('elevation'),
        shadowColor: dialog.color('shadowColor'),
        surfaceTintColor: dialog.color('surfaceTintColor'),
        barrierColor: dialog.color('barrierColor'),
        insetPadding: dialog.insets('insetPadding'),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: sheet.color('backgroundColor'),
        modalBackgroundColor: sheet.color('backgroundColor'),
        shape: sheet.shape(base.bottomSheetTheme.shape),
        elevation: sheet.number('elevation'),
        modalElevation: sheet.number('elevation'),
        shadowColor: sheet.color('shadowColor'),
        surfaceTintColor: sheet.color('surfaceTintColor'),
        modalBarrierColor: sheet.color('barrierColor'),
        dragHandleColor: sheet.color('dragHandleColor'),
      ),
    );
  }
}

final class _Style {
  const _Style(this.values, this.scheme);
  final Map<String, dynamic> values;
  final ColorScheme scheme;

  bool hasAny(Set<String> keys) => keys.any(values.containsKey);
  double? number(String key) => (values[key] as num?)?.toDouble();
  Color? color(String key) => switch (values[key]) {
    final int value => Color(value),
    final String role => ThemePalette.resolve(scheme, role),
    _ => null,
  };
  EdgeInsets? insets(String key) {
    final value = values[key] as List?;
    if (value == null) return null;
    return EdgeInsets.fromLTRB(
      (value[0] as num).toDouble(),
      (value[1] as num).toDouble(),
      (value[2] as num).toDouble(),
      (value[3] as num).toDouble(),
    );
  }

  OutlinedBorder? shape(ShapeBorder? original) {
    if (!hasAny(ThemeComponents._shape)) {
      return original is OutlinedBorder ? original : null;
    }
    final rounded = original is RoundedRectangleBorder ? original : null;
    return RoundedRectangleBorder(
      borderRadius: number('radius') != null
          ? BorderRadius.circular(number('radius')!)
          : rounded?.borderRadius ?? BorderRadius.circular(12),
      side: BorderSide(
        color: color('borderColor') ?? rounded?.side.color ?? scheme.outline,
        width:
            number('borderWidth') ??
            (values.containsKey('borderColor') ? 1 : rounded?.side.width ?? 0),
      ),
    );
  }

  _Style state(Set<WidgetState> active) {
    final merged = <String, dynamic>{...values};
    for (final name in ThemeComponents.states.reversed) {
      if (active.any((state) => state.name == name)) {
        merged.addAll(values[name] as Map<String, dynamic>? ?? const {});
      }
    }
    return _Style(merged, scheme);
  }

  ButtonStyle? button(ButtonStyle? base) {
    if (values.isEmpty) return base;
    bool has(String key) =>
        values.containsKey(key) ||
        ThemeComponents.states.any(
          (name) =>
              (values[name] as Map<String, dynamic>?)?.containsKey(key) ??
              false,
        );
    WidgetStateProperty<T?>? prop<T>(
      String key,
      T? Function(_Style) read,
      WidgetStateProperty<T?>? fallback,
    ) => !has(key)
        ? null
        : WidgetStateProperty.resolveWith(
            (states) => read(state(states)) ?? fallback?.resolve(states),
          );
    return ButtonStyle(
      backgroundColor: prop(
        'backgroundColor',
        (s) => s.color('backgroundColor'),
        base?.backgroundColor,
      ),
      foregroundColor: prop(
        'foregroundColor',
        (s) => s.color('foregroundColor'),
        base?.foregroundColor,
      ),
      overlayColor: prop(
        'overlayColor',
        (s) => s.color('overlayColor'),
        base?.overlayColor,
      ),
      shadowColor: prop(
        'shadowColor',
        (s) => s.color('shadowColor'),
        base?.shadowColor,
      ),
      surfaceTintColor: prop(
        'surfaceTintColor',
        (s) => s.color('surfaceTintColor'),
        base?.surfaceTintColor,
      ),
      elevation: prop(
        'elevation',
        (s) => s.number('elevation'),
        base?.elevation,
      ),
      padding: prop('padding', (s) => s.insets('padding'), base?.padding),
      shape: ThemeComponents._shape.any(has)
          ? WidgetStateProperty.resolveWith(
              (states) => state(states).shape(base?.shape?.resolve(states)),
            )
          : null,
      side: has('borderColor') || has('borderWidth')
          ? WidgetStateProperty.resolveWith((states) {
              final style = state(states);
              if (!style.hasAny({'borderColor', 'borderWidth'})) {
                return base?.side?.resolve(states);
              }
              return BorderSide(
                color:
                    style.color('borderColor') ??
                    base?.side?.resolve(states)?.color ??
                    scheme.outline,
                width:
                    style.number('borderWidth') ??
                    base?.side?.resolve(states)?.width ??
                    1,
              );
            })
          : null,
    ).merge(base);
  }
}
