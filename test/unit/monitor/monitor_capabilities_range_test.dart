import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';

/// What a client may ask an agent for is the agent's to say.
///
/// Two answers, and the app needs both: retention is the policy — what will
/// not be deleted — and the oldest sample is what was actually collected. An
/// agent started yesterday under a 90-day policy has a day, and offering "30
/// days" against it draws an empty chart and calls it a quiet machine.
void main() {
  MonitorCapabilities caps(Map<String, dynamic> json) =>
      MonitorCapabilities.fromJson({
        'remote_access': <String, dynamic>{},
        ...json,
      });

  test('retention arrives as a duration', () {
    expect(caps({'retention_days': 9}).retention, const Duration(days: 9));
  });

  test('an agent too old to say is not read as keeping nothing', () {
    final it = caps({});

    expect(it.retention, isNull);
    expect(it.oldestSample, isNull);
    expect(
      it.historyFrom,
      isNull,
      reason: 'no answer is not the same as "nothing before now"',
    );
  });

  test('a retention of zero is no answer, not an empty store', () {
    expect(caps({'retention_days': 0}).retention, isNull);
  });

  test('the reachable window is the later of the two bounds', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // Kept for 90 days, collected for one: a day is what can be asked for.
    final young = caps({
      'retention_days': 90,
      'oldest_sample': yesterday.toUtc().toIso8601String(),
    });
    expect(young.historyFrom, isNotNull);
    expect(
      young.historyFrom!.difference(yesterday).inMinutes.abs(),
      lessThan(2),
    );

    // Collected for a year, kept for three days: three days.
    final trimmed = caps({
      'retention_days': 3,
      'oldest_sample': now
          .subtract(const Duration(days: 365))
          .toUtc()
          .toIso8601String(),
    });
    // In hours, because the bound is taken from the clock at the moment it is
    // asked for and lands a hair short of three whole days.
    expect(
      now.difference(trimmed.historyFrom!).inHours,
      closeTo(72, 1),
      reason: 'rows older than the policy are gone whatever the oldest row says',
    );
  });

  test('an unparseable instant is dropped rather than guessed at', () {
    expect(caps({'oldest_sample': 'whenever'}).oldestSample, isNull);
  });
}
