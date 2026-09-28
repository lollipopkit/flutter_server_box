import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

import 'package:server_box/core/service/theme_palette.dart';
import 'package:server_box/data/model/app/theme_style.dart';

/// `[layout] density`: how tightly the app's controls are packed.
enum ThemeDensity {
  compact(VisualDensity.compact),
  standard(VisualDensity.standard),
  comfortable(VisualDensity.comfortable);

  const ThemeDensity(this.visual);

  final VisualDensity visual;
}

/// What a component field holds, which is what it is checked against and what
/// `docs/schemas/fsbt-manifest.schema.json` refers to for it: each kind is a
/// schema definition of the same name (see [ThemeFieldKind.definition]), and
/// `test/unit/theme_schema_test.dart` holds every field's reference to it.
enum ThemeFieldKind {
  /// An ARGB integer or a palette role.
  color('color'),

  /// A corner radius, 0–[ThemeComponents.maxRadius].
  radius('ratio'),
  borderWidth('borderWidth'),
  elevation('elevation'),

  /// `[left, top, right, bottom]`, each 0–[ThemeComponents.maxInset].
  inset('inset'),
  flag('flag'),

  /// A height or a size in logical pixels, 0–[ThemeComponents.maxSize]: a bar,
  /// a button's minimum height, an icon.
  size('size'),

  /// A line or a track, 0–[ThemeComponents.maxThickness].
  thickness('thickness');

  const ThemeFieldKind(this.definition);

  /// The schema definition a field of this kind refers to.
  final String definition;
}

/// Validated component overrides. Common values are merged with Light/Dark
/// overrides, then with the active button state. Missing fields inherit Flutter.
///
/// Also carries the package's `[layout]`, which is read with the components and
/// applied with them.
final class ThemeComponents {
  const ThemeComponents.empty() : _data = const {}, density = null;
  const ThemeComponents._(this._data, this.density);

  final Map<String, dynamic> _data;

  /// `[layout] density`, or null for the platform's own.
  final ThemeDensity? density;

  static const _c = ThemeFieldKind.color;
  static const _r = ThemeFieldKind.radius;
  static const _bw = ThemeFieldKind.borderWidth;
  static const _el = ThemeFieldKind.elevation;
  static const _in = ThemeFieldKind.inset;
  static const _sz = ThemeFieldKind.size;
  static const _th = ThemeFieldKind.thickness;

  static const _shapeKinds = {'radius': _r, 'borderColor': _c, 'borderWidth': _bw};
  static const _shape = {'radius', 'borderColor', 'borderWidth'};
  static const _surfaceKinds = {
    'backgroundColor': _c,
    'elevation': _el,
    'shadowColor': _c,
    'surfaceTintColor': _c,
  };
  static const _buttonKinds = {
    ..._shapeKinds,
    ..._surfaceKinds,
    'foregroundColor': _c,
    'overlayColor': _c,
    'padding': _in,
    'minHeight': _sz,
  };

