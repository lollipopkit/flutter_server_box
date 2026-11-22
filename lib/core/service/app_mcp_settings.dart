import 'package:fl_lib/fl_lib.dart' show LocaleX, RNodes, StorePropDefault;
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart' show l10n;
import 'package:server_box/data/model/app/keybinding.dart';
import 'package:server_box/data/model/app/motion.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/app/tray.dart';
import 'package:server_box/data/provider/app/keybindings.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';

/// Wire representation and checked write for one user preference.
class McpPreference {
  const McpPreference(this.schema, this.read, this.write);

  final Map<String, Object> schema;
  final Object Function() read;
  final bool Function(Object?) write;
}

Map<String, McpPreference> mcpPreferences(ProviderContainer container) {
  final preferences = <String, McpPreference>{};
  void add<T extends Object>(
    StorePropDefault<T> prop,
    Map<String, Object> schema,
    T? Function(Object?) decode, {
    Object Function(T)? encode,
  }) {
    preferences[prop.key] = McpPreference(
      schema,
      () {
        final value = prop.get();
        return encode?.call(value) ?? value;
      },
      (raw) {
        final value = decode(raw);
        if (value == null) return false;
        prop.putSync(value);
        if (identical(prop, Stores.setting.textFactor) ||
            identical(prop, Stores.setting.locale)) {
          RNodes.app.notify();
        }
        return true;
      },
    );
  }

  final s = Stores.setting;
  for (final prop in [
    s.editorHighlight,
    s.editorSoftWrap,
    s.closeAfterSave,
    s.sftpShowFoldersFirst,
    s.showHiddenFiles,
    s.sftpOpenLastPath,
    s.trayCompact,
    s.showDistMark,
    s.tmuxShowSelector,
    s.collapseUIDefault,
    s.serverOverview,
    s.serverTabConnBadge,
    s.termMetricsBar,
    s.serverPageSortAsc,
    s.sshPageSortAsc,
    s.remoteDesktopSortAsc,
  ]) {
    add(prop, {'type': 'boolean'}, (v) => v is bool ? v : null);
  }

  void integer(StorePropDefault<int> prop, List<int> choices) => add(prop, {
    'type': 'integer',
    'enum': choices,
  }, (v) => v is int && choices.contains(v) ? v : null);
  integer(s.maxRetryCount, List.generate(10, (i) => i));
  integer(s.serverStatusUpdateInterval, [0, for (int i = 2; i <= 10; i++) i]);
  integer(s.termTheme, [0, 1, 2]);

  for (final prop in [s.termFontSize, s.editorFontSize, s.textFactor]) {
    add(prop, {
      'type': 'number',
      'exclusiveMinimum': 0,
    }, (v) => v is num && v.isFinite && v > 0 ? v.toDouble() : null);
  }
  add(
    s.termLineHeight,
    {
      'type': 'number',
      'minimum': TerminalLook.minLineHeight,
      'maximum': TerminalLook.maxLineHeight,
    },
    (v) =>
        v is num &&
            v >= TerminalLook.minLineHeight &&
            v <= TerminalLook.maxLineHeight
        ? v.toDouble()
        : null,
  );

  void string(StorePropDefault<String> prop, [List<String>? options]) => add(
    prop,
    {'type': 'string', 'enum': ?options},
    (v) => v is String && (options == null || options.contains(v)) ? v : null,
  );
  string(s.locale, [
    '',
    ...AppLocalizations.supportedLocales.map((l) => l.code),
  ]);
  add(s.timeout, {
    'type': 'integer',
    'minimum': 1,
  }, (v) => v is int && v > 0 ? v : null);
  final tabs = AppTab.values.map((t) => t.name).toList();
  add(
    s.homeTabs,
    {
      'type': 'array',
      'minItems': 1,
      'uniqueItems': true,
      'items': {'type': 'string', 'enum': tabs},
    },
    (v) =>
        v is List &&
            v.isNotEmpty &&
            v.every(tabs.contains) &&
            v.toSet().length == v.length
        ? AppTab.parseAppTabsFromObj(v)
        : null,
    encode: (value) => value.map((t) => t.name).toList(),
  );
  final shortcuts = {
    for (final cmd in KbCommand.values)
      if (!cmd.fixed) cmd.id: cmd,
  };
  preferences['keybindings'] = McpPreference(
    {
      'type': 'object',
      'maxProperties': 1,
      'minProperties': 1,
      'propertyNames': {'enum': shortcuts.keys.toList()},
      'additionalProperties': {'type': 'string'},
      'description': l10n.appMcpShortcut,
    },
    () {
      final state = container.read(keybindingsProvider);
      return {for (final cmd in shortcuts.values) cmd.id: state.chordOf(cmd)};
    },
    (raw) {
      if (raw is! Map || raw.length != 1) return false;
      final cmd = shortcuts[raw.keys.single];
      final chord = raw.values.single;
      if (cmd == null ||
          chord is! String ||
          (chord.isNotEmpty && KbChord.activator(chord) == null)) {
        return false;
      }
      container.read(keybindingsProvider.notifier).bind(cmd, chord);
      return true;
    },
  );
  string(s.editorFontFamily);
  string(s.editorTheme, themeMap.keys.toList());
  string(s.editorDarkTheme, themeMap.keys.toList());
  string(s.trayChart, [
    '',
    for (final m in TrayMetric.values)
      if (m.chartable) m.name,
  ]);
  add(
    s.motionPref,
    {'type': 'string', 'enum': MotionPref.values.map((p) => p.name).toList()},
    MotionPref.parse,
    encode: (p) => p.name,
  );

  final metrics = TrayMetric.values.map((m) => m.name).toList();
  add(
    s.trayMetrics,
    {
      'type': 'array',
      'uniqueItems': true,
      'items': {'type': 'string', 'enum': metrics},
    },
    (v) =>
        v is List && v.every(metrics.contains) && v.toSet().length == v.length
        ? metrics.where(v.contains).toList()
        : null,
  );
  add(
    s.distNameMap,
    {
      'type': 'object',
      'additionalProperties': {'type': 'string'},
    },
    (v) => v is Map<String, dynamic> && v.values.every((e) => e is String)
        ? Map<String, String>.from(v)
        : null,
  );
  return preferences;
}

Map<String, Object> mcpPreferenceTool(ProviderContainer container) {
  final preferences = mcpPreferences(container);
  return {
    'name': 'app_setting_set',
    'description': l10n.appMcpSet,
    'inputSchema': {
      'type': 'object',
      'required': ['key', 'value'],
      'additionalProperties': false,
      'properties': {
        'key': {'type': 'string', 'enum': preferences.keys.toList()},
        'value': <String, Object>{},
      },
      'oneOf': [
        for (final entry in preferences.entries)
          {
            'properties': {
              'key': {'const': entry.key},
              'value': entry.value.schema,
            },
          },
      ],
    },
  };
}
