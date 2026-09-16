import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_push.dart';
import 'package:server_box/data/model/server/monitor_settings.dart';

/// The app's half of two contracts whose other half is in Rust
/// (`monitor/src/api/server.rs` and `monitor/src/api/push.rs`).
///
/// Both endpoints replace everything they are sent, so a field this side
/// forgets to send is a field the agent clears. And a push credential is
/// write-only: the agent answers `null` where one is set, and reads that same
/// `null` coming back as "keep". Getting either wrong is silent — a cleared
/// retention policy or a notification channel that stops delivering — which is
/// why they are asserted on the encoded JSON rather than on the model.
void main() {
  group('settings payload', () {
    test('names exactly the fields the agent replaces', () {
      final settings = MonitorSettings.fromJson(_settingsResponse);
      expect(settings.toPayload().keys.toSet(), {
        'interval_seconds',
        'extended_interval_secs',
        'idle_pause_enabled',
        'idle_pause_threshold_secs',
        'rules',
        'data_retention',
        'cors_allowed_origins',
      });
    });

    test('drops the fields that are the agent\'s to answer', () {
      final settings = MonitorSettings.fromJson(_settingsResponse);
      final payload = settings.toPayload();
      // Both are GET-only. `live_fields` is the agent describing itself, and
      // sending `data_retention_defaults` back would write the defaults into
      // the config file as though the user had chosen them.
      expect(payload.containsKey('live_fields'), isFalse);
      expect(payload.containsKey('data_retention_defaults'), isFalse);
    });

    test('an absent retention policy stays absent, and is not the defaults', () {
      final settings = MonitorSettings.fromJson({
        ..._settingsResponse,
        'data_retention': null,
      });
      // Absent means the agent never deletes anything — a different thing from
      // deleting on the default schedule, and the one an editor must not
      // quietly turn into the other.
      expect(settings.dataRetention, isNull);
      expect(settings.toPayload()['data_retention'], isNull);
      expect(settings.dataRetentionDefaults.metricsDays, 30);
    });

    test('an agent too old to send defaults still answers with some', () {
      final response = {..._settingsResponse}
        ..remove('data_retention_defaults');
      final settings = MonitorSettings.fromJson(response);
      expect(settings.dataRetentionDefaults.metricsDays, 30);
      expect(settings.dataRetentionDefaults.alertsDays, 90);
      expect(settings.dataRetentionDefaults.cleanupIntervalHours, 24);
    });

    test('a null interval clears it rather than sending a zero', () {
      final settings = MonitorSettings.fromJson(_settingsResponse).copyWith(
        extendedIntervalSecs: () => null,
        idlePauseThresholdSecs: () => null,
      );
      expect(settings.toPayload()['extended_interval_secs'], isNull);
      expect(settings.toPayload()['idle_pause_threshold_secs'], isNull);
    });

    test('rules round-trip through the wire names', () {
      final settings = MonitorSettings.fromJson(_settingsResponse);
      expect(settings.rules.single.monitorType, 'cpu');
      expect(settings.rules.single.toJson(), {
        'name': 'High CPU',
        'monitor_type': 'cpu',
        'threshold': '>=80%',
        'matcher': 'cpu',
      });
    });
  });

  group('push channels', () {
    test('a withheld credential is null, and says so', () {
      final list = MonitorPushList.fromJson(_pushResponse);
      final bark = list.pushes.first;
      expect(bark.isWithheld('key'), isTrue);
      expect(bark.isWithheld('server'), isFalse);
      // Absent is not the same answer: it means the agent has no such value,
      // where null means it has one and will not say what.
      expect(bark.isWithheld('title'), isFalse);
    });

    test('from_index is the position loaded, not the position sent', () {
      final list = MonitorPushList.fromJson(_pushResponse);
      expect(list.pushes.map((p) => p.fromIndex), [0, 1]);

      // A rename and a reorder: what identifies the stored credential is the
      // index that travelled with the entry, not where it now sits.
      final reordered = MonitorPushList(
        pushes: [
          list.pushes[1],
          list.pushes[0].copyWith(name: 'renamed'),
        ],
      );
      final sent = reordered.toPayload()['pushes'] as List;
      expect((sent[0] as Map)['from_index'], 1);
      expect((sent[1] as Map)['from_index'], 0);
      expect((sent[1] as Map)['name'], 'renamed');
    });

    test('the withheld null survives being encoded', () {
      final list = MonitorPushList.fromJson(_pushResponse);
      final encoded = jsonEncode(list.toPayload());
      // `jsonEncode` keeps a null map *value*; a model that dropped it would
      // make the agent read the key as removed and the channel would lose its
      // key on the first save from this app.
      expect(encoded, contains('"key":null'));
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final first = (decoded['pushes'] as List).first as Map<String, dynamic>;
      expect((first['config'] as Map).containsKey('key'), isTrue);
      expect((first['config'] as Map)['key'], isNull);
    });

    test('a new channel carries no index to resolve against', () {
      const added = MonitorPushEntry(
        name: 'hook',
        pushType: 'webhook',
        config: {'url': 'https://example.invalid/'},
      );
      expect(added.toJson()['from_index'], isNull);
    });

    test('a type this agent cannot send through comes back uneditable', () {
      final list = MonitorPushList.fromJson(_pushResponse);
      final unknown = MonitorPushList.fromJson({
        'pushes': [
          {'name': 'tg', 'push_type': 'telegram', 'config': {}, 'editable': false},
        ],
      });
      expect(list.pushes.first.editable, isTrue);
      expect(unknown.pushes.single.editable, isFalse);
      // Its config is withheld whole, since the agent cannot know which of its
      // keys are credentials.
      expect(unknown.pushes.single.config, isEmpty);
    });

    test('a blank rate is not sent as a rate the agent cannot read', () {
      const list = MonitorPushList(pushes: [], pushRate: null);
      expect(list.toPayload()['push_rate'], isNull);
    });

    test('editable is the agent\'s answer and is never sent back', () {
      final list = MonitorPushList.fromJson(_pushResponse);
      expect(list.pushes.first.toJson().containsKey('editable'), isFalse);
    });
  });
}

