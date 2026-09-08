/// What a monitor agent's own plugins report, as it arrives.
///
/// The agent runs status plugins itself so their readings reach
/// `/metrics/history`, the watch and the home widgets — none of which ever
/// speaks to the app. PLUGINS.md 9.5.
///
/// **This is a wire contract, not one type used twice.** The agent serializes
/// `sbm_plugin::status::StatusResult` with serde and the app reads it with
/// `json_serializable`, so the literal below is the same one in
/// `crates/sbm_plugin/src/status.rs`'s `wire` module. A change to either side
/// fails one of the two.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_metrics.dart';
import 'package:server_box/data/model/server/monitor_metrics_mapper.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/res/status.dart';

/// Byte for byte what `sbm_plugin` writes. Do not tidy it.
const _wire =
    '{"title":"ZFS","items":['
    '{"label":"tank","value":"ONLINE","percent":0.33,"tone":"success"},'
    '{"label":"pool2","value":"42C","tone":"normal"}'
    '],"note":"2 pools"}';

/// The smallest `/metrics` the mapper will accept, with a `plugin_status` in
/// it. Everything else is what an agent reporting nothing sends.
Map<String, dynamic> _metrics(Object? pluginStatus) => {
  'timestamp': '2026-09-08T00:00:00Z',
  'server_name': 'one',
  'cpu_usage': 0.0,
  'memory': {'total': 0, 'used': 0, 'free': 0, 'usage_percent': 0.0},
  'swap': {'total': 0, 'used': 0, 'usage_percent': 0.0},
  'disk': {'total': 0, 'used': 0, 'free': 0, 'usage_percent': 0.0},
  'network': {'rx_bytes': 0, 'tx_bytes': 0},
  'plugin_status': ?pluginStatus,
};

ServerStatus _statusFrom(Object? pluginStatus) => applyMonitorMetrics(
  InitStatus.status,
  MonitorMetrics.fromJson(_metrics(pluginStatus)),
);

void main() {
  test('the shape the agent writes is the shape the app reads', () {
    final status = _statusFrom({'app.serverbox.zfs': jsonDecode(_wire)});

    final zfs = status.agentPlugins['app.serverbox.zfs']!;
    expect(zfs.title, 'ZFS');
    expect(zfs.note, '2 pools');
    expect(zfs.items, hasLength(2));

    expect(zfs.items[0].label, 'tank');
    expect(zfs.items[0].value, 'ONLINE');
    expect(zfs.items[0].percent, closeTo(0.33, 1e-9));
    expect(zfs.items[0].tone, 'success');
  });

  /// `percent` is absent rather than null where the reading is not a
  /// proportion, and the app has to read that as "no bar" rather than as zero
  /// — a bar at 0% is a claim, and none was made.
  test('a reading with no proportion has no percent', () {
    final status = _statusFrom({'p': jsonDecode(_wire)});
    final second = status.agentPlugins['p']!.items[1];

    expect(second.percent, isNull);
    expect(second.tone, 'normal');
  });

  /// An agent predating the field sends nothing, which reads exactly like an
  /// agent running no plugins — so the app leaves what it knew alone rather
  /// than clearing it.
  test('an agent that says nothing is not an agent with nothing', () {
    final before = _statusFrom({'p': jsonDecode(_wire)});
    expect(before.agentPlugins, isNotEmpty);

    applyMonitorMetrics(before, MonitorMetrics.fromJson(_metrics(null)));

    expect(
      before.agentPlugins,
      isNotEmpty,
      reason: 'a missing field must not clear what the last cycle reported',
    );
  });

  test('an agent running none reports an empty map, not a missing one', () {
    final status = _statusFrom(<String, dynamic>{});

    expect(status.agentPlugins, isEmpty);
  });

  /// A document this build cannot read costs that plugin's card, never the
  /// rest of the metrics — the mapper applies each section on its own.
  test('a plugin whose reading will not parse costs only itself', () {
    final status = _statusFrom({'p': 'not an object'});

    expect(status.agentPlugins, isEmpty);
    // The rest of the document still landed.
    expect(status.err, isNull);
  });
}
