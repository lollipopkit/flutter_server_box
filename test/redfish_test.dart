/// Redfish against the shapes four vendors actually present.
///
/// The point of every case here is that nothing about a service's layout may
/// be assumed. The ids differ (`1`, `System.Embedded.1`, `system`), the sensor
/// model differs by firmware generation and transitional firmware carries both,
/// and a reset type being advertised is the only statement a service makes
/// about what it will accept — see `docs/principles/bmc.md`.
///
/// None of this needs a BMC, which is why the layer under the transport is
/// pure. The one thing deliberately absent: no test performs a reset. The
/// request a reset *would* be is asserted; sending it is left to a person, the
/// way `script_compat` treats shutdown and reboot.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/bmc/redfish.dart';
import 'package:server_box/data/model/server/bmc/redfish_service.dart';

/// A service made of recorded responses.
class _FakeTransport implements RedfishTransport {
  _FakeTransport(this.resources, {this.forbidden = const {}});

  final Map<String, Map<String, dynamic>> resources;
  final Set<String> forbidden;
  final posted = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (forbidden.contains(path)) {
      throw const RedfishException(RedfishFailure.forbidden);
    }
    final res = resources[path];
    if (res == null) throw StateError('no such resource: $path');
    return res;
  }

  @override
  Future<void> post(String path, Map<String, dynamic> body) async {
    posted.add((path, body));
  }
}

/// Dell iDRAC 9: ids like `System.Embedded.1`, legacy sensor model.
Map<String, Map<String, dynamic>> _dell() => {
  '/redfish/v1/': {
    'RedfishVersion': '1.13.0',
    'Product': 'Integrated Dell Remote Access Controller',
    'Systems': {'@odata.id': '/redfish/v1/Systems'},
    'Chassis': {'@odata.id': '/redfish/v1/Chassis'},
    'Links': {
      'Sessions': {'@odata.id': '/redfish/v1/Sessions'},
    },
  },
  '/redfish/v1/Systems': {
    'Members': [
      {'@odata.id': '/redfish/v1/Systems/System.Embedded.1'},
    ],
    'Members@odata.count': 1,
  },
  '/redfish/v1/Chassis': {
    'Members': [
      {'@odata.id': '/redfish/v1/Chassis/System.Embedded.1'},
    ],
  },
  '/redfish/v1/Systems/System.Embedded.1': {
    'PowerState': 'On',
    'Model': 'PowerEdge R740',
    'Manufacturer': 'Dell Inc.',
    'SerialNumber': 'ABCDEF1',
    'BiosVersion': '2.19.0',
    'Status': {'Health': 'OK', 'HealthRollup': 'Warning', 'State': 'Enabled'},
    'Actions': {
      '#ComputerSystem.Reset': {
        'target':
            '/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset',
        'ResetType@Redfish.AllowableValues': [
          'On',
          'ForceOff',
          'ForceRestart',
          'GracefulShutdown',
          'PushPowerButton',
          'Nmi',
        ],
      },
    },
  },
  '/redfish/v1/Chassis/System.Embedded.1': {
    'Name': 'Computer System Chassis',
    'Thermal': {'@odata.id': '/redfish/v1/Chassis/System.Embedded.1/Thermal'},
    'Power': {'@odata.id': '/redfish/v1/Chassis/System.Embedded.1/Power'},
  },
};

/// Supermicro X11: id `1`, legacy sensor model.
Map<String, Map<String, dynamic>> _supermicro() => {
  '/redfish/v1/': {
    'RedfishVersion': '1.8.0',
    'Systems': {'@odata.id': '/redfish/v1/Systems'},
    'Chassis': {'@odata.id': '/redfish/v1/Chassis'},
    'SessionService': {'@odata.id': '/redfish/v1/SessionService'},
  },
  '/redfish/v1/Systems': {
    'Members': [
      {'@odata.id': '/redfish/v1/Systems/1'},
    ],
  },
  '/redfish/v1/Chassis': {
    'Members': [
      {'@odata.id': '/redfish/v1/Chassis/1'},
    ],
  },
  '/redfish/v1/Systems/1': {
    'PowerState': 'Off',
    'Model': 'SYS-1029P',
    'Actions': {
      '#ComputerSystem.Reset': {
        'target': '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset',
        'ResetType@Redfish.AllowableValues': [
          'On',
          'ForceOff',
          'GracefulShutdown',
          'GracefulRestart',
          'ForceRestart',
          'Nmi',
          'ForceOn',
          'PowerCycle',
        ],
      },
    },
  },
  '/redfish/v1/Chassis/1': {
    'Thermal': {'@odata.id': '/redfish/v1/Chassis/1/Thermal'},
    'Power': {'@odata.id': '/redfish/v1/Chassis/1/Power'},
  },
};

