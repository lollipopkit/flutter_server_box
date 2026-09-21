import 'dart:ui';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/color/oklch.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/chart_series.dart';

/// The chart palette, against the values the design published.
///
/// A derived palette fails quietly: every seed still yields six colours, and
/// two of them being indistinguishable is not something any other test would
/// notice. So this is two things — the arithmetic, pinned to the worked
/// example, and the rules the arithmetic exists to satisfy, checked against
/// every seed the app offers rather than against the one it ships with.
void main() {
  /// The app's own default — `SettingStore.colorSeed`, and the design's
  /// "ServerBox 默认 · Pink 900".
  const seed = Color(0xFF880E4F);

  /// The seeds the design checked its rules against, which are the ones a
  /// user is most likely to pick: a blue, a green, an orange, a purple, and
  /// one with almost no colour in it at all.
  const seeds = <Color>[
    Color(0xFF880E4F),
    Color(0xFF4353FF),
    Color(0xFF3AA655),
    Color(0xFFE08D19),
    Color(0xFF7A52C0),
    Color(0xFF4A4A52),
  ];

  List<String> hexOf(SeriesPalette p) =>
      [for (final c in p.all) c.toHexRGB.toLowerCase()];

  group('the worked example', () {
    test('a dark theme from the default seed is the design\'s six', () {
      expect(hexOf(SeriesPalette.fan(seed, dark: true)), [
        '#fda6c7', // CPU — the theme colour itself, at L 0.82
        '#a57451', // Memory
        '#9ca56b', // Disk read
        '#46907e', // Disk write
        '#6ca7c9', // Net ↓
        '#8477ab', // Net ↑
      ]);
    });

    test('and a light theme is the same six hues, two steps darker', () {
      final dark = SeriesPalette.fan(seed, dark: true);
      final light = SeriesPalette.fan(seed, dark: false);

      expect(hexOf(light), [
        '#b53872',
        '#964d01',
        '#899532',
        '#007461',
        '#2c97cc',
        '#6a52a0',
      ]);

      // The point of the pair: one machine means the same thing in either
      // theme, so only the light changes.
      for (var i = 0; i < ChartSeries.values.length; i++) {
        expect(
          hueDistance(Oklch.of(dark.all[i]).h, Oklch.of(light.all[i]).h),
          lessThan(4),
          reason: '${ChartSeries.values[i]} changed hue between themes',
        );
        expect(
          relativeLuminance(light.all[i]),
          lessThan(relativeLuminance(dark.all[i])),
        );
      }
    });

    test('the anchor keeps the seed\'s hue and takes the theme\'s light', () {
      final anchor = Oklch.of(SeriesPalette.fan(seed, dark: true).cpu);
      expect(anchor.h, closeTo(Oklch.of(seed).h, 1));
      expect(anchor.l, closeTo(0.82, 0.01));
      // Asked for 0.16 × 1.15, capped at 0.17, and what fits at that lightness
      // is 0.11.
      expect(anchor.c, closeTo(0.11, 0.01));
    });
  });

  group('the rules, for every seed', () {
    /// The pairs that are read together: an overlaid chart draws CPU over
    /// memory, and read↔write and ↓↔↑ are each one row. The last is the two
    /// that most often share a card.
    const pairs = [
      (ChartSeries.cpu, ChartSeries.mem),
      (ChartSeries.diskRead, ChartSeries.diskWrite),
      (ChartSeries.netRx, ChartSeries.netTx),
      (ChartSeries.cpu, ChartSeries.diskRead),
    ];

    for (final dark in [true, false]) {
      final theme = dark ? 'dark' : 'light';

      test('a pair differs by hue or by light — $theme', () {
        for (final seed in seeds) {
          final p = SeriesPalette.fan(seed, dark: dark);
          for (final (a, b) in pairs) {
            // Hue as built, light as it comes out. Fitting to the gamut and
            // rounding to eight bits move a hue by up to a degree — a blue
            // seed's read↔write pair measures 58.9° — and that is the fit
            // doing its job rather than the palette breaking its own rule.
            // Light does not drift: it is read off the colours themselves.
            final hue = hueDistance(p.hueOf(a), p.hueOf(b));
            final light = contrastRatio(p.of(a), p.of(b));
            expect(
              hue >= 60 || light >= 1.5,
              isTrue,
              reason:
                  '$a and $b are ${hue.toStringAsFixed(1)}° apart and '
                  '${light.toStringAsFixed(2)}× in light, from '
                  '${seed.toHexRGB} on $theme',
            );
          }
          // And whatever the numbers say, no two of the six are the same
          // colour — which is what a fit collapsing two hues would look like.
          expect(p.all.toSet(), hasLength(ChartSeries.values.length));
        }
      });

      test('no series out-saturates the theme colour — $theme', () {
        for (final seed in seeds) {
          final p = SeriesPalette.fan(seed, dark: dark);
          final lead = Oklch.of(p.cpu).c;
          for (final series in ChartSeries.values.skip(1)) {
            expect(
              Oklch.of(p.of(series)).c,
              lessThanOrEqualTo(lead + 0.005),
              reason: '$series is more colourful than the accent',
            );
          }
        }
      });

      test('a near-grey seed still yields six colours — $theme', () {
        // The floor's whole job. Without it the anchor's chroma is the seed's,
        // which is almost zero, and 72% of almost zero is six greys.
        final p = SeriesPalette.fan(const Color(0xFF4A4A52), dark: dark);
        for (final c in p.all) {
          expect(Oklch.of(c).c, greaterThan(0.04));
        }
      });

      test('every series is a colour a screen can show — $theme', () {
        for (final seed in seeds) {
          for (final c in SeriesPalette.fan(seed, dark: dark).all) {
            // Fitting a colour that is already inside the gamut leaves it
            // alone, so this says the palette never handed over a request the
            // screen had to clip.
            final back = Oklch.of(c);
            expect(back.fitted.c, back.c, reason: '${c.toHexRGB} is clipped');
            expect(back.c, lessThanOrEqualTo(0.175));
          }
        }
      });
    }
  });

  group('the palette the app reads', () {
    tearDown(() => ChartPalette.resolve(seed, dark: true));

    test('the six move with the seed and with the theme', () {
      ChartPalette.resolve(seed, dark: true);
      final wasCpu = ChartPalette.cpu;
      final wasAccent = ChartPalette.accent;

      ChartPalette.resolve(const Color(0xFF3AA655), dark: true);
      expect(ChartPalette.cpu, isNot(wasCpu));
      expect(ChartPalette.accent, isNot(wasAccent));

      // And back, since the same two answers must come from the same two
      // inputs — this is a cache as much as it is a computation.
      ChartPalette.resolve(seed, dark: true);
      expect(ChartPalette.cpu, wasCpu);
      expect(ChartPalette.accent, wasAccent);

      ChartPalette.resolve(seed, dark: false);
      expect(ChartPalette.cpu, isNot(wasCpu));
    });

    test('a reading is drawn in the theme colour', () {
      // Every reading, not only the one a card is watching. The rest were a
      // tint barely off grey on a hue 100° from the theme's: olive under a
      // pink theme, beside cards whose own icons were pink.
      for (final seed in seeds) {
        for (final dark in [true, false]) {
          ChartPalette.resolve(seed, dark: dark);
          final accent = Oklch.of(ChartPalette.accent);
          expect(hueDistance(accent.h, Oklch.of(seed).h), lessThan(4));
          // In colour, by as much as this lightness has room for at this
          // hue: some have 0.086 where the default seed has 0.11.
          expect(accent.c, greaterThan(0.07));
          // One colour, not two near ones: a line in this and a stretch of
          // the bar over the list in the CPU's are the same thing.
          expect(ChartPalette.accent, ChartPalette.cpu);
        }
      }
    });

    test('the lines of a chart start at the theme colour and stay apart', () {
      // They were six colours fixed at build time, two of them the red and
      // the amber a failure and a warning are drawn in. Whatever the seed:
      // the first is the accent, the second is across the wheel from it, and
      // no two that are not apart by hue are as light as each other.
      for (final seed in seeds) {
        for (final dark in [true, false]) {
          ChartPalette.resolve(seed, dark: dark);
          final lines = ChartPalette.lines;
          expect(lines, hasLength(6));
          expect(lines.toSet(), hasLength(6));
          expect(lines.first, ChartPalette.accent);

          final hues = [
            for (final line in lines)
              ChartPalette.series.hueOf(
                ChartSeries.values[ChartPalette.series.all.indexOf(line)],
              ),
          ];
          expect(hueDistance(hues[0], hues[1]), closeTo(180, 0.5));
          for (var a = 0; a < lines.length; a++) {
            for (var b = a + 1; b < lines.length; b++) {
              expect(
                hueDistance(hues[a], hues[b]),
                greaterThanOrEqualTo(59.5),
                reason: '$seed $dark: $a vs $b',
              );
            }
          }
        }
      }
    });
  });

  group('oklch', () {
    test('a colour survives the round trip', () {
      for (final seed in seeds) {
        expect(Oklch.of(seed).color, seed);
      }
    });

    test('fitting only ever takes chroma away', () {
      // Well outside sRGB at this lightness.
      const asked = Oklch(0.9, 0.3, 140);
      final got = asked.fitted;
      expect(got.c, lessThan(asked.c));
      expect(got.l, asked.l);
      expect(got.h, asked.h);
    });

    test('and leaves a colour already inside it alone', () {
      const asked = Oklch(0.6, 0.05, 140);
      expect(asked.fitted.c, asked.c);
    });
  });
}
