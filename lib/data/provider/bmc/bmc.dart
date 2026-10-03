import 'dart:async';

// `select` is an extension on ProviderListenable, which riverpod_annotation
// does not re-export.
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/bmc.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/src/rust/api/bmc.dart';

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
    @Default(BmcSensors(temperatures: [], fans: [])) BmcSensors sensors,
    RedfishFailure? failure,
    String? failureDetail,
    @Default(false) bool isBusy,

    /// Set when the sensor list was cut to `sbm_redfish::MAX_SENSOR_MEMBERS`.
    @Default(false) bool sensorsTruncated,
  }) = _BmcState;

  const BmcState._();

  /// What the machine's power is doing, or unknown before the first answer.
  PowerState get powerState =>
      topology?.system?.powerState ?? PowerState.unknown;

  /// Whether there is anything to show.
  bool get hasData => topology?.system != null;
}

/// One server's BMC.
///
/// Holds a [BmcClient] (`sbm_redfish` over FFI), and therefore a session on a
/// device that allows few of them — so the client is closed on dispose, which
/// is the only thing that gives the session back. See `docs/principles/bmc.md`.
@riverpod
class BmcNotifier extends _$BmcNotifier {
  BmcClient? _client;
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
      // nobody ends stays on the BMC until it times out. The native handle is
      // released once the session is given back.
      final client = _client;
      _client = null;
      if (client != null) {
        unawaited(client.close().whenComplete(client.dispose));
      }
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

    // Plain values, not this app's records: the client is `sbm_redfish` and
    // knows nothing about how anything here is stored. Without a pin every
    // handshake is refused as `certificateRejected`, which the editor answers
    // by offering the certificate for review.
    try {
      _client = BmcClient(
        baseUrl: cfg.addr,
        user: cred.user,
        password: cred.pwd,
        pinnedSha256: cfg.certSha256,
      );
    } on BmcError catch (e) {
      return BmcState(failure: e.failure, failureDetail: e.detail);
    }
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
      final snapshot = await client.snapshot(known: state.topology);
      if (generation != _generation) return;
      if (snapshot.sensorsTruncated) {
        Loggers.app.info('BMC sensors truncated to the first 64 members');
      }

      state = state.copyWith(
        topology: snapshot.topology,
        sensors: snapshot.sensors,
        sensorsTruncated: snapshot.sensorsTruncated,
        failure: null,
        failureDetail: null,
        isBusy: false,
      );
    } on BmcError catch (e) {
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
    return bmcPlan(system: system, intent: intent);
  }

  /// Asks the machine to change state, and waits to see whether it did.
  ///
  /// Never called by a test against real hardware. What the caller must not skip is the
  /// confirmation: this is the one thing in the app that can take a running
  /// server away from whoever is using it.
  Future<BmcPowerResult> power(PowerIntent intent) async {
    final client = _client;
    final topology = state.topology;
    final request = plan(intent);
    if (client == null || topology == null || request == null) {
      return BmcPowerResult.notSupported;
    }

    final before = state.powerState;
    _powering = true;
    try {
      // The intent, never the controller's address or its credentials. This is
      // the one feature that acts on hardware rather than on an OS, so which
      // of the intents people actually reach for is what says whether the set
      // is the right one.
      Diag.crumb(SbDiag.bmc, 'power', data: {'intent': intent.name});
      try {
        await client.power(topology: topology, intent: intent);
      } catch (e) {
        final error = e is BmcError ? e.message : e;
        Diag.crumb(
          SbDiag.bmc,
          'power failed',
          level: DiagLevel.warning,
          data: {'intent': intent.name, 'error': Redact.error(error)},
        );
        Loggers.app.warning('BMC ${request.resetType} refused', error);
        return e is BmcError && e.failure == RedfishFailure.notSupported
            ? BmcPowerResult.notSupported
            : BmcPowerResult.failed;
      }

      // `accepted` and `confirmed` are told apart because they are different
      // answers: the controller took the request either way, but only one of
      // them was watched reaching the state it asked for.
      final confirmed = await _awaitPowerChange(client, before, intent);
      Diag.crumb(
        SbDiag.bmc,
        confirmed ? 'power confirmed' : 'power accepted',
        data: {'intent': intent.name},
      );
      return confirmed ? BmcPowerResult.confirmed : BmcPowerResult.accepted;
    } finally {
      _powering = false;
    }
  }

  /// Polls until [PowerWatch] says the machine has both moved and arrived
  /// where [intent] means it to be.
  ///
  /// The clock is here and the decision is in Rust: a transitional state is
  /// the machine on its way, not arrival, and a restart that finishes between
  /// two polls is only ever seen `on` — see `sbm_redfish::model::PowerWatch`.
  Future<bool> _awaitPowerChange(
    BmcClient client,
    PowerState before,
    PowerIntent intent,
  ) async {
    final generation = _generation;
    final deadline = DateTime.now().add(_powerConfirmTimeout);
    final watch = PowerWatch(before: before, intent: intent);
    try {
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(_powerPollInterval);
        if (generation != _generation) return false;
        final topology = state.topology;
        if (topology == null) return false;

        try {
          final system = await client.readSystem(topology: topology);
          if (generation != _generation) return false;
          state = state.copyWith(topology: topology.withSystem(system));
          if (watch.observe(now: system.powerState)) return true;
        } catch (e) {
          // A machine on its way down stops answering, which is itself not an
          // answer about whether it got there
          Loggers.app.info(
            'BMC unreachable while confirming power change',
            e is BmcError ? e.message : e,
          );
        }
      }
      return false;
    } finally {
      watch.dispose();
    }
  }
}