  /// Every component, its fields, and what each field holds.
  ///
  /// `button` is the primary action — Material's filled and elevated buttons,
  /// and `Btn.elevated`. A text, an outlined and an icon button are drawn for
  /// lighter actions and have tables of their own; one style for all four drew
  /// every text button in a dialog as a primary one.
  static const kinds = <String, Map<String, ThemeFieldKind>>{
    'card': {..._shapeKinds, ..._surfaceKinds, 'margin': _in},
    'tile': {
      ..._shapeKinds,
      'backgroundColor': _c,
      'selectedTileColor': _c,
      'textColor': _c,
      'iconColor': _c,
      'selectedColor': _c,
      'padding': _in,
    },
    'button': _buttonKinds,
    'textButton': _buttonKinds,
    'outlinedButton': _buttonKinds,
    'iconButton': {..._buttonKinds, 'iconSize': _sz},
    'input': {
      ..._shapeKinds,
      'filled': ThemeFieldKind.flag,
      'fillColor': _c,
      'focusedBorderColor': _c,
      'errorBorderColor': _c,
      'disabledBorderColor': _c,
      'padding': _in,
    },
    // The fields a search box embedded in a bar is drawn with, which is not
    // what a form's input is: one field's border in a pill that has its own.
    'search': {
      ..._shapeKinds,
      'backgroundColor': _c,
      'elevation': _el,
      'iconColor': _c,
      'textColor': _c,
      'hintColor': _c,
      'height': _sz,
      'padding': _in,
    },
    'navigation': {
      'backgroundColor': _c,
      'indicatorColor': _c,
      'indicatorRadius': _r,
      'selectedIconColor': _c,
      'unselectedIconColor': _c,
      'selectedLabelColor': _c,
      'unselectedLabelColor': _c,
      'elevation': _el,
    },
    'appBar': {
      'backgroundColor': _c,
      'foregroundColor': _c,
      'titleColor': _c,
      'iconColor': _c,
      'elevation': _el,
      'shadowColor': _c,
      'surfaceTintColor': _c,
    },
    'segmented': {
      ..._shapeKinds,
      'backgroundColor': _c,
      'selectedColor': _c,
      'textColor': _c,
      'selectedTextColor': _c,
    },
    'sidebar': {
      'backgroundColor': _c,
      'selectedColor': _c,
      'textColor': _c,
      'selectedTextColor': _c,
      'iconColor': _c,
      'selectedIconColor': _c,
      'radius': _r,
      'padding': _in,
    },
    'dialog': {..._shapeKinds, ..._surfaceKinds, 'barrierColor': _c, 'insetPadding': _in},
    'sheet': {..._shapeKinds, ..._surfaceKinds, 'barrierColor': _c, 'dragHandleColor': _c},
    'menu': {..._shapeKinds, ..._surfaceKinds, 'textColor': _c},
    'tooltip': {..._shapeKinds, 'backgroundColor': _c, 'textColor': _c, 'padding': _in},
    'toast': {..._shapeKinds, 'backgroundColor': _c, 'textColor': _c, 'elevation': _el},
    'switch': {
      'thumbColor': _c,
      'trackColor': _c,
      'trackOutlineColor': _c,
      'selectedThumbColor': _c,
      'selectedTrackColor': _c,
      'selectedTrackOutlineColor': _c,
    },
    'slider': {
      'activeTrackColor': _c,
      'inactiveTrackColor': _c,
      'thumbColor': _c,
      'overlayColor': _c,
      'trackHeight': _th,
    },
    'progress': {'color': _c, 'trackColor': _c, 'thickness': _th, 'radius': _r},
    'badge': {'backgroundColor': _c, 'textColor': _c, 'smallSize': _sz, 'largeSize': _sz},
    'chip': {
      ..._shapeKinds,
      'backgroundColor': _c,
      'selectedColor': _c,
      'textColor': _c,
      'padding': _in,
    },
    'divider': {'color': _c, 'thickness': _th},
    'scrollbar': {'thumbColor': _c, 'trackColor': _c, 'radius': _r, 'thickness': _th},
  };

  /// The fields of each component, for whoever only needs the names.
  static final fields = <String, Set<String>>{
    for (final e in kinds.entries) e.key: e.value.keys.toSet(),
  };

  /// The components with state tables (`hovered`, `pressed`, ...).
  static const stateful = {'button', 'textButton', 'outlinedButton', 'iconButton'};

  /// What schema 2 had, and nothing more: a package that uses a component or
  /// a field outside this reaches for schema 3, and has to say so, or a build
  /// that reads only 2 refuses the package (an unknown table) after the
  /// download rather than before it.
  static const schema2 = <String, Set<String>>{
    'card': {..._shape, 'backgroundColor', 'elevation', 'shadowColor', 'surfaceTintColor', 'margin'},
    'tile': {..._shape, 'backgroundColor', 'selectedTileColor', 'textColor', 'iconColor', 'selectedColor', 'padding'},
    'button': {..._shape, 'backgroundColor', 'elevation', 'shadowColor', 'surfaceTintColor', 'foregroundColor', 'overlayColor', 'padding'},
    'input': {..._shape, 'filled', 'fillColor', 'focusedBorderColor', 'errorBorderColor', 'disabledBorderColor', 'padding'},
    'navigation': {'backgroundColor', 'indicatorColor', 'indicatorRadius', 'selectedIconColor', 'unselectedIconColor', 'selectedLabelColor', 'unselectedLabelColor', 'elevation'},
    'dialog': {..._shape, 'backgroundColor', 'elevation', 'shadowColor', 'surfaceTintColor', 'barrierColor', 'insetPadding'},
    'sheet': {..._shape, 'backgroundColor', 'elevation', 'shadowColor', 'surfaceTintColor', 'barrierColor', 'dragHandleColor'},
  };

