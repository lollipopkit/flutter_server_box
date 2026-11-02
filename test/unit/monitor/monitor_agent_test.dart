import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_agent.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

void main() {
  group('agent events', () {
    test('a data frame is its JSON object', () {
      expect(MonitorHttpClient.sseData('data: {"type":"resync"}'), {'type': 'resync'});
      // Split over lines, as the format allows.
      expect(MonitorHttpClient.sseData('data: {"type":\ndata: "flow"}'), {'type': 'flow'});
    });

    test('comments and anything else are nothing', () {
      expect(MonitorHttpClient.sseData(': ok'), isNull);
      expect(MonitorHttpClient.sseData(': ping'), isNull);
      expect(MonitorHttpClient.sseData('data: not json'), isNull);
      expect(MonitorHttpClient.sseData('data: [1]'), isNull);
    });
  });

  group('agent tasks', () {
    final flow = {
      'id': 'f1',
      'title': 'Disk usage',
      'status': 'waiting',
      'line': 'Checking /var',
      'areas': ['files'],
      'mode': 'manual',
      'createdAt': '2026-10-12T08:00:00.123456789+00:00',
      'updatedAt': '2026-10-12T08:01:00+00:00',
      'startedAt': null,
      'finishedAt': null,
      'waiting': 'sudo',
    };

    test('a list reads as the agent wrote it', () {
      final list = MonitorAgentFlows.fromJson({
        'flows': [flow],
        'configured': true,
        'maxRunning': 3,
        'hostname': 'h',
        'defaultMode': 'auto',
        'bypassAllowed': false,
      });
      expect(list.configured, isTrue);
      expect(list.next, isNull, reason: 'an agent that does not page lists it all');
      expect(list.defaultMode, 'auto');
      final f = list.flows.single;
      expect((f.id, f.title, f.status, f.waiting), ('f1', 'Disk usage', MonitorAgentStatus.waiting, 'sudo'));
      expect(f.status.active, isTrue);
      expect(f.updatedAt.toUtc(), DateTime.utc(2026, 10, 12, 8, 1));
    });

    test('a page says where the next one starts', () {
      final page = MonitorAgentFlows.fromJson({'flows': [flow], 'configured': true, 'next': '2026-10-12T08:01:00+00:00|f1'});
      expect(page.next, '2026-10-12T08:01:00+00:00|f1');
    });

    test('an unknown status is a finished one, not an active one', () {
      expect(MonitorAgentStatus.of('later'), MonitorAgentStatus.done);
      expect(MonitorAgentStatus.of('cancelled').active, isFalse);
    });

    test('a detail carries its entries, what it waits on and its output', () {
      final d = MonitorAgentDetail.fromJson({
        'flow': flow,
        'entries': [
          {'id': '7', 'parentId': null, 'type': 'message', 'seq': 7, 'timestamp': 1, 'message': {'role': 'user', 'content': [{'type': 'text', 'text': 'hi'}]}},
        ],
        'pending': {
          'id': 'p1',
          'kind': 'danger',
          'toolCallId': 'c1',
          'title': 'Remove',
          'command': 'rm -rf /tmp/x',
          'alternatives': ['rm -ri /tmp/x'],
          'confirmText': 'host',
        },
        'output': {'toolCallId': 'c1', 'lines': [[1, 'a'], [2, 'b']], 'omitted': 3},
      });
      expect(d.entries.single['id'], '7');
      final p = d.pending!;
      expect((p.kind, p.command, p.confirmText), ('danger', 'rm -rf /tmp/x', 'host'));
      expect(p.alternatives, ['rm -ri /tmp/x']);
      expect(d.output!.lines, ['a', 'b']);
      expect(d.output!.omitted, 3);
    });

    test('a plan lists its steps; a question its options', () {
      final plan = MonitorAgentPending.fromJson({
        'id': 'p',
        'kind': 'confirm',
        'steps': [
          {'text': 'Look', 'command': 'df -h'},
          {'text': 'Think'},
        ],
      });
      expect(plan.command, isNull);
      expect(plan.steps.map((s) => (s.text, s.command)), [('Look', 'df -h'), ('Think', null)]);
      final ask = MonitorAgentPending.fromJson({
        'id': 'q',
        'kind': 'clarify',
        'options': [
          {'label': 'A', 'hint': 'first'},
          {'label': 'B'},
        ],
      });
      expect(ask.options.map((o) => (o.label, o.hint)), [('A', 'first'), ('B', null)]);
    });
  });
}
