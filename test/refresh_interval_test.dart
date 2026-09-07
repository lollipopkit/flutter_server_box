import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/res/default.dart';

void main() {
  group('normalizeServerStatusRefreshSeconds', () {
    test('keeps manual refresh disabled', () {
      expect(normalizeServerStatusRefreshSeconds(0), isNull);
    });

    test('keeps valid automatic refresh values', () {
      expect(normalizeServerStatusRefreshSeconds(2), 2);
      expect(normalizeServerStatusRefreshSeconds(10), 10);
    });

    test('falls back for invalid automatic refresh values', () {
      expect(normalizeServerStatusRefreshSeconds(1), Defaults.updateInterval);
      expect(normalizeServerStatusRefreshSeconds(-1), Defaults.updateInterval);
      expect(normalizeServerStatusRefreshSeconds(11), Defaults.updateInterval);
    });
  });

  group('effectiveCustomCmdSeconds', () {
    // The commands run on a status poll and nowhere else, so the interval that
    // takes effect is the requested one rounded *up* to a whole number of poll
    // intervals. Rounding down would run them more often than asked, which is
    // the direction that costs something on the far side.
    test('rounds up to a whole number of poll intervals', () {
      expect(effectiveCustomCmdSeconds(requested: 7, poll: 3), 9);
      expect(effectiveCustomCmdSeconds(requested: 30, poll: 3), 30);
      expect(effectiveCustomCmdSeconds(requested: 30, poll: 4), 32);
      expect(effectiveCustomCmdSeconds(requested: 1, poll: 3), 3);
      expect(effectiveCustomCmdSeconds(requested: 3, poll: 3), 3);
    });

    // Never less than one poll: there is no moment in between to run them at.
    test('never comes out below one poll', () {
      for (var requested = 1; requested <= 10; requested++) {
        final effective = effectiveCustomCmdSeconds(
          requested: requested,
          poll: 10,
        );
        expect(effective, 10, reason: 'requested $requested');
      }
    });

    // Zero is how a user asks for the behaviour this replaced — every poll.
    // It is one poll, not "no interval": the settings page reports the number
    // and saying nothing there would be wrong rather than merely vague.
    test('zero is one poll', () {
      expect(effectiveCustomCmdSeconds(requested: 0, poll: 3), 3);
      expect(effectiveCustomCmdSeconds(requested: -5, poll: 3), 3);
    });

    // Manual status polling is the only case with no interval to align to.
    test('says nothing when the status poll is manual', () {
      expect(effectiveCustomCmdSeconds(requested: 30, poll: null), isNull);
      expect(effectiveCustomCmdSeconds(requested: 0, poll: null), isNull);
      // A poll interval of 0 never reaches here — `normalize` answers null for
      // it — but answering "every refresh" is the only sane reading of it.
      expect(effectiveCustomCmdSeconds(requested: 30, poll: 0), isNull);
    });
  });
}
