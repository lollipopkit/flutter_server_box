import 'dart:async';
import 'dart:collection';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/src/rust/api/bmc.dart';

part 'summary.freezed.dart';
part 'summary.g.dart';

/// Poll interval for Status-tab card summaries. Longer than the detail page's
/// 1-minute cycle because many cards may share the grid.
const _summaryPollInterval = Duration(seconds: 90);

/// Global concurrency gate for list-level BMC polls.
///
/// BMCs are slow and expose small session tables; capping in-flight list polls
/// avoids saturating the device or starving interactive detail pages.
final class BmcPollBudget {
  BmcPollBudget({this.maxConcurrent = 2});

  static final shared = BmcPollBudget();

  final int maxConcurrent;
  var _active = 0;
  final _waiters = Queue<Completer<void>>();

  @visibleForTesting
  int get activeCount => _active;

  Future<T> run<T>(Future<T> Function() fn) async {
    if (_active >= maxConcurrent) {
      final gate = Completer<void>();
      _waiters.add(gate);
      await gate.future;
    } else {
      _active++;
    }
    try {
      return await fn();
    } finally {
      if (_waiters.isNotEmpty) {
        // Hand the active slot straight to the next waiter so no new caller
        // can sneak in between decrements and exceed [maxConcurrent].
        _waiters.removeFirst().complete();
      } else {
        _active--;
      }
    }
  }
}

@freezed
abstract class BmcSummaryState with _$BmcSummaryState {
  const factory BmcSummaryState({
    RedfishTopology? topology,
    double? watts,
    RedfishFailure? failure,
    String? failureDetail,
    @Default(false) bool isBusy,
    @Default(false) bool isPowering,
  }) = _BmcSummaryState;

  const BmcSummaryState._();

  PowerState get powerState =>
      topology?.system?.powerState ?? PowerState.unknown;

  bool get hasData => topology?.system != null;

  bool get needsCertReview =>
      failure == RedfishFailure.certificateRejected ||
      failure == RedfishFailure.certNotReviewed;
}

/// Lightweight list-card BMC poller.
///
/// Opens a short-lived [BmcClient] per poll (via [BmcPollBudget]) and closes
/// the Redfish session immediately afterwards, so a grid of cards never holds
/// open sessions on devices that allow only a handful.
@riverpod
class BmcSummaryNotifier extends _$BmcSummaryNotifier {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  var _generation = 0;
  var _refreshSeq = 0;
  int? _refreshingIn;
  var _powering = false;
  var _paused = false;
  String? _targetId;
  String? _addr;
  String? _certSha256;
  String? _user;
  String? _password;

  /// Optional test seam for injecting a fake summary read without FFI sockets.
  @visibleForTesting
  static Future<BmcSummary> Function(
    BmcTarget target,
    RedfishTopology? known,
  )?
  testReadSummary;

  /// Optional test seam for injecting a fake power action.
  @visibleForTesting
  static Future<BmcOutcome> Function(
    BmcTarget target,
    RedfishTopology topology,
    PowerIntent intent,
  )?
  testPower;

  @override
  BmcSummaryState build(String targetId) {
    _targetId = targetId;
    _addr = null;
    _certSha256 = null;
    _user = null;
    _password = null;
    _paused = false;
    final buildGen = _generation;

    ref.onDispose(() {
      _generation++;
      _refreshSeq++;
      _refreshingIn = null;
      _targetId = null;
      _addr = null;
      _certSha256 = null;
      _user = null;
      _password = null;
      _paused = false;
      _timer?.cancel();
      _timer = null;
      _lifecycle?.dispose();
      _lifecycle = null;
    });

    // Watch only connection fields so renaming, tagging, or linking/unlinking
    // never drops cached summary state or triggers an extra discovery poll.
    final endpoint = ref.watch(
      bmcTargetsProvider.select((s) {
        final t = s.targets[targetId];
        if (t == null) return null;
        return (
          addr: t.addr,
          credId: t.credId,
          certSha256: t.certSha256,
          incompleteFailure: t.incompleteFailure,
        );
      }),
    );
    if (endpoint == null) return const BmcSummaryState();
    if (endpoint.incompleteFailure case final failure?) {
      return BmcSummaryState(failure: failure);
    }

    final credId = endpoint.credId!;
    final cred = ref.watch(
      bmcCredentialProvider.select(
        (state) => state.creds.firstWhereOrNull((e) => e.id == credId),
      ),
    );
    if (cred == null || !cred.isComplete) {
      return const BmcSummaryState(failure: RedfishFailure.noCredential);
    }

    _addr = endpoint.addr;
    _certSha256 = endpoint.certSha256;
    _user = cred.user;
    _password = cred.pwd;

    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState == AppLifecycleState.paused ||
        binding.lifecycleState == AppLifecycleState.hidden) {
      _paused = true;
    }
    _lifecycle = AppLifecycleListener(
      onPause: () => _paused = true,
      onHide: () => _paused = true,
      onResume: () {
        if (_paused && ref.mounted && _generation == buildGen) {
          _paused = false;
          unawaited(refresh());
        }
      },
    );