  // Highest-priority active state wins for each property independently.
  static const states = [
    'disabled',
    'pressed',
    'hovered',
    'focused',
    'selected',
  ];

  /// The largest value each numeric kind may hold, which
  /// `docs/schemas/fsbt-manifest.schema.json` states for editors as well:
  /// `test/unit/theme_schema_test.dart` holds the two equal, so a bound raised
  /// here and not there is a failure rather than a manifest the schema accepts
  /// and this refuses.
  static const maxRadius = 40.0;
  static const maxBorderWidth = 8;
  static const maxElevation = 24;
  static const maxSize = 96;
  static const maxThickness = 16;

  /// Each of the four numbers in `padding`, `margin` and `insetPadding`.
  static const maxInset = 64;

  /// The top-level `[layout]` fields.
  static const layoutFields = {'density'};

  /// The schema version the parsed tables need: 3 once anything beyond
  /// [schema2] is used, or `[layout]`.
  int get neededSchema {
    if (density != null) return 3;
    bool within(String name, Map<String, dynamic> table) {
      final allowed = schema2[name];
      if (allowed == null) return false;
      return table.entries.every((e) {
        if (name == 'button' && states.contains(e.key)) {
          return (e.value as Map<String, dynamic>).keys.every(allowed.contains);
        }
        return allowed.contains(e.key);
      });
    }

    for (final entry in _data.entries) {
      final value = entry.value as Map<String, dynamic>;
      if (brightnessByName(entry.key) != null) {
        if (!value.entries.every((e) => within(e.key, e.value as Map<String, dynamic>))) {
          return 3;
        }
      } else if (!within(entry.key, value)) {
        return 3;
      }
    }
    return 1;
  }

