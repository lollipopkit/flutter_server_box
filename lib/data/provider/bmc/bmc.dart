import 'dart:async';

// `select` is an extension on ProviderListenable, which riverpod_annotation
// does not re-export.
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:redfish/redfish.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/bmc_credential.dart';

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

/// How long to wait for a machine to do what it was asked, and how often to
/// look.
///
/// Because the HTTP status is not the answer. HPE documents that
/// `GracefulShutdown` and `GracefulRestart` depend on the OS and that iLO does
/// not distinguish them at that level, so a `204` means the request was
/// accepted and nothing more. What happened is in `PowerState`.
const _powerConfirmTimeout = Duration(minutes: 2);
const _powerPollInterval = Duration(seconds: 5);

/// How many members of a `Sensors` collection to read.
///
/// The new model puts every reading in its own resource, so a chassis with a
/// hundred sensors is a hundred requests to a device that answers in seconds.
/// A cap is the only thing that keeps one poll from outlasting the next, and
/// [BmcState.sensorsTruncated] says when one was applied — a silent cap reads
/// as "this machine has 64 sensors".
const _maxSensorMembers = 64;

/// What came of asking a machine to change state.
enum BmcPowerResult {
  /// `PowerState` moved. The only one that means the machine did something.
  confirmed,

  /// The service accepted the request and the state had not moved before the
  /// wait ran out. Not a failure — a graceful shutdown can take longer than
  /// anyone wants to watch — but not a result either, and it must not be
  /// reported as one.
  accepted,

  /// The service allows nothing that satisfies the intent, so nothing was
  /// sent.
  notSupported,