/// OpenBMC: id `system`, modern sensor model only.
Map<String, Map<String, dynamic>> _openbmc() => {
  '/redfish/v1/': {
    'RedfishVersion': '1.15.0',
    'Systems': {'@odata.id': '/redfish/v1/Systems'},
    'Chassis': {'@odata.id': '/redfish/v1/Chassis'},
    'Links': {
      'Sessions': {'@odata.id': '/redfish/v1/SessionService/Sessions'},
    },
  },
  '/redfish/v1/Systems': {
    'Members': [
      {'@odata.id': '/redfish/v1/Systems/system'},
    ],
  },
  '/redfish/v1/Chassis': {
    'Members': [
      {'@odata.id': '/redfish/v1/Chassis/chassis'},
    ],
  },
  '/redfish/v1/Systems/system': {
    'PowerState': 'On',
    'Actions': {
      '#ComputerSystem.Reset': {
        'target': '/redfish/v1/Systems/system/Actions/ComputerSystem.Reset',
        'ResetType@Redfish.AllowableValues': [
          'On',
          'ForceOff',
          'ForceRestart',
          'GracefulRestart',
          'GracefulShutdown',
          'PowerCycle',
          'Nmi',
        ],
      },
    },
  },
  '/redfish/v1/Chassis/chassis': {
    'ThermalSubsystem': {
      '@odata.id': '/redfish/v1/Chassis/chassis/ThermalSubsystem',
    },
    'PowerSubsystem': {
      '@odata.id': '/redfish/v1/Chassis/chassis/PowerSubsystem',
    },
    'Sensors': {'@odata.id': '/redfish/v1/Chassis/chassis/Sensors'},
  },
};