  static ThemeComponents parse(Object? raw, {Object? layout}) {
    final density = _density(layout);
    if (raw == null) {
      return density == null
          ? const ThemeComponents.empty()
          : ThemeComponents._(const {}, density);
    }
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
      final allowed = kinds[name];
      if (allowed == null) throw FormatException('Unknown component: $name');
      final result = <String, dynamic>{};
      for (final entry in table(raw).entries) {
        final key = entry.key;
        final value = entry.value;
        if (stateful.contains(name) && !state && states.contains(key)) {
          result[key] = component(name, value, state: true);
          continue;
        }
        final kind = allowed[key];
        if (kind == null) throw FormatException('Unknown $name field: $key');
        switch (kind) {
          case ThemeFieldKind.color:
            if (!(value is int && value >= 0 && value <= 0xffffffff) &&
                !(value is String && ThemePalette.roles.contains(value))) {
              throw FormatException('Invalid $name.$key color');
            }
          case ThemeFieldKind.flag:
            if (value is! bool) throw FormatException('Invalid $name.$key flag');
          case ThemeFieldKind.inset:
            if (value is! List ||
                value.length != 4 ||
                value.any(
                  (v) => v is! num || !v.isFinite || v < 0 || v > maxInset,
                )) {
              throw FormatException('Invalid $name.$key insets');
            }
            result[key] = List<num>.unmodifiable(value.cast<num>());
            continue;
          case ThemeFieldKind.radius ||
              ThemeFieldKind.borderWidth ||
              ThemeFieldKind.elevation ||
              ThemeFieldKind.size ||
              ThemeFieldKind.thickness:
            final max = switch (kind) {
              ThemeFieldKind.borderWidth => maxBorderWidth,
              ThemeFieldKind.elevation => maxElevation,
              ThemeFieldKind.size => maxSize,
              ThemeFieldKind.thickness => maxThickness,
              _ => maxRadius,
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
      // A key of one of the two brightnesses opens a table of components;
      // anything else is a component itself.
      data[entry.key] = brightnessByName(entry.key) != null
          ? group(entry.value)
          : component(entry.key, entry.value);
    }
    return ThemeComponents._(Map.unmodifiable(data), density);
  }

  static ThemeDensity? _density(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, dynamic> || !raw.keys.every(layoutFields.contains)) {
      throw const FormatException('Invalid layout table');
    }
    final value = raw['density'];
    if (value == null) return null;
    final density = ThemeDensity.values.asNameMap()[value];
    if (density == null) throw const FormatException('Invalid layout density');
    return density;
  }

  /// `[layout]` as the installed manifest carries it; null when empty.
  Map<String, dynamic>? layoutMap() =>
      density == null ? null : {'density': density!.name};

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
    if (_data.isEmpty && density == null) return base;
    final card = _style('card', base);
    final tile = _style('tile', base);
    final input = _style('input', base);
    final navigation = _style('navigation', base);
    final dialog = _style('dialog', base);
    final sheet = _style('sheet', base);
    final button = _style('button', base);
    final textButton = _style('textButton', base);
    final outlinedButton = _style('outlinedButton', base);
    final iconButton = _style('iconButton', base);
    final search = _style('search', base);
    final appBar = _style('appBar', base);
    final segmented = _style('segmented', base);
    final sidebar = _style('sidebar', base);
    final menu = _style('menu', base);
    final tooltip = _style('tooltip', base);
    final toast = _style('toast', base);
    final switcher = _style('switch', base);
    final slider = _style('slider', base);
    final progress = _style('progress', base);
    final badge = _style('badge', base);
    final chip = _style('chip', base);
    final divider = _style('divider', base);
    final scrollbar = _style('scrollbar', base);
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
        borderSide: themeBorderSide(
          input.color(colorKey) ??
              input.color('borderColor') ??
              border?.borderSide.color ??
              base.colorScheme.outline,
          input.number('borderWidth') ?? border?.borderSide.width ?? 1,
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

    /// A property that differs between selected and not, from two fields.
    WidgetStateProperty<Color?>? selectable(
      _Style style,
      String plain,
      String selected,
      WidgetStateProperty<Color?>? fallback,
    ) => !style.hasAny({plain, selected})
        ? fallback
        : WidgetStateProperty.resolveWith((states) {
            final key = states.contains(WidgetState.selected) ? selected : plain;
            return style.color(key) ?? fallback?.resolve(states);
          });

    TextStyle? withColor(TextStyle? style, Color? color, TextStyle fallback) =>
        color == null ? style : (style ?? fallback).copyWith(color: color);

    final searchShape = search.hasAny(_shape)
        ? search.shape(const StadiumBorder())
        : null;
    final menuShape = menu.hasAny(_shape) ? menu.shape(base.popupMenuTheme.shape) : null;

    // What the library's own widgets read — a search field in a bar, segmented
    // tabs, a side bar's rows, a toast — which no Material theme covers.
    final styles = ComponentStyles(
      search: SearchFieldStyle(
        backgroundColor: search.color('backgroundColor'),
        radius: search.number('radius'),
        borderColor: search.color('borderColor'),
        borderWidth: search.number('borderWidth'),
        iconColor: search.color('iconColor'),
        textColor: search.color('textColor'),
        hintColor: search.color('hintColor'),
        height: search.number('height'),
        padding: search.insets('padding'),
      ),
      segmented: SegmentedStyle(
        trackColor: segmented.color('backgroundColor'),
        selectedColor: segmented.color('selectedColor'),
        textColor: segmented.color('textColor'),
        selectedTextColor: segmented.color('selectedTextColor'),
        radius: segmented.number('radius'),
        borderColor: segmented.color('borderColor'),
        borderWidth: segmented.number('borderWidth'),
      ),
      sidebar: SidebarStyle(
        backgroundColor: sidebar.color('backgroundColor'),
        selectedColor: sidebar.color('selectedColor'),
        textColor: sidebar.color('textColor'),
        selectedTextColor: sidebar.color('selectedTextColor'),
        iconColor: sidebar.color('iconColor'),
        selectedIconColor: sidebar.color('selectedIconColor'),
        radius: sidebar.number('radius'),
        padding: sidebar.insets('padding'),
      ),
      toast: ToastStyle(
        backgroundColor: toast.color('backgroundColor'),
        textColor: toast.color('textColor'),
        radius: toast.number('radius'),
        borderColor: toast.color('borderColor'),
        borderWidth: toast.number('borderWidth'),
        elevation: toast.number('elevation'),
      ),
    );

    return base.copyWith(
      visualDensity: density?.visual,
      extensions: [
        ...base.extensions.values.where((e) => e is! ComponentStyles),
        styles,
      ],
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
      // The primary action. A text, an outlined and an icon button are the
      // lighter ones and keep the app's style unless their own table says
      // otherwise.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.button(base.elevatedButtonTheme.style),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button.button(base.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: outlinedButton.button(base.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: textButton.button(base.textButtonTheme.style),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: iconButton.button(base.iconButtonTheme.style),
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
      // Material's own search bar. The search fields the app draws itself
      // read the same theme, through [SearchBarTheme].
      searchBarTheme: base.searchBarTheme.copyWith(
        backgroundColor: search.color('backgroundColor') == null
            ? null
            : WidgetStatePropertyAll(search.color('backgroundColor')),
        elevation: search.number('elevation') == null
            ? null
            : WidgetStatePropertyAll(search.number('elevation')),
        shape: searchShape == null ? null : WidgetStatePropertyAll(searchShape),
        side: search.hasAny({'borderColor', 'borderWidth'})
            ? WidgetStatePropertyAll(searchShape!.side)
            : null,
        padding: search.insets('padding') == null
            ? null
            : WidgetStatePropertyAll(search.insets('padding')),
        textStyle: search.color('textColor') == null
            ? null
            : WidgetStatePropertyAll(
                TextStyle(color: search.color('textColor')),
              ),
        hintStyle: search.color('hintColor') == null
            ? null
            : WidgetStatePropertyAll(
                TextStyle(color: search.color('hintColor')),
              ),
        constraints: search.number('height') == null
            ? null
            : BoxConstraints(
                minHeight: search.number('height')!,
                maxHeight: search.number('height')!,
              ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: appBar.color('backgroundColor'),
        foregroundColor: appBar.color('foregroundColor'),
        elevation: appBar.number('elevation'),
        shadowColor: appBar.color('shadowColor'),
        surfaceTintColor: appBar.color('surfaceTintColor'),
        iconTheme: appBar.color('iconColor') == null
            ? null
            : (base.appBarTheme.iconTheme ?? const IconThemeData()).copyWith(
                color: appBar.color('iconColor'),
              ),
        actionsIconTheme: appBar.color('iconColor') == null
            ? null
            : (base.appBarTheme.actionsIconTheme ?? const IconThemeData())
                  .copyWith(color: appBar.color('iconColor')),
        titleTextStyle: withColor(
          base.appBarTheme.titleTextStyle,
          appBar.color('titleColor'),
          base.textTheme.titleLarge!,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: segmented.values.isEmpty
            ? base.segmentedButtonTheme.style
            : ButtonStyle(
                backgroundColor: selectable(
                  segmented,
                  'backgroundColor',
                  'selectedColor',
                  null,
                ),
                foregroundColor: selectable(
                  segmented,
                  'textColor',
                  'selectedTextColor',
                  null,
                ),
                shape: segmented.hasAny(_shape)
                    ? WidgetStatePropertyAll(segmented.shape(null))
                    : null,
                side: segmented.hasAny({'borderColor', 'borderWidth'})
                    ? WidgetStatePropertyAll(segmented.shape(null)!.side)
                    : null,
              ).merge(base.segmentedButtonTheme.style),
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
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: menu.color('backgroundColor'),
        shape: menuShape,
        elevation: menu.number('elevation'),
        shadowColor: menu.color('shadowColor'),
        surfaceTintColor: menu.color('surfaceTintColor'),
        textStyle: withColor(
          base.popupMenuTheme.textStyle,
          menu.color('textColor'),
          base.textTheme.bodyMedium!,
        ),
      ),
      menuTheme: menu.values.isEmpty
          ? base.menuTheme
          : MenuThemeData(
              style: MenuStyle(
                backgroundColor: menu.color('backgroundColor') == null
                    ? null
                    : WidgetStatePropertyAll(menu.color('backgroundColor')),
                elevation: menu.number('elevation') == null
                    ? null
                    : WidgetStatePropertyAll(menu.number('elevation')),
                shadowColor: menu.color('shadowColor') == null
                    ? null
                    : WidgetStatePropertyAll(menu.color('shadowColor')),
                surfaceTintColor: menu.color('surfaceTintColor') == null
                    ? null
                    : WidgetStatePropertyAll(menu.color('surfaceTintColor')),
                shape: menuShape == null ? null : WidgetStatePropertyAll(menuShape),
              ).merge(base.menuTheme.style),
            ),
      tooltipTheme: tooltip.values.isEmpty
          ? base.tooltipTheme
          : base.tooltipTheme.copyWith(
              decoration: BoxDecoration(
                color:
                    tooltip.color('backgroundColor') ??
                    base.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(tooltip.number('radius') ?? 4),
                border: tooltip.hasAny({'borderColor', 'borderWidth'})
                    ? Border.fromBorderSide(
                        themeBorderSide(
                          tooltip.color('borderColor') ??
                              base.colorScheme.outline,
                          tooltip.number('borderWidth') ?? 1,
                        ),
                      )
                    : null,
              ),
              textStyle: withColor(
                base.tooltipTheme.textStyle,
                tooltip.color('textColor'),
                base.textTheme.bodySmall!.copyWith(
                  color: base.colorScheme.onInverseSurface,
                ),
              ),
              padding: tooltip.insets('padding'),
            ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: toast.color('backgroundColor'),
        contentTextStyle: withColor(
          base.snackBarTheme.contentTextStyle,
          toast.color('textColor'),
          base.textTheme.bodyMedium!,
        ),
        elevation: toast.number('elevation'),
        shape: toast.hasAny(_shape) ? toast.shape(base.snackBarTheme.shape) : null,
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbColor: selectable(
          switcher,
          'thumbColor',
          'selectedThumbColor',
          base.switchTheme.thumbColor,
        ),
        trackColor: selectable(
          switcher,
          'trackColor',
          'selectedTrackColor',
          base.switchTheme.trackColor,
        ),
        trackOutlineColor: selectable(
          switcher,
          'trackOutlineColor',
          'selectedTrackOutlineColor',
          base.switchTheme.trackOutlineColor,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: slider.color('activeTrackColor'),
        inactiveTrackColor: slider.color('inactiveTrackColor'),
        thumbColor: slider.color('thumbColor'),
        overlayColor: slider.color('overlayColor'),
        trackHeight: slider.number('trackHeight'),
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: progress.color('color'),
        linearTrackColor: progress.color('trackColor'),
        circularTrackColor: progress.color('trackColor'),
        linearMinHeight: progress.number('thickness'),
        borderRadius: progress.number('radius') == null
            ? null
            : BorderRadius.circular(progress.number('radius')!),
      ),
      badgeTheme: base.badgeTheme.copyWith(
        backgroundColor: badge.color('backgroundColor'),
        textColor: badge.color('textColor'),
        smallSize: badge.number('smallSize'),
        largeSize: badge.number('largeSize'),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: chip.color('backgroundColor'),
        selectedColor: chip.color('selectedColor'),
        labelStyle: withColor(
          base.chipTheme.labelStyle,
          chip.color('textColor'),
          base.textTheme.labelLarge!,
        ),
        shape: chip.hasAny(_shape) ? chip.shape(base.chipTheme.shape) : null,
        side: chip.hasAny({'borderColor', 'borderWidth'})
            ? chip.shape(base.chipTheme.shape)!.side
            : null,
        padding: chip.insets('padding'),
      ),
      dividerTheme: base.dividerTheme.copyWith(
        color: divider.color('color'),
        thickness: divider.number('thickness'),
      ),
      scrollbarTheme: base.scrollbarTheme.copyWith(
        thumbColor: scrollbar.color('thumbColor') == null
            ? null
            : WidgetStatePropertyAll(scrollbar.color('thumbColor')),
        trackColor: scrollbar.color('trackColor') == null
            ? null
            : WidgetStatePropertyAll(scrollbar.color('trackColor')),
        radius: scrollbar.number('radius') == null
            ? null
            : Radius.circular(scrollbar.number('radius')!),
        thickness: scrollbar.number('thickness') == null
            ? null
            : WidgetStatePropertyAll(scrollbar.number('thickness')),
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
  Color? color(String key) => ThemePalette.spec(values[key], scheme);
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
      side: themeBorderSide(
        color('borderColor') ?? rounded?.side.color ?? scheme.outline,
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
      minimumSize: prop(
        'minHeight',
        (s) => s.number('minHeight') == null
            ? null
            : Size(0, s.number('minHeight')!),
        base?.minimumSize,
      ),
      iconSize: prop('iconSize', (s) => s.number('iconSize'), base?.iconSize),
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
              return themeBorderSide(
                style.color('borderColor') ??
                    base?.side?.resolve(states)?.color ??
                    scheme.outline,
                style.number('borderWidth') ??
                    base?.side?.resolve(states)?.width ??
                    1,
              );
            })
          : null,
    ).merge(base);
  }
}
