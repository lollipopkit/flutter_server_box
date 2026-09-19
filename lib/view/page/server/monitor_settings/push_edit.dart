// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_push.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

final class MonitorPushEditArgs {
  final MonitorPushEntry entry;

  /// The types this agent can deliver through, as it reported them.
  final List<String> pushTypes;

  /// Borrowed, not owned: the page that opened this one keeps it and disposes
  /// it. A test send goes through the same session the list was loaded with,
  /// so a withheld credential resolves against the same agent.
  final MonitorHttpClient client;

  const MonitorPushEditArgs({
    required this.entry,
    required this.pushTypes,
    required this.client,
  });
}

/// One notification channel.
///
/// The fields are rendered from the channel's own config rather than from a
/// per-type form: the agent passes keys through that this app knows nothing
/// about (`legacy_go_format`, a webhook's `expected_http_status`), and a form
/// that rebuilt the map out of the fields it knows would drop them on save.
/// A new channel starts from [_templates], which mirrors what the agent's
/// `config.example.toml` documents.
///
/// A `null` value is a credential the agent withheld. It is shown as an empty
/// box marked "set", and left empty it goes back as `null`, which the agent
/// reads as "keep". Typing into it replaces the stored value; there is no way
/// from here to read one.
final class MonitorPushEditPage extends StatefulWidget {
  final MonitorPushEditArgs args;

  const MonitorPushEditPage({super.key, required this.args});

  static const route = AppRouteArg<MonitorPushEntry, MonitorPushEditArgs>(
    page: MonitorPushEditPage.new,
    path: '/server/monitor_settings/push',
  );

  @override
  State<MonitorPushEditPage> createState() => _MonitorPushEditPageState();
}

/// What a new channel of each type starts with — the fields the agent's own
/// example config documents. An existing channel is rendered from whatever the
/// agent sent instead, so a key that is not here is still editable once it is
/// in the file.
const _templates = <String, Map<String, dynamic>>{
  'webhook': {
    'url': '',
    'method': 'POST',
    'headers': {'Content-Type': 'application/json'},
    'body_template': {'message': 'Server {{name}}: {{message}}'},
  },
  'serverchan': {
    'sc_key': '',
    'title': 'ServerBox Monitor',
    'desp': '{{message}}',
  },
  'bark': {
    'server': 'https://api.day.app',
    'key': '',
    'title': 'ServerBox Monitor',
    'body': '{{message}}',
    'level': 'active',
  },
  'ios': {
    'token': '',
    'title': 'ServerBox Monitor',
    'content': '{{message}}',
    'body_regex': '.*',
    'code': 200,
  },
};

/// A scalar setting, as a string because that is what a text field holds.
/// [kind] is recovered from what the agent sent so a number goes back a
/// number — TOML is typed, and an expected status code arriving as a string
/// would not compare against anything.
final class _Field {
  final String key;
  final TextEditingController ctrl;
  final _FieldKind kind;

  /// Arrived as `null`: set on the agent and not disclosed.
  final bool withheld;

  _Field({
    required this.key,
    required String value,
    required this.kind,
    required this.withheld,
  }) : ctrl = TextEditingController(text: value);
}

enum _FieldKind { string, number, boolean }

/// A nested table other than `headers` — a webhook's `body_template`. Edited
/// as JSON text because its shape is whatever the receiving service wants.
final class _JsonField {
  final String key;
  final TextEditingController ctrl;

  _JsonField({required this.key, required Object? value})
    : ctrl = TextEditingController(
        text: const JsonEncoder.withIndent('  ').convert(value),
      );
}

final class _Header {
  final TextEditingController name;
  final TextEditingController value;
  final bool withheld;

  _Header({required String name, required String value, this.withheld = false})
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);
}

final class _MonitorPushEditPageState extends State<MonitorPushEditPage> {
  late final _nameCtrl = TextEditingController(text: widget.args.entry.name);
  late String _type = widget.args.entry.pushType;
  late int? _fromIndex = widget.args.entry.fromIndex;