void main() {
  group('service root', () {
    test('a static host answering every path is not a service', () {
      // What Cloudflare Pages and every other static host does: 200, and the
      // index page. Parsed as JSON it has none of this.
      final root = RedfishRoot.fromJson({'title': 'ServerBox'});
      expect(root.isService, isFalse);
    });

    test('reads the session endpoint from either place it is put', () {
      expect(
        RedfishRoot.fromJson(_dell()['/redfish/v1/']!).sessions,
        '/redfish/v1/Sessions',
      );
      // Supermicro fills in SessionService and no Links.Sessions
      expect(
        RedfishRoot.fromJson(_supermicro()['/redfish/v1/']!).sessions,
        '/redfish/v1/SessionService',
      );
    });
  });

  group('discovery walks collections rather than building paths', () {
    for (final (name, resources, expectedSystem) in [
      ('Dell', _dell(), '/redfish/v1/Systems/System.Embedded.1'),
      ('Supermicro', _supermicro(), '/redfish/v1/Systems/1'),
      ('OpenBMC', _openbmc(), '/redfish/v1/Systems/system'),
    ]) {
      test('$name: finds ${expectedSystem.split('/').last}', () async {
        final topology = await RedfishDiscovery(
          _FakeTransport(resources),
        ).run();
        expect(topology.systemPath, expectedSystem);
        expect(topology.isUsable, isTrue);
      });
    }

    test('a service that is not one is refused before anything else', () {
      expect(
        RedfishDiscovery(
          _FakeTransport({
            '/redfish/v1/': {'title': 'not a bmc'},
          }),
        ).run(),
        throwsA(
          isA<RedfishException>().having(
            (e) => e.failure,
            'failure',
            RedfishFailure.notAService,
          ),
        ),
      );
    });

    test('an empty Systems collection is reported, not crashed on', () {
      final resources = _dell();
      resources['/redfish/v1/Systems'] = {'Members': <Object>[]};
      expect(
        RedfishDiscovery(_FakeTransport(resources)).run(),
        throwsA(
          isA<RedfishException>().having(
            (e) => e.failure,
            'failure',
            RedfishFailure.noSystem,
          ),
        ),
      );
    });

    test('one system is not reported as several', () async {
      final topology = await RedfishDiscovery(_FakeTransport(_dell())).run();
      expect(topology.hasMultipleSystems, isFalse);
    });

    test('a chassis publishing several systems says so', () async {
      // A blade enclosure is one Redfish service with one system per node.
      // Only the first is shown, which is a stated limitation — but showing it
      // silently reports one node's power state as if it were the enclosure's.
      final resources = _dell();
      resources['/redfish/v1/Systems'] = {
        'Members': [
          {'@odata.id': '/redfish/v1/Systems/System.Embedded.1'},
          {'@odata.id': '/redfish/v1/Systems/System.Embedded.2'},
        ],
      };
      final topology = await RedfishDiscovery(_FakeTransport(resources)).run();

      expect(topology.hasMultipleSystems, isTrue);
      expect(
        topology.systemPath,
        '/redfish/v1/Systems/System.Embedded.1',
        reason: 'still the first; the flag is what makes that sayable',
      );
    });

    test('re-reading the system keeps what discovery worked out', () async {
      // A poll re-reads the system and nothing else. Rebuilding the topology
      // field by field at that point dropped `hasMultipleSystems` back to
      // false once a minute, which is why `withSystem` exists.
      final resources = _dell();
      resources['/redfish/v1/Systems'] = {
        'Members': [
          {'@odata.id': '/redfish/v1/Systems/System.Embedded.1'},
          {'@odata.id': '/redfish/v1/Systems/System.Embedded.2'},
        ],
      };
      final topology = await RedfishDiscovery(_FakeTransport(resources)).run();
      final polled = topology.withSystem(topology.system!);

      expect(polled.hasMultipleSystems, isTrue);
      expect(polled.systemPath, topology.systemPath);
      expect(polled.chassisPath, topology.chassisPath);
      expect(polled.chassis, topology.chassis);
    });

    test('a chassis that is refused costs the sensors and nothing else', () async {
      // Licensing gates parts of some services, so a 403 on one sub-resource
      // must not take the power half down with it
      final topology = await RedfishDiscovery(
        _FakeTransport(
          _dell(),
          forbidden: {'/redfish/v1/Chassis/System.Embedded.1'},
        ),
      ).run();

      expect(topology.system, isNotNull);
      expect(topology.system!.powerState, PowerState.on);
      expect(topology.chassis, isNull);
      expect(topology.sensorModel, SensorModel.none);
    });
  });

  group('sensor model', () {
    test('legacy where only Thermal/Power are linked', () {
      final chassis = RedfishChassis.fromJson(
        _dell()['/redfish/v1/Chassis/System.Embedded.1']!,
      );
      expect(chassis.model, SensorModel.legacy);
    });

    test('modern where the subsystems and Sensors are linked', () {
      final chassis = RedfishChassis.fromJson(
        _openbmc()['/redfish/v1/Chassis/chassis']!,
      );
      expect(chassis.model, SensorModel.modern);
    });

    test('transitional firmware carries both, and the new one wins', () {
      // Which is what deprecation means; a service offering both is mid-move
      final chassis = RedfishChassis.fromJson({
        'Thermal': {'@odata.id': '/t'},
        'Power': {'@odata.id': '/p'},
        'ThermalSubsystem': {'@odata.id': '/ts'},
        'PowerSubsystem': {'@odata.id': '/ps'},
        'Sensors': {'@odata.id': '/s'},
      });
      expect(chassis.hasLegacySensors, isTrue);
      expect(chassis.hasModernSensors, isTrue);
      expect(chassis.model, SensorModel.modern);
    });

    test('a subsystem without Sensors has nothing readable in it', () {
      // The readings live in Sensors under the new model, so the links alone
      // are not a path to anything
      final chassis = RedfishChassis.fromJson({
        'ThermalSubsystem': {'@odata.id': '/ts'},
      });
      expect(chassis.model, SensorModel.none);
    });
  });

  group('system', () {
    test('prefers HealthRollup, which accounts for the subsystems', () {
      final system = RedfishSystem.fromJson(
        _dell()['/redfish/v1/Systems/System.Embedded.1']!,
      );
      expect(system.health, 'Warning');
      expect(system.model, 'PowerEdge R740');
      expect(system.biosVersion, '2.19.0');
    });

    test('an unfamiliar power state is shown, not rejected', () {
      expect(
        RedfishSystem.fromJson({'PowerState': 'Hibernating'}).powerState,
        PowerState.unknown,
      );
    });

    test('a service with no reset action cannot be reset', () {
      final system = RedfishSystem.fromJson({'PowerState': 'On'});
      expect(system.canReset, isFalse);
      expect(ResetRequest.build(system, PowerIntent.restart), isNull);
    });
  });

  group('reset type negotiation', () {
    test('Dell has no GracefulRestart, so a restart falls back to force', () {
      final system = RedfishSystem.fromJson(
        _dell()['/redfish/v1/Systems/System.Embedded.1']!,
      );
      final req = ResetRequest.build(system, PowerIntent.restart)!;
      expect(req.resetType, 'ForceRestart');
      expect(
        req.target,
        '/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset',
      );
      expect(req.body, {'ResetType': 'ForceRestart'});
    });

    test('Supermicro has it, so the polite one is used', () {
      final system = RedfishSystem.fromJson(_supermicro()['/redfish/v1/Systems/1']!);
      expect(
        ResetRequest.build(system, PowerIntent.restart)!.resetType,
        'GracefulRestart',
      );
    });

    test('an intent the service allows nothing for yields nothing', () {
      // Not "send something close" — an intent with nothing behind it is not
      // offered, rather than offered and failing when pressed
      final system = RedfishSystem.fromJson({
        'Actions': {
          '#ComputerSystem.Reset': {
            'target': '/t',
            'ResetType@Redfish.AllowableValues': ['On'],
          },
        },
      });
      expect(ResetRequest.build(system, PowerIntent.gracefulShutdown), isNull);
      expect(ResetRequest.build(system, PowerIntent.on)!.resetType, 'On');
    });

    test('the target comes from the action, not from the system path', () {
      // The two agree everywhere seen, but only one of them is what the
      // service said
      final system = RedfishSystem.fromJson({
        'Actions': {
          '#ComputerSystem.Reset': {
            'target': '/somewhere/else/entirely',
            'ResetType@Redfish.AllowableValues': ['ForceOff'],
          },
        },
      });
      expect(
        ResetRequest.build(system, PowerIntent.forceOff)!.target,
        '/somewhere/else/entirely',
      );
    });

    test('an action with no allowable values is not usable', () {
      // Some services omit the annotation entirely. Guessing from the spec's
      // enum would mean sending something the service never claimed to take.
      final system = RedfishSystem.fromJson({
        'Actions': {
          '#ComputerSystem.Reset': {'target': '/t'},
        },
      });
      expect(system.canReset, isFalse);
    });
  });

  group('power state', () {
    test('knows which states are being passed through', () {
      expect(PowerState.poweringOn.isTransitional, isTrue);
      expect(PowerState.poweringOff.isTransitional, isTrue);
      expect(PowerState.on.isTransitional, isFalse);
      expect(PowerState.unknown.isTransitional, isFalse);
    });
  });

  group('collection parsing', () {
    test('a malformed Members is empty rather than an exception', () {
      expect(collectionMembers({'Members': 'nope'}), isEmpty);
      expect(collectionMembers({}), isEmpty);
      expect(
        collectionMembers({
          'Members': [
            {'no-odata-id': 1},
            {'@odata.id': '/ok'},
          ],
        }),
        ['/ok'],
      );
    });
  });
}
