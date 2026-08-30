import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/service/analytics.dart';

/// Which variant of an experiment this install is in.
///
/// **Read through [isEnabled], which answers the local default unless an
/// experiment is actually running and this install is actually in it.** That
/// is the shape every call site has to be written for, because it is what all
/// but a fraction of installs will get: flags are only fetched at `full`, and
/// `full` is neither the default nor the recommendation.
///
/// **The population is not a sample, and no result from here is about "users"
/// in general.** Everyone measured chose `full` on the intro page — a group
/// that opted into continuous collection, which is not how most people answer.
/// An experiment here says what happens among people who said yes to that, and
/// generalising it to everyone else is the mistake this paragraph exists to
/// prevent. It is still worth running: a strong effect in a self-selected
/// group is a reason to look, just never a number to quote.
///
/// **A flag must never gate something a user paid attention to.** Nothing here
/// decides whether a feature exists, whether data is written, or how a server
/// is reached. What it is for is which of two wordings, orderings or defaults
/// a new screen uses — decisions whose wrong answer is a worse screen, not a
/// broken app. The reason is not caution about the network: it is that an
/// install with collection off never asks, so anything gated here is already
/// absent for most of the userbase.
abstract final class FeatureFlags {
  /// What the server said, empty until a fetch succeeds.
  ///
  /// Not persisted. A cached assignment would have to survive [Analytics.stop]
  /// deleting the identity that produced it, which would mean a variant
  /// outliving the consent it was assigned under.
  static final _flags = <String, Object>{};

  static bool _fetched = false;

  /// Whether an answer has been received this run.
  ///
  /// Exposed so a caller can tell "the control variant" from "no experiment
  /// running", which read the same through [isEnabled] and mean different
  /// things when a result is being interpreted.
  static bool get fetched => _fetched;

  /// Asks the server which variants this install is in.
  ///
  /// Once per run, at startup, and never retried: a flag arriving after the
  /// screen it applies to has been built would change that screen under the
  /// user, which is worse than the default they already got. Failure is
  /// silent and total — every flag then answers its local default.
  static Future<void> fetch() async {
    if (!Analytics.started) return;
    final id = Analytics.distinctId;
    if (id == null) return;
    try {
      final res = await Dio(
        BaseOptions(
          baseUrl: Analytics.host,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      ).post<Map<String, dynamic>>(
        '/decide/?v=3',
        data: {'api_key': Analytics.key, 'distinct_id': id},
      );
      final flags = res.data?['featureFlags'];
      if (flags is Map) {
        _flags
          ..clear()
          ..addAll(flags.map((k, v) => MapEntry('$k', v as Object)));
        _fetched = true;
      }
    } catch (e) {
      // Not through `Diag`: a device that is offline would otherwise report
      // being unable to ask about experiments, on every launch, forever.
      Loggers.app.warning('FeatureFlags.fetch: $e');
    }
  }

  /// Forgets everything. Called when collection stops, so a variant does not
  /// outlive the consent under which it was assigned.
  static void clear() {
    _flags.clear();
    _fetched = false;
  }

  /// Whether [key] is on for this install.
  ///
  /// [fallback] is the answer for every install that is not in an experiment,
  /// which is most of them — so it is the real default of whatever it gates,
  /// and the variant is the exception. A `true` fallback with a flag that
  /// turns something *off* reads the wrong way round at the call site and is
  /// worth avoiding for that reason alone.
  static bool isEnabled(String key, {bool fallback = false}) {
    final value = _flags[key];
    if (value is bool) return value;
    // A multivariate flag answers with the variant's name. Present at all
    // means assigned to something other than control.
    if (value is String) return value != 'control';
    return fallback;
  }

  /// Which variant of a multivariate experiment, or null when this install is
  /// not in one.
  static String? variant(String key) {
    final value = _flags[key];
    return value is String ? value : null;
  }
}