  failed,
}

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

  /// Whether a read is already going.
  ///
  /// The timer fires on a fixed period; a poll of a slow BMC can take longer
  /// than that period, and `power()` holds the same client for up to two
  /// minutes while it watches for the state to move. Both would otherwise
  /// overlap this one — two discoveries, two sensor sweeps of up to 64
  /// requests each, against a device that allows few of anything.
  ///
  /// A skip rather than a queue: what a poll produces is the current state,
  /// and the one already running is about to publish it.
  var _refreshing = false;

  /// Set while a power operation and the confirmation after it hold the client.
  ///
  /// Separate from [_refreshing] rather than the same flag: `refresh` clears
  /// its own in a `finally`, and a refresh that happens to finish during a
  /// power operation would clear a flag it did not set — reopening the window
  /// this closes for the rest of a confirmation that runs up to two minutes
  /// against a timer that fires every one.
  ///
  /// `power` does not skip when a refresh is running. It is what the user
  /// asked for, and the reads it races are reads.
  var _powering = false;

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

    // The account may have been deleted since this server was configured: the
    // foreign key sets `bmc_cred_id` to null rather than taking the server
    // with it, so `isComplete` above is about the id being *named*, and this is
    // about the record still being there.
    //
    // Watched rather than read once. An account is a record several servers
    // share, so rotating its password from the account page has to reach a
    // detail page that is already open; a snapshot kept the old password and
    // its session, and every poll after the BMC expired that session failed
    // until the page was disposed. Narrowed to this one account, or editing an
    // unrelated one would tear this server's polling down and re-run discovery.
    final credId = cfg.credId!;
    final cred = ref.watch(
      bmcCredentialProvider.select(
        (state) => state.creds.firstWhereOrNull((e) => e.id == credId),
      ),
    );
    if (cred == null || !cred.isComplete) {
      return const BmcState(failure: RedfishFailure.noCredential);
    }

    // Plain values, not this app's records: the client is `package:redfish`
    // now and knows nothing about how anything here is stored.
    _client = RedfishClient(
      baseUrl: cfg.addr,
      user: cred.user,
      password: cred.pwd,
      pinnedCertSha256: cfg.certSha256,
      onWarning: (message, error) => Loggers.app.warning('BMC: $message', error),
    );
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
    if (client == null || _refreshing || _powering) return;
    final generation = _generation;
    _refreshing = true;

    if (!state.isBusy) state = state.copyWith(isBusy: true);

    try {
      final topology = state.topology ?? await RedfishDiscovery(client).run();
      // The system is re-read every time — power state is the point of this
      final system = RedfishSystem.fromJson(
        await client.get(topology.systemPath!),
      );
      final fresh = topology.withSystem(system);

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
    } finally {
      // In a `finally` because the three branches above return early on a
      // stale generation, and a flag left set there would stop this notifier
      // ever polling again.
      _refreshing = false;
    }
  }

  /// The request [intent] would become, or null if this service allows nothing
  /// that satisfies it.
  ///
  /// Public and separate from [power] so the UI can ask what is possible
  /// before offering it — an action that is offered and then fails when pressed
  /// is worse than one that was never there — and so a test can assert which
  /// request would be sent without a machine being reset to find out.
  ResetRequest? plan(PowerIntent intent) {
    final system = state.topology?.system;
    if (system == null) return null;
    return ResetRequest.build(system, intent);
  }

  /// Asks the machine to change state, and waits to see whether it did.
  ///
  /// Never called by a test against real hardware — see the header of
  /// `test/bmc_power_test.dart`. What the caller must not skip is the
  /// confirmation: this is the one thing in the app that can take a running
  /// server away from whoever is using it.
  Future<BmcPowerResult> power(PowerIntent intent) async {
    final client = _client;
    final request = plan(intent);
    if (client == null || request == null) return BmcPowerResult.notSupported;

    final before = state.powerState;
    _powering = true;
    try {
      try {
        await client.post(request.target, request.body);
      } catch (e) {
        Loggers.app.warning('BMC ${request.resetType} refused', e);
        return BmcPowerResult.failed;
      }

      return await _awaitPowerChange(client, before, intent)
          ? BmcPowerResult.confirmed
          : BmcPowerResult.accepted;
    } finally {
      _powering = false;
    }
  }

  /// Where [intent] should leave the machine.
  ///
  /// `restart` and `powerCycle` end where they started, which is why the
  /// arrival test cannot be "the state differs from before": a machine that
  /// finishes rebooting between two polls is only ever seen `on`, and was
  /// reported as *accepted* — the weaker answer — for a restart that had in
  /// fact happened.
  static PowerState _expected(PowerIntent intent) => switch (intent) {
    PowerIntent.on || PowerIntent.restart || PowerIntent.powerCycle =>
      PowerState.on,
    PowerIntent.gracefulShutdown || PowerIntent.forceOff => PowerState.off,
  };

  /// Polls until the machine has both moved and arrived where [intent] means
  /// it to be.
  ///
  /// A transitional state does not count as arrival — `PoweringOff` is the
  /// machine on its way, and reporting that as done would be reporting the
  /// request back rather than the result — but it does count as having moved,
  /// which is the only evidence an operation ending where it began can leave.
  Future<bool> _awaitPowerChange(
    RedfishClient client,
    PowerState before,
    PowerIntent intent,
  ) async {
    final generation = _generation;
    final deadline = DateTime.now().add(_powerConfirmTimeout);
    // Whether the machine was ever seen anywhere other than where it started.
    // For an intent that ends where it began, this is the whole of the
    // evidence; for the others it is redundant with the state itself.
    var moved = before != _expected(intent);

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(_powerPollInterval);
      if (generation != _generation) return false;

      try {
        final system = RedfishSystem.fromJson(
          await client.get(state.topology!.systemPath!),
        );
        state = state.copyWith(topology: state.topology!.withSystem(system));
        final now = system.powerState;
        if (now.isTransitional) {
          // On its way. Seeing this is itself the evidence a restart needs,
          // since it will settle back where it started.
          moved = true;
          continue;
        }
        if (now != before) moved = true;
        if (moved && now == _expected(intent)) return true;
      } catch (e) {
        // A machine on its way down stops answering, which is itself not an
        // answer about whether it got there
        Loggers.app.info('BMC unreachable while confirming power change', e);
      }
    }
    return false;
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