const _settingsResponse = <String, dynamic>{
  'interval_seconds': 7,
  'extended_interval_secs': 120,
  'idle_pause_enabled': true,
  'idle_pause_threshold_secs': null,
  'rules': [
    {
      'name': 'High CPU',
      'monitor_type': 'cpu',
      'threshold': '>=80%',
      'matcher': 'cpu',
    },
  ],
  'data_retention': {
    'metrics_days': 14,
    'alerts_days': 30,
    'cleanup_interval_hours': 12,
    'max_db_size_mb': 512,
  },
  'cors_allowed_origins': ['https://panel.example.com'],
  'live_fields': [
    'extended_interval_secs',
    'idle_pause_enabled',
    'idle_pause_threshold_secs',
  ],
  'data_retention_defaults': {
    'metrics_days': 30,
    'alerts_days': 90,
    'cleanup_interval_hours': 24,
    'max_db_size_mb': 256,
  },
};

const _pushResponse = <String, dynamic>{
  'pushes': [
    {
      'name': 'phone',
      'push_type': 'bark',
      'config': {
        'server': 'https://api.day.app',
        'key': null,
        'title': 'ServerBox Monitor',
      },
      'editable': true,
    },
    {
      'name': 'hook',
      'push_type': 'webhook',
      'config': {
        'url': 'https://example.invalid/hook',
        'headers': {'Authorization': null},
      },
      'editable': true,
    },
  ],
  'push_rate': '1/1m',
  'push_types': ['webhook', 'serverchan', 'bark', 'ios'],
  'applies_on_restart': true,
};