  var _fields = <_Field>[];
  var _jsons = <_JsonField>[];
  List<_Header>? _headers;

  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _loadConfig(widget.args.entry.config);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _disposeFields();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.args.entry;
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(
          up: l10n.pushChannels,
          down: entry.name.isEmpty ? libL10n.add : entry.name,
        ),
        actions: [
          IconButton(
            tooltip: libL10n.save,
            icon: const Icon(Icons.save),
            onPressed: _onSave,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

// --- Widget build ---

extension on _MonitorPushEditPageState {
  Widget _buildBody() {
    if (!widget.args.entry.editable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Text(
            l10n.pushUnknownType,
            style: UIs.textGrey,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Grouped, then laid out in the server editor's grid. One field per grid
    // entry would scatter a channel's settings across the columns: the grid
    // fills them in turn, so `url` and `method` would end up side by side in
    // different columns rather than one under the other.
    //
    // A group is added only when it has something in it — an entry that
    // renders to nothing still takes the grid's spacing on both sides, which
    // is a gap belonging to no card.
    final headers = _headers;
    return PageColumns(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Input(
              controller: _nameCtrl,
              label: libL10n.name,
              icon: BoxIcons.bx_rename,
              suggestion: false,
            ),
            _buildType(),
          ],
        ),
        if (_fields.isNotEmpty)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: _fields.map(_buildField).toList(),
          ),
        if (headers != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildHeaders(headers),
          ),
        if (_jsons.isNotEmpty)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: _jsons.map(_buildJson).toList(),
          ),
        _buildTest(),
      ],
    );
  }

  Widget _buildType() {
    // A spelling the agent still accepts but no longer offers (the Go agent's
    // `server_chan`) would otherwise vanish from the list and take the
    // channel's type with it.
    final types = {..._templates.keys, ...widget.args.pushTypes, _type}.toList();
    return ListTile(
      leading: const Icon(MingCute.send_plane_line),
      title: Text(l10n.pushType),
      trailing: DropdownButton<String>(
        value: _type,
        underline: const SizedBox.shrink(),
        items: [
          for (final type in types)
            DropdownMenuItem(value: type, child: Text(type)),
        ],
        onChanged: (type) {
          if (type == null || type == _type) return;
          _onTypeChanged(type);
        },
      ),
    ).cardx;
  }

  Widget _buildField(_Field field) {
    if (field.kind == _FieldKind.boolean) return _buildBool(field);
    return Input(
      controller: field.ctrl,
      label: field.key,
      hint: field.withheld ? l10n.pushSecretKeep : null,
      type: field.kind == _FieldKind.number
          ? TextInputType.number
          : TextInputType.text,
      suggestion: false,
      suffix: field.withheld
          ? Tooltip(
              message: l10n.pushSecretSet,
              child: const Icon(Icons.lock_outline, size: 17),
            )
          : null,
    );
  }

  /// A switch rather than a text box, so the only two values a TOML boolean
  /// has are the only two that can be typed. Free text here read anything but
  /// `true` as `false` — "yes" saved as off, without a word.
  Widget _buildBool(_Field field) {
    final on = field.ctrl.text.toLowerCase() == 'true';
    return ListTile(
      leading: const Icon(Icons.toggle_on_outlined),
      title: Text(field.key, style: const TextStyle(fontFamily: 'monospace')),
      trailing: SwitchX(
        value: on,
        onChanged: (value) =>
            setState(() => field.ctrl.text = value ? 'true' : 'false'),
      ),
    ).cardx;
  }

