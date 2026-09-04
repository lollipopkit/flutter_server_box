/// A point on the globe, in degrees.
///
/// There is no public constructor. Every way in validates, so a value outside
/// latitude [-90, 90] or longitude [-180, 180] — or one that is NaN — cannot
/// exist. That is worth the ceremony because the values arrive from places
/// that do not check each other: a text field, a backup written by another
/// install, and later a lookup answered over the network.
///
/// Deliberately one object rather than two nullable doubles on whatever holds
/// it. Half a coordinate is not a place, and a pair of nullable fields makes
/// that state representable in two of its four combinations — with nothing to
/// say which of the two columns the reader should believe.
final class GeoCoord {
  /// Degrees north, in [-90, 90].
  final double lat;

  /// Degrees east, in [-180, 180].
  final double lon;

  const GeoCoord._(this.lat, this.lon);

  /// Null unless both values are present and in range.
  ///
  /// The arguments are nullable because both callers — a row with two columns,
  /// and a parse of two strings — have to answer "one of them is missing"
  /// anyway. Doing it here is one check rather than one per caller.
  ///
  /// The NaN test is not redundant with the range test below it: every
  /// comparison against NaN is false, so a NaN passes a range check.
  static GeoCoord? tryNew(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    if (lat.isNaN || lon.isNaN) return null;
    if (lat < -90 || lat > 90) return null;
    if (lon < -180 || lon > 180) return null;
    return GeoCoord._(lat, lon);
  }

  /// Reads `lat, lon` — the form a coordinate is copied out of a map in.
  ///
  /// Separated by a comma, whitespace, or both, since what gets pasted differs
  /// by where it was copied from. Null for anything else, and for a pair that
  /// parses but is out of range.
  static GeoCoord? tryParse(String text) {
    final parts = text.trim().split(RegExp(r'[,\s]+'));
    if (parts.length != 2) return null;
    return tryNew(double.tryParse(parts[0]), double.tryParse(parts[1]));
  }

  /// What [tryParse] reads back, and what the editor puts in its field.
  String get text => '$lat, $lon';

  Map<String, double> toJson() => {'lat': lat, 'lon': lon};

  /// For `@JsonKey(toJson:)`, which hands over the field including its null.
  static Map<String, double>? encode(GeoCoord? geo) => geo?.toJson();

  /// Anything unreadable becomes no coordinate rather than an error.
  ///
  /// This is the restore path. A backup carrying a value this build would
  /// refuse must cost the user the coordinate, not the server it is attached
  /// to — so nothing here throws, including on a type that was never a number.
  static GeoCoord? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'];
    final lon = json['lon'];
    return tryNew(
      lat is num ? lat.toDouble() : null,
      lon is num ? lon.toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GeoCoord && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoCoord($text)';
}
