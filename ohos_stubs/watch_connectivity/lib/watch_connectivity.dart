/// No-op stub of watch_connectivity for HarmonyOS port.
class WatchConnectivity {
  WatchConnectivity();

  Future<bool?> get isReachable async => null;

  Future<bool> get isPaired async => false;

  Future<Map<String, dynamic>> get applicationContext async => {};

  Future<void> updateApplicationContext(Map<String, dynamic> data) async {}

  void setOnMessageReceived(void Function(Map<String, dynamic> message) onMessageReceived) {}
}
