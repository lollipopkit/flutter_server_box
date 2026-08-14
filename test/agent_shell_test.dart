import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';

void main() {
  const margin = AgentShellGeometry.margin;
  const min = AgentShellGeometry.minSize;
  const desktop = Size(1440, 900);

  group('AgentShellMode.parse', () {
    test('reads back every name it writes', () {
      for (final mode in AgentShellMode.values) {
        expect(AgentShellMode.parse(mode.name), mode);
      }
    });

    test('falls back to hidden for anything else', () {
      expect(AgentShellMode.parse(null), AgentShellMode.hidden);
      expect(AgentShellMode.parse(''), AgentShellMode.hidden);
      expect(AgentShellMode.parse('minimised'), AgentShellMode.hidden);
    });
  });

  group('desktopRect', () {
    Rect rect({
      Size area = desktop,
      double topInset = 0,
      double bottomInset = 0,
      Offset? offset,
      Size size = const Size(400, 560),
      bool collapsed = false,
    }) {
      return AgentShellGeometry.desktopRect(
        area: area,
        topInset: topInset,
        bottomInset: bottomInset,
        offset: offset,
        size: size,
        collapsed: collapsed,
      );
    }

    test('an unplaced panel starts in the bottom-right corner', () {
      final result = rect();
      expect(result.right, desktop.width - margin);
      expect(result.bottom, desktop.height - margin);
    });

    test('a saved position is kept when it still fits', () {
      final result = rect(offset: const Offset(120, 80));
      expect(result.topLeft, const Offset(120, 80));
      expect(result.size, const Size(400, 560));
    });

    test('a position off the right edge is pulled back inside', () {
      final result = rect(offset: const Offset(5000, 40));
      expect(result.right, desktop.width - margin);
      expect(result.left, greaterThanOrEqualTo(margin));
    });

    test('a position above the safe area is pushed below it', () {
      final result = rect(topInset: 44, offset: const Offset(100, 0));
      expect(result.top, 44 + margin);
    });

    test('a panel restored from a larger monitor shrinks to fit', () {
      final result = rect(area: const Size(700, 500), size: const Size(1200, 900));
      expect(result.width, 700 - margin * 2);
      expect(result.height, 500 - margin * 2);
      expect(result.left, greaterThanOrEqualTo(margin));
      expect(result.top, greaterThanOrEqualTo(margin));
    });

    test('a window smaller than the minimum does not throw, and floors', () {
      // `clamp` throws when the upper bound falls below the lower one, which
      // is exactly what a window this size produces.
      final result = rect(area: const Size(120, 120));
      expect(result.width, min.width);
      expect(result.height, min.height);
      expect(result.left, margin);
      expect(result.top, margin);
    });

    test('collapsed is the bar height regardless of the stored size', () {
      final result = rect(size: const Size(400, 800), collapsed: true);
      expect(result.height, AgentShellGeometry.barHeight);
      expect(result.width, 400);
    });

    test('collapsing keeps the panel inside a short window', () {
      final result = rect(
        area: const Size(1440, 400),
        offset: const Offset(100, 380),
        collapsed: true,
      );
      expect(
        result.bottom,
        lessThanOrEqualTo(400 - margin),
      );
    });
  });

  group('sheetHeightFor', () {
    double height({
      double areaHeight = 800,
      double topInset = 47,
      double keyboardInset = 0,
      double fraction = 0.62,
    }) {
      return AgentShellGeometry.sheetHeightFor(
        areaHeight: areaHeight,
        topInset: topInset,
        keyboardInset: keyboardInset,
        fraction: fraction,
      );
    }

    test('is the requested fraction while there is room for it', () {
      expect(height(), closeTo(800 * 0.62, 0.001));
    });

    test('gives way to the keyboard rather than overflowing', () {
      final withKeyboard = height(keyboardInset: 400);
      expect(withKeyboard, lessThan(800 * 0.62));
      // Still below the top inset plus its own margins, so the panel never
      // reaches up under the status bar.
      expect(withKeyboard, lessThanOrEqualTo(800 - 400 - 47 - margin * 2));
    });

    test('keeps a usable floor when the keyboard leaves almost nothing', () {
      expect(height(keyboardInset: 780), 200);
    });
  });

  group('pill placement', () {
    test('0 is the top of the safe area and 1 the bottom', () {
      const area = 800.0;
      const pill = 52.0;
      final top = AgentShellGeometry.pillTopFor(
        areaHeight: area,
        topInset: 47,
        bottomInset: 34,
        y: 0,
        pillSize: pill,
      );
      final bottom = AgentShellGeometry.pillTopFor(
        areaHeight: area,
        topInset: 47,
        bottomInset: 34,
        y: 1,
        pillSize: pill,
      );
      expect(top, 47 + margin);
      expect(bottom + pill, area - 34 - margin);
    });

    test('a screen with no room reports no travel and does not divide by it', () {
      final travel = AgentShellGeometry.pillTravelFor(
        areaHeight: 60,
        topInset: 20,
        bottomInset: 20,
        pillSize: 52,
      );
      expect(travel, 0);
    });

    test('an out-of-range stored position is clamped, not extrapolated', () {
      final top = AgentShellGeometry.pillTopFor(
        areaHeight: 800,
        topInset: 0,
        bottomInset: 0,
        y: 4.2,
        pillSize: 52,
      );
      expect(top + 52, 800 - margin);
    });
  });
}
