/// No-op stub of wakelock_plus for HarmonyOS (keep-screen-on not supported yet).
class WakelockPlus {
  static Future<bool> enable() async => true;
  static Future<bool> disable() async => true;
  static Future<bool> toggle({bool enable = true}) async => true;
  static Future<bool> isEnabled() async => false;
}
