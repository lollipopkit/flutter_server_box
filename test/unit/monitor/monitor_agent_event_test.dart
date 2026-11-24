import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor/monitor_agent.dart';

void main() {
  group('MonitorAgentEvent.fromJson', () {
    test('decodes valid SSE event frames', () {
      final flow = MonitorAgentEvent.fromJson({
        'type': 'flow',
        'flow': {
          'id': 'f1',
          'title': 'Check disk',
          'state': 'running',
          'mode': 'default',
          'createdAt': 1,
          'updatedAt': 2,
        },
      });
      expect(flow, isA<MonitorAgentFlowEvent>());
      expect((flow! as MonitorAgentFlowEvent).flow.id, 'f1');

      final removed = MonitorAgentEvent.fromJson({
        'type': 'removed',
        'id': 'f1',
      });
      expect(removed, isA<MonitorAgentRemovedEvent>());
      expect((removed! as MonitorAgentRemovedEvent).id, 'f1');

      final pending = MonitorAgentEvent.fromJson({
        'type': 'pending',
        'id': 'f1',
        'pending': {'id': 'p1', 'kind': 'confirm'},
      });
      expect(pending, isA<MonitorAgentPendingEvent>());
      expect((pending! as MonitorAgentPendingEvent).pending?.id, 'p1');

      final output = MonitorAgentEvent.fromJson({
        'type': 'output',
        'id': 'f1',
        'lines': [
          [1, 'stdout line'],
          [2, 'stderr line'],
          ['bad'],
        ],
      });
      expect(output, isA<MonitorAgentOutputEvent>());
      expect((output! as MonitorAgentOutputEvent).lines, [
        'stdout line',
        'stderr line',
      ]);

      final piEvent = MonitorAgentEvent.fromJson({
        'type': 'event',
        'id': 'f1',
        'event': {'kind': 'delta'},
      });
      expect(piEvent, isA<MonitorAgentPiEvent>());
      expect((piEvent! as MonitorAgentPiEvent).event, {'kind': 'delta'});

      expect(
        MonitorAgentEvent.fromJson({'type': 'resync'}),
        isA<MonitorAgentResyncEvent>(),
      );
    });

    test('returns null or safe defaults for malformed frames without throwing', () {
      expect(MonitorAgentEvent.fromJson({'type': 'unknown'}), isNull);
      expect(
        MonitorAgentEvent.fromJson({'type': 'flow', 'flow': 'not-a-map'}),
        isNull,
      );
      expect(
        MonitorAgentEvent.fromJson({'type': 'flow', 'flow': <String, dynamic>{}}),
        isNull,
      );
      expect(MonitorAgentEvent.fromJson({'type': 'removed'}), isNull);

      final malformedPending = MonitorAgentEvent.fromJson({
        'type': 'pending',
        'id': 'f1',
        'pending': {'kind': 'confirm'},
      });
      expect(malformedPending, isA<MonitorAgentPendingEvent>());
      expect((malformedPending! as MonitorAgentPendingEvent).pending, isNull);

      final malformedOutput = MonitorAgentEvent.fromJson({
        'type': 'output',
        'id': 'f1',
        'lines': 'not-a-list',
      });
      expect(malformedOutput, isA<MonitorAgentOutputEvent>());
      expect((malformedOutput! as MonitorAgentOutputEvent).lines, isEmpty);

      final malformedPiEvent = MonitorAgentEvent.fromJson({
        'type': 'event',
        'id': 'f1',
        'event': 'not-a-map',
      });
      expect(malformedPiEvent, isA<MonitorAgentPiEvent>());
      expect((malformedPiEvent! as MonitorAgentPiEvent).event, isEmpty);
    });
  });
}
