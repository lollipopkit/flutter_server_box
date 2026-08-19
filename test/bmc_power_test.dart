/// Power control: every decision, and none of the consequences.
///
/// **Nothing in this file, and nothing anywhere in the suite, resets real
/// hardware.** The transport here is a fake; the only thing it does with a
/// reset is write it down. That is the same line `crates/sbm_parser/tests/
/// ssh_e2e.rs` draws — its header says the destructive shell functions are
/// never executed against real hosts, and they are covered by text assertions
/// in `script_compat` instead.
///
/// What is worth locking down is everything up to the send:
///
/// - which `ResetType` an intent becomes, per service, and that it becomes
///   *nothing* where the service allows nothing
/// - that the request goes where the service said, not where the path implies
/// - that a `204` is not treated as a result, because HPE documents that a
///   graceful operation depends on the OS and iLO does not distinguish it
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/bmc/redfish.dart';
import 'package:server_box/data/model/server/bmc/redfish_service.dart';

/// Records what would have been sent.
class _RecordingTransport implements RedfishTransport {
  _RecordingTransport(this.resources);

  final Map<String, Map<String, dynamic>> resources;
  final posted = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    final res = resources[path];
    if (res == null) throw StateError('no such resource: $path');
    return res;
  }

  @override
  Future<void> post(String path, Map<String, dynamic> body) async {
    posted.add((path, body));
  }
}

RedfishSystem _systemAllowing(List<String> types, {String target = '/reset'}) =>
    RedfishSystem.fromJson({
      'PowerState': 'On',
      'Actions': {
        '#ComputerSystem.Reset': {
          'target': target,
          'ResetType@Redfish.AllowableValues': types,
        },
      },
    });

void main() {
  group('which actions a service can offer', () {
    test('an intent with nothing behind it is not offered', () {
      // A button that fails when pressed is worse than one that was never
      // there, and Nmi and PowerCycle are advertised-but-unimplemented often
      // enough that this is not hypothetical
      final system = _systemAllowing(['On', 'ForceOff']);

      final offered = [
        for (final intent in PowerIntent.values)
          if (ResetRequest.build(system, intent) != null) intent,
      ];

      expect(offered, [PowerIntent.on, PowerIntent.forceOff]);
      expect(offered, isNot(contains(PowerIntent.restart)));
      expect(offered, isNot(contains(PowerIntent.gracefulShutdown)));
    });

    test('a service with no reset action offers nothing at all', () {
      final system = RedfishSystem.fromJson({'PowerState': 'On'});
      for (final intent in PowerIntent.values) {
        expect(ResetRequest.build(system, intent), isNull);
      }
    });
  });

  group('which ResetType an intent becomes', () {
    test('restart prefers the graceful one where it exists', () {
      final system = _systemAllowing(['GracefulRestart', 'ForceRestart']);
      expect(
        ResetRequest.build(system, PowerIntent.restart)!.resetType,
        'GracefulRestart',
      );
    });

    test('and falls back where it does not — Dell has no GracefulRestart', () {
      final system = _systemAllowing(['ForceRestart', 'ForceOff', 'On']);
      expect(
        ResetRequest.build(system, PowerIntent.restart)!.resetType,
        'ForceRestart',
      );
    });

    test('power on falls back to ForceOn', () {
      expect(
        ResetRequest.build(_systemAllowing(['ForceOn']), PowerIntent.on)!
            .resetType,
        'ForceOn',
      );
    });

    test('a power cycle falls back to a forced restart', () {
      expect(
        ResetRequest.build(
          _systemAllowing(['ForceRestart']),
          PowerIntent.powerCycle,
        )!.resetType,
        'ForceRestart',
      );
    });

    test('a graceful shutdown has no fallback, by design', () {
      // ForceOff is not a shutdown, and quietly substituting it would take a
      // machine down hard when someone asked for the polite thing
      final system = _systemAllowing(['ForceOff']);
      expect(ResetRequest.build(system, PowerIntent.gracefulShutdown), isNull);
    });
  });

  group('the request itself', () {
    test('goes to the target the service named', () async {
      final system = _systemAllowing(
        ['ForceOff'],
        target: '/redfish/v1/Systems/System.Embedded.1/Actions/'
            'ComputerSystem.Reset',
      );
      final request = ResetRequest.build(system, PowerIntent.forceOff)!;

      final transport = _RecordingTransport({});
      await transport.post(request.target, request.body);

      expect(transport.posted, hasLength(1));
      final (path, body) = transport.posted.single;
      expect(
        path,
        '/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset',
      );
      expect(body, {'ResetType': 'ForceOff'});
    });

    test('carries only the ResetType', () {
      final request = ResetRequest.build(
        _systemAllowing(['GracefulShutdown']),
        PowerIntent.gracefulShutdown,
      )!;
      expect(request.body, {'ResetType': 'GracefulShutdown'});
      expect(request.body.keys, hasLength(1));
    });
  });

  group('what counts as done', () {
    test('a transitional state is not arrival', () {
      // PoweringOff is the machine on its way. Reporting it as done would be
      // reporting the request back rather than the result.
      expect(PowerState.poweringOff.isTransitional, isTrue);
      expect(PowerState.off.isTransitional, isFalse);
    });

    test('the states a confirmation waits to reach are the resting ones', () {
      final resting = PowerState.values.where((s) => !s.isTransitional);
      expect(resting, contains(PowerState.on));
      expect(resting, contains(PowerState.off));
      expect(resting, isNot(contains(PowerState.poweringOn)));
    });
  });
}
