/// Opt-in end-to-end test against a real BMC.
///
/// **Read-only. Nothing here changes the machine's power state, and nothing
/// here may be made to.** The reset action is *read* — its target and its
/// `ResetType@Redfish.AllowableValues` are what the whole negotiation rests on,
/// and confirming them against real firmware is the point — but no POST is ever
/// sent to it. That is the same line `crates/sbm_parser/tests/ssh_e2e.rs`
/// draws: destructive functions are never executed against real hosts, and are
/// covered by text assertions elsewhere. Here that elsewhere is
/// `test/bmc_power_test.dart`.
///
/// What this can tell that no fixture can: which of the two sensor models the
/// firmware in front of you actually presents, whether its ids are shaped the
/// way the recorded ones are, and whether a session is really given back.
///
/// Configuration, from the environment or the workspace-root `.env` (which is
/// gitignored). Skipped silently when unset:
///
/// ```
/// SBM_E2E_BMC_URL=https://10.0.0.9
/// SBM_E2E_BMC_USER=...
/// SBM_E2E_BMC_PWD=...
/// ```
///
/// The certificate is read and pinned by the test itself, the same way the edit
/// page does it — a BMC's self-signed certificate is not something to put in a
/// config file.
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/cert_pin.dart';
import 'package:server_box/data/model/server/bmc/redfish.dart';
import 'package:server_box/data/model/server/bmc/redfish_sensors.dart';
import 'package:server_box/data/model/server/bmc/redfish_service.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/provider/bmc/redfish_client.dart';

String? _env(String key) {
  final fromEnv = Platform.environment[key];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  final dotenv = File('.env');
  if (!dotenv.existsSync()) return null;
  for (final line in dotenv.readAsLinesSync()) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('$key=')) continue;
    final value = trimmed
        .substring(key.length + 1)
        .trim()
        .replaceAll(RegExp(r'''^["']|["']$'''), '');
    if (value.isNotEmpty) return value;
  }
  return null;
}

void main() {
  final url = _env('SBM_E2E_BMC_URL');
  if (url == null) {
    test('bmc redfish e2e', () {}, skip: 'SBM_E2E_BMC_URL not set');
    return;
  }

  final user = _env('SBM_E2E_BMC_USER') ?? '';
  final pwd = _env('SBM_E2E_BMC_PWD');

  late RedfishClient client;
  late RedfishTopology topology;

  setUpAll(() async {
    final probe = BmcCfg(addr: url, user: user);
    final uri = probe.uri;
    expect(uri, isNotNull, reason: 'SBM_E2E_BMC_URL must be a URL');

    // Read the certificate and pin it, as the edit page does. Not from config:
    // a self-signed certificate is something someone looks at, not something
    // written down in advance.
    final cert = await fetchServerCert(uri!.host, probe.port);
    // ignore: avoid_print
    print('certificate: ${cert.subject} — ${cert.prettyFingerprint}');
    if (cert.isExpired) {
      // ignore: avoid_print
      print('note: outside its validity dates, which is common on a BMC');
    }

    client = RedfishClient(
      BmcCfg(addr: url, user: user, pwd: pwd, certSha256: cert.fingerprint),
    );
    addTearDown(client.close);

    topology = await RedfishDiscovery(client).run();
  });

  test('the service root identifies itself', () async {
    final root = topology.root;
    // ignore: avoid_print
    print(
      'Redfish ${root.version ?? '?'} — '
      '${root.vendor ?? ''} ${root.product ?? ''}'.trim(),
    );
    expect(root.isService, isTrue);
    expect(root.systems, isNotNull);
  });

  test('the system id is whatever this vendor calls it', () async {
    // The whole reason collections are walked. Printed rather than asserted
    // against a list: a fourth shape is a thing to learn, not a failure.
    // ignore: avoid_print
    print('system:  ${topology.systemPath}');
    // ignore: avoid_print
    print('chassis: ${topology.chassisPath ?? '(none)'}');
    expect(topology.systemPath, isNotNull);
    expect(topology.isUsable, isTrue);
  });

  test('the system reports a power state and what it is', () async {
    final system = topology.system!;
    // ignore: avoid_print
    print(
      'power=${system.powerState.name} model=${system.model} '
      'bios=${system.biosVersion} health=${system.health}',
    );
    expect(
      system.powerState,
      isNot(PowerState.unknown),
      reason: 'an unrecognised PowerState means the enum needs a new case',
    );
  });

  test('the reset action is read, and never sent', () async {
    final system = topology.system!;
    // ignore: avoid_print
    print('reset target: ${system.resetTarget}');
    // ignore: avoid_print
    print('allowed:      ${system.resetTypes.join(', ')}');

    // Which intents this hardware could satisfy — the negotiation, checked
    // against real firmware rather than a recorded list
    for (final intent in PowerIntent.values) {
      final req = ResetRequest.build(system, intent);
      // ignore: avoid_print
      print('  ${intent.name.padRight(18)} -> ${req?.resetType ?? '(none)'}');
    }

    expect(
      system.resetTypes,
      isNotEmpty,
      reason: 'a service advertising no reset types can offer no power control',
    );
  });

  test('the sensor model is whichever this firmware presents', () async {
    final chassis = topology.chassis;
    if (chassis == null) {
      // ignore: avoid_print
      print('no chassis readable — sensors unavailable on this service');
      return;
    }

    // ignore: avoid_print
    print('sensor model: ${chassis.model.name}');
    // ignore: avoid_print
    print('  Thermal=${chassis.thermal} Power=${chassis.power}');
    // ignore: avoid_print
    print(
      '  ThermalSubsystem=${chassis.thermalSubsystem} '
      'Sensors=${chassis.sensors}',
    );

    final BmcSensors sensors;
    switch (chassis.model) {
      case SensorModel.legacy:
        sensors = BmcSensors.fromLegacy(
          thermal: chassis.thermal == null
              ? null
              : await client.get(chassis.thermal!),
          power: chassis.power == null
              ? null
              : await client.get(chassis.power!),
        );
      case SensorModel.modern:
        final members = collectionMembers(await client.get(chassis.sensors!));
        // ignore: avoid_print
        print('  ${members.length} sensor resources');
        final fetched = <Map<String, dynamic>>[];
        for (final path in members.take(16)) {
          fetched.add(await client.get(path));
        }
        sensors = BmcSensors.fromSensors(fetched);
      case SensorModel.none:
        // ignore: avoid_print
        print('  neither model linked');
        return;
    }

    for (final r in [...sensors.temperatures, ...sensors.fans]) {
      // ignore: avoid_print
      print('  ${r.name}: ${r.value} ${r.unit ?? ''}');
    }
    // ignore: avoid_print
    print('  watts: ${sensors.watts}');
  });

  test('a session is created once and given back', () async {
    // The arithmetic that matters: BMCs allow few, and one that is never
    // deleted stays until it times out. Everything above shared one client and
    // therefore one session; this closes it and shows the next one can log in.
    await client.close();

    final cert = await fetchServerCert(
      Uri.parse(url).host,
      BmcCfg(addr: url, user: user).port,
    );
    final second = RedfishClient(
      BmcCfg(addr: url, user: user, pwd: pwd, certSha256: cert.fingerprint),
    );
    addTearDown(second.close);

    final root = await second.probe();
    expect(root['@odata.id'] ?? root['RedfishVersion'], isNotNull);
  });
}