  List<Widget> _buildHeaders(List<_Header> headers) {
    return [
      CenterGreyTitle(l10n.pushHeaders),
      for (final (idx, header) in headers.indexed)
        CardX(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 7, 7, 7),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: header.name,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Authorization',
                    ),
                  ),
                ),
                UIs.width13,
                Expanded(
                  child: TextField(
                    controller: header.value,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: header.withheld ? l10n.pushSecretKeep : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 19),
                  onPressed: () => setState(() => headers.removeAt(idx)),
                ),
              ],
            ),
          ),
        ),
      Btn.icon(
        icon: const Icon(Icons.add, size: 20),
        text: libL10n.add,
        onTap: _onAddHeader,
      ),
    ];
  }

  Widget _buildJson(_JsonField json) {
    return Input(
      controller: json.ctrl,
      label: json.key,
      maxLines: 5,
      minLines: 2,
      suggestion: false,
    );
  }

  Widget _buildTest() {
    final result = _testResult;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.send_outlined),
          title: TipText(libL10n.test, l10n.pushTestTip),
          trailing: _testing
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_arrow_right),
          onTap: _testing ? null : _onTest,
        ).cardx,
        if (result != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
            child: Text(
              result,
              style: UIs.textGrey.copyWith(
                color: _testOk ? null : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

// --- Actions ---

extension on _MonitorPushEditPageState {
  void _onTypeChanged(String type) {
    // The agent refuses to carry a credential across a type change — a Bark
    // key is not an iOS token — so the form starts over rather than going on
    // showing "set" for something that will not be saved.
    setState(() {
      _type = type;
      _fromIndex = null;
      _loadConfig(_templates[type] ?? const {});
    });
  }

  void _onAddHeader() {
    setState(() {
      (_headers ??= []).add(_Header(name: '', value: ''));
    });
  }

  Future<void> _onTest() async {
    final entry = _collect();
    if (entry == null) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final result = await widget.args.client.testPush(
        entry,
        l10n.pushTestMessage,
      );
      if (!mounted) return;
      setState(() {
        _testOk = result.ok;
        _testResult = result.ok
            ? l10n.pushTestSent
            : (result.error ?? l10n.pushTestFailed);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testResult = '$e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _onSave() {
    final entry = _collect();
    if (entry == null) return;
    context.pop(entry);
  }
}

// --- Utils ---

extension on _MonitorPushEditPageState {
  void _disposeFields() {
    for (final field in _fields) {
      field.ctrl.dispose();
    }
    for (final json in _jsons) {
      json.ctrl.dispose();
    }
    for (final header in _headers ?? const <_Header>[]) {
      header.name.dispose();
      header.value.dispose();
    }
  }

  /// Splits a channel's config into the three things this page can render.
  /// Anything that is neither a scalar nor `headers` becomes a JSON box rather
  /// than being dropped — losing a key on load would lose it on the save too.
  void _loadConfig(Map<String, dynamic> config) {
    _disposeFields();
    final fields = <_Field>[];
    final jsons = <_JsonField>[];
    List<_Header>? headers;

    for (final entry in config.entries) {
      final value = entry.value;
      if (entry.key == 'headers' && value is Map) {
        headers = [
          for (final header in value.entries)
            _Header(
              name: '${header.key}',
              value: header.value == null ? '' : '${header.value}',
              withheld: header.value == null,
            ),
        ];
      } else if (value == null) {
        fields.add(
          _Field(
            key: entry.key,
            value: '',
            kind: _FieldKind.string,
            withheld: true,
          ),
        );
      } else if (value is Map || value is List) {
        jsons.add(_JsonField(key: entry.key, value: value));
      } else if (value is num) {
        fields.add(
          _Field(
            key: entry.key,
            value: '$value',
            kind: _FieldKind.number,
            withheld: false,
          ),
        );
      } else if (value is bool) {
        fields.add(
          _Field(
            key: entry.key,
            value: '$value',
            kind: _FieldKind.boolean,
            withheld: false,
          ),
        );
      } else {
        fields.add(
          _Field(
            key: entry.key,
            value: '$value',
            kind: _FieldKind.string,
            withheld: false,
          ),
        );
      }
    }

    _fields = fields;
    _jsons = jsons;
    _headers = headers;
  }

  /// This page's state as the agent wants it, or null after reporting why it
  /// could not be — which can only be a JSON box that does not parse.
  MonitorPushEntry? _collect() {
    final config = <String, dynamic>{};

    for (final field in _fields) {
      final text = field.ctrl.text;
      if (field.withheld) {
        // Blank means keep: the value was never shown, so there is nothing
        // else an empty box could honestly be taken to mean.
        config[field.key] = text.isEmpty ? null : text;
        continue;
      }
      // An empty box removes the key. Every sender reads its settings with a
      // default behind them, so absent and blank mean the same thing to the
      // agent — and absent is the one that lets the default apply.
      if (text.isEmpty) continue;
      config[field.key] = switch (field.kind) {
        _FieldKind.number => num.tryParse(text) ?? text,
        _FieldKind.boolean => text.toLowerCase() == 'true',
        _FieldKind.string => text,
      };
    }

    if (_headers case final headers?) {
      final collected = <String, dynamic>{};
      for (final header in headers) {
        final name = header.name.text.trim();
        if (name.isEmpty) continue;
        final value = header.value.text;
        if (header.withheld) {
          collected[name] = value.isEmpty ? null : value;
        } else if (value.isNotEmpty) {
          collected[name] = value;
        }
      }
      if (collected.isNotEmpty) config['headers'] = collected;
    }

    for (final json in _jsons) {
      try {
        config[json.key] = jsonDecode(json.ctrl.text);
      } catch (_) {
        Toast.show('${json.key} ${l10n.pushJsonInvalid}');
        return null;
      }
    }

    return MonitorPushEntry(
      name: _nameCtrl.text.trim(),
      pushType: _type,
      config: config,
      fromIndex: _fromIndex,
      editable: widget.args.entry.editable,
    );
  }
}