    if (!_paused) {
      unawaited(
        Future.microtask(() {
          if (ref.mounted && _generation == buildGen) {
            return refresh();
          }
        }),
      );
    }
    _timer = Timer.periodic(_summaryPollInterval, (_) {
      if (!_paused && ref.mounted && _generation == buildGen) {
        unawaited(refresh());
      }
    });

    return BmcSummaryState(isBusy: !_paused, isPowering: _powering);
  }

  /// Runs one short-lived summary read through [BmcPollBudget].
  Future<void> refresh({bool force = false}) async {
    if (!ref.mounted) return;
    final targetId = _targetId;
    final addr = _addr;
    final user = _user;
    if (targetId == null || addr == null || user == null) return;
    if (!force && (_refreshingIn == _generation || _powering)) return;

    final generation = _generation;
    final seq = ++_refreshSeq;
    _refreshingIn = generation;
    if (!state.isBusy) state = state.copyWith(isBusy: true);

    try {
      final result = await BmcPollBudget.shared.run(() async {
        if (!ref.mounted ||
            generation != _generation ||
            seq != _refreshSeq ||
            (!force && _paused)) {
          return null;
        }
        if (testReadSummary case final hook?) {
          final target =
              ref.read(bmcTargetsProvider).targets[targetId] ??
              BmcTarget(
                id: targetId,
                name: targetId,
                addr: addr,
                certSha256: _certSha256,
              );
          return await hook(target, state.topology);
        }
        final client = BmcClient(
          baseUrl: addr,
          user: user,
          password: _password,
          pinnedSha256: _certSha256,
        );
        try {
          return await client.summary(known: state.topology);
        } finally {
          try {
            await client.close();
          } finally {
            client.dispose();
          }
        }
      });
      if (result == null) {
        if (ref.mounted &&
            generation == _generation &&
            seq == _refreshSeq &&
            !force &&
            _paused &&
            state.isBusy) {
          state = state.copyWith(isBusy: false);
        }
        return;
      }
      if (!ref.mounted || generation != _generation || seq != _refreshSeq) {
        return;
      }

      state = state.copyWith(
        topology: result.topology,
        watts: result.watts,
        failure: null,
        failureDetail: null,
        isBusy: false,
      );
    } on BmcError catch (e) {
      if (!ref.mounted || generation != _generation || seq != _refreshSeq) {
        return;
      }
      state = state.copyWith(
        failure: e.failure,
        failureDetail: e.detail,
        isBusy: false,
      );
    } catch (e) {
      if (!ref.mounted || generation != _generation || seq != _refreshSeq) {
        return;
      }
      state = state.copyWith(
        failure: RedfishFailure.unreachable,
        failureDetail: '$e',
        isBusy: false,
      );
    } finally {
      if (_refreshingIn == generation && seq == _refreshSeq) {
        _refreshingIn = null;
      }
    }
  }

  /// Sends a power action (e.g. quick Power On from a card) over a short-lived
  /// client, then triggers a summary refresh.
  Future<BmcPowerResult> power(PowerIntent intent) async {
    if (!ref.mounted) return BmcPowerResult.failed;
    final targetId = _targetId;
    final addr = _addr;
    final user = _user;
    final topology = state.topology;
    if (targetId == null ||
        addr == null ||
        user == null ||
        topology == null ||
        _powering) {
      return BmcPowerResult.failed;
    }

    final system = topology.system;
    if (testPower == null &&
        (system == null || bmcPlan(system: system, intent: intent) == null)) {
      return BmcPowerResult.notSupported;
    }

    final generation = _generation;
    _powering = true;
    state = state.copyWith(isPowering: true);
    try {
      if (testPower case final hook?) {
        final target =
            ref.read(bmcTargetsProvider).targets[targetId] ??
            BmcTarget(
              id: targetId,
              name: targetId,
              addr: addr,
              certSha256: _certSha256,
            );
        await hook(target, topology, intent);
      } else {
        final client = BmcClient(
          baseUrl: addr,
          user: user,
          password: _password,
          pinnedSha256: _certSha256,
        );
        try {
          await client.power(topology: topology, intent: intent);
        } finally {
          try {
            await client.close();
          } finally {
            client.dispose();
          }
        }
      }
      return BmcPowerResult.accepted;
    } on BmcError catch (e) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(failure: e.failure, failureDetail: e.detail);
      }
      return e.failure == RedfishFailure.notSupported
          ? BmcPowerResult.notSupported
          : BmcPowerResult.failed;
    } catch (_) {
      return BmcPowerResult.failed;
    } finally {
      _powering = false;
      if (ref.mounted) {
        state = state.copyWith(isPowering: false);
        if (generation == _generation) {
          unawaited(refresh(force: true));
        } else if (!_paused && state.isBusy) {
          // A rebuild during power() skipped its initial refresh while
          // `_powering` was true.
          unawaited(refresh());
        }
      }
    }
  }
}
