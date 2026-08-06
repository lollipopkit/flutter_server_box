/// No-op stub of flutter_displaymode for HarmonyOS port.
class FlutterDisplayMode {
  static Future<DisplayMode?> get supportedModes async => null;
  static Future<void> setPreferredMode(DisplayMode mode) async {}
  static Future<void> setHighRefreshRate() async {}
}

class DisplayMode {
  final int width;
  final int height;
  final int refreshRate;

  const DisplayMode({
    required this.width,
    required this.height,
    required this.refreshRate,
  });

  @override
  String toString() =>
      'DisplayMode(${width}x${height}@$refreshRate Hz)';
}
