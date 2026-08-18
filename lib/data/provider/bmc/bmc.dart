import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/bmc/redfish.dart';
import 'package:server_box/data/model/server/bmc/redfish_sensors.dart';
import 'package:server_box/data/model/server/bmc/redfish_service.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/bmc/redfish_client.dart';

part 'bmc.freezed.dart';
part 'bmc.g.dart';

/// How often the BMC is asked, which is not how often the host is.
///
/// A BMC is slow — a thermal fetch takes seconds — and it is answering about
/// hardware, which does not move at the rate a status page does. Riding on the
/// status poll would spend most of a device's capacity on numbers nobody is
/// watching change. The same reason the extended status commands have a cycle
/// of their own.
const _pollInterval = Duration(minutes: 1);

/// How many members of a `Sensors` collection to read.
///
/// The new model puts every reading in its own resource, so a chassis with a
/// hundred sensors is a hundred requests to a device that answers in seconds.
/// A cap is the only thing that keeps one poll from outlasting the next, and
/// [BmcState.sensorsTruncated] says when one was applied — a silent cap reads
/// as "this machine has 64 sensors".
const _maxSensorMembers = 64;

@freezed
abstract class BmcState with _$BmcState {
  const factory BmcState({
    /// Null until the first successful discovery.
    RedfishTopology? topology,
    @Default(BmcSensors()) BmcSensors sensors,
    RedfishFailure? failure,
    String? failureDetail,
    @Default(false) bool isBusy,

    /// Set when the sensor list was cut to [_maxSensorMembers].
    @Default(false) bool sensorsTruncated,
  }) = _BmcState;

  const BmcState._();

  /// What the machine's power is doing, or unknown before the first answer.
  PowerState get powerState =>
      topology?.system?.powerState ?? PowerState.unknown;

  /// Whether there is anything to show.
  bool get hasData => topology?.isUsable == true;
}

/// One server's BMC.
///
/// Holds a [RedfishClient], and therefore a session on a device that allows
/// few of them — so the client is closed on dispose, which is the only thing
/// that gives the session back. See `docs/principles/bmc.md`.
@riverpod
class BmcNotifier extends _$BmcNotifier {
  RedfishClient? _client;
  Timer? _timer;

  /// Rises on every rebuild, so a fetch in flight when the config changed can
  /// tell that its answer is no longer wanted.
  var _generation = 0;

  @override
  BmcState build(Spi spi) {
    final cfg = spi.bmc;

    ref.onDispose(() {
      _generation++;
      _timer?.cancel();
      _timer = null;
      // Not awaited — dispose cannot wait — but started, because a session
      // nobody ends stays on the BMC until it times out
      unawaited(_client?.close());
      _client = null;
    });

    if (cfg == null || !cfg.isComplete) return const BmcState();

    _client = RedfishClient(cfg);
    unawaited(refresh());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));

    return const BmcState(isBusy: true);
  }

  /// Reads the machine once.
  ///
  /// Discovery runs only when there is nothing yet: which ids and which sensor
  /// model do not change while a connection lives, and re-deriving them is
  /// several round trips this device can least afford.
  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    final generation = _generation;

    if (!state.isBusy) state = state.copyWith(isBusy: true);

    try {
      final topology = state.topology ?? await RedfishDiscovery(client).run();
      // The system is re-read every time — power state is the point of this
      final system = RedfishSystem.fromJson(
        await client.get(topology.systemPath!),
      );
      final fresh = RedfishTopology(
        root: topology.root,
        systemPath: topology.systemPath,
        chassisPath: topology.chassisPath,
        system: system,
        chassis: topology.chassis,
      );

      final (sensors, truncated) = await _readSensors(client, topology);
      if (generation != _generation) return;

      state = state.copyWith(
        topology: fresh,
        sensors: sensors,
        sensorsTruncated: truncated,
        failure: null,
        failureDetail: null,
        isBusy: false,
      );
    } on RedfishException catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        failure: e.failure,
        failureDetail: e.detail,
        isBusy: false,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        failure: RedfishFailure.unreachable,
        failureDetail: '$e',
        isBusy: false,
      );
    }
  }

  /// Sensors, by whichever model this chassis presents.
  ///
  /// Never fatal: a chassis that cannot be read costs the readings, and the
  /// power state — the thing this feature exists for — is already in hand.
  Future<(BmcSensors, bool)> _readSensors(
    RedfishClient client,
    RedfishTopology topology,
  ) async {
    final chassis = topology.chassis;
    if (chassis == null) return (const BmcSensors(), false);

    try {
      switch (chassis.model) {
        case SensorModel.legacy:
          final thermal = chassis.thermal;
          final power = chassis.power;
          return (
            BmcSensors.fromLegacy(
              thermal: thermal == null ? null : await client.get(thermal),
              power: power == null ? null : await client.get(power),
            ),
            false,
          );
        case SensorModel.modern:
          final members = collectionMembers(await client.get(chassis.sensors!));
          final truncated = members.length > _maxSensorMembers;
          final wanted = truncated
              ? members.take(_maxSensorMembers)
              : members;
          final fetched = <Map<String, dynamic>>[];
          for (final path in wanted) {
            fetched.add(await client.get(path));
          }
          if (truncated) {
            Loggers.app.info(
              'BMC sensors truncated: ${members.length} offered, '
              '$_maxSensorMembers read',
            );
          }
          return (BmcSensors.fromSensors(fetched), truncated);
        case SensorModel.none:
          return (const BmcSensors(), false);
      }
    } catch (e) {
      Loggers.app.warning('BMC sensors unavailable', e);
      return (const BmcSensors(), false);
    }
  }
}
