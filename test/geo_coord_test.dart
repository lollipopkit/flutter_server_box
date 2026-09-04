import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/geo.dart';

/// The type exists to make an invalid coordinate unrepresentable, so what is
/// worth testing is every way one could get in.
void main() {
  group('tryNew', () {
    test('accepts a point, and the poles and the antimeridian', () {
      expect(GeoCoord.tryNew(39.9042, 116.4074)?.lat, 39.9042);
      expect(GeoCoord.tryNew(39.9042, 116.4074)?.lon, 116.4074);
      for (final pair in const [
        (90.0, 180.0),
        (-90.0, -180.0),
        (0.0, 0.0),
      ]) {
        expect(
          GeoCoord.tryNew(pair.$1, pair.$2),
          isNotNull,
          reason: '$pair is a real place',
        );
      }
    });

    test('refuses half a coordinate', () {
      expect(GeoCoord.tryNew(39.9042, null), isNull);
      expect(GeoCoord.tryNew(null, 116.4074), isNull);
      expect(GeoCoord.tryNew(null, null), isNull);
    });

    test('refuses a value off the globe', () {
      expect(GeoCoord.tryNew(90.1, 0), isNull);
      expect(GeoCoord.tryNew(-90.1, 0), isNull);
      expect(GeoCoord.tryNew(0, 180.1), isNull);
      expect(GeoCoord.tryNew(0, -180.1), isNull);
    });

    test('refuses NaN and infinity', () {
      // Not covered by the range test above it: every comparison against NaN
      // is false, so a NaN passes a range check and would be drawn nowhere at
      // all. Infinity does fail the range test; it is here so that stays true.
      expect(GeoCoord.tryNew(double.nan, 0), isNull);
      expect(GeoCoord.tryNew(0, double.nan), isNull);
      expect(GeoCoord.tryNew(double.infinity, 0), isNull);
      expect(GeoCoord.tryNew(0, double.negativeInfinity), isNull);
    });
  });

  group('tryParse', () {
    test('reads what a map copies out', () {
      for (final text in const [
        '39.9042, 116.4074',
        '39.9042,116.4074',
        '39.9042 116.4074',
        '  39.9042 ,  116.4074  ',
      ]) {
        expect(
          GeoCoord.tryParse(text),
          GeoCoord.tryNew(39.9042, 116.4074),
          reason: text,
        );
      }
    });

    test('reads a southern, western point', () {
      expect(GeoCoord.tryParse('-33.8688, 151.2093')?.lat, -33.8688);
      expect(GeoCoord.tryParse('-22.9068, -43.1729')?.lon, -43.1729);
    });

    test('refuses anything that is not two numbers', () {
      for (final text in const [
        '',
        '   ',
        '39.9042',
        '39.9042, 116.4074, 44',
        '39.9042, east',
        'somewhere',
        // Degrees and minutes, which is a form maps also offer. Refused rather
        // than half-read as 39: saving 39 for 39°54' is a wrong answer, and a
        // wrong answer here is silent.
        "39°54'15\"N 116°24'26\"E",
      ]) {
        expect(GeoCoord.tryParse(text), isNull, reason: '"$text"');
      }
    });

    test('refuses a pair that parses but is off the globe', () {
      expect(GeoCoord.tryParse('116.4074, 39.9042'), isNull);
    });

    test('round-trips through the text the editor shows', () {
      final coord = GeoCoord.tryNew(39.9042, -116.4074)!;
      expect(GeoCoord.tryParse(coord.text), coord);
    });
  });

  group('JSON, which is the backup', () {
    test('round-trips', () {
      final coord = GeoCoord.tryNew(51.5072, -0.1276)!;
      expect(GeoCoord.tryFromJson(coord.toJson()), coord);
    });

    test('reads an integer, since JSON has one number type', () {
      // `{"lat": 51, "lon": 0}` is what a whole degree encodes to, and it
      // decodes as an int rather than a double.
      expect(GeoCoord.tryFromJson({'lat': 51, 'lon': 0}), isNotNull);
    });

    test('an unreadable value costs the coordinate, not the server', () {
      // Nothing here throws. `ServerCustom.fromJson` runs this during a
      // restore, so an exception would fail the whole record over a field
      // nothing else reads.
      for (final json in const <Object?>[
        null,
        'somewhere',
        <String, Object?>{},
        {'lat': 51.5072},
        {'lat': '51.5072', 'lon': '-0.1276'},
        {'lat': 951.5072, 'lon': -0.1276},
        {'latitude': 51.5072, 'longitude': -0.1276},
      ]) {
        expect(GeoCoord.tryFromJson(json), isNull, reason: '$json');
      }
    });

    test('encode passes a null through', () {
      expect(GeoCoord.encode(null), isNull);
      expect(GeoCoord.encode(GeoCoord.tryNew(1, 2)), {'lat': 1.0, 'lon': 2.0});
    });
  });

  test('reads as itself in a log line', () {
    // `text` is the user-facing form and `toString` is the debug one; the
    // second carries the type so a coordinate in a log is not mistaken for
    // some other pair of numbers.
    final coord = GeoCoord.tryNew(39.9042, 116.4074)!;
    expect(coord.text, '39.9042, 116.4074');
    expect(coord.toString(), 'GeoCoord(39.9042, 116.4074)');
  });

  test('equality is by value, so a save can tell nothing changed', () {
    expect(GeoCoord.tryNew(1, 2), GeoCoord.tryNew(1, 2));
    expect(GeoCoord.tryNew(1, 2)?.hashCode, GeoCoord.tryNew(1, 2)?.hashCode);
    expect(GeoCoord.tryNew(1, 2), isNot(GeoCoord.tryNew(2, 1)));
  });
}
