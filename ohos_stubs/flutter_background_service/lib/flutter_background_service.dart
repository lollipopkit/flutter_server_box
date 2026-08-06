import 'dart:async';

/// No-op stub of flutter_background_service for HarmonyOS port.
class FlutterBackgroundService {
  static FlutterBackgroundService? _instance;

  FlutterBackgroundService._();

  factory FlutterBackgroundService() => _instance ??= FlutterBackgroundService._();

  Future<void> configure({
    AndroidConfiguration? androidConfiguration,
    IosConfiguration? iosConfiguration,
  }) async {}

  Stream<Map<String, dynamic>> get on => const Stream<Map<String, dynamic>>.empty();
  Future<void> startService() async {}
  Future<void> invoke(Map<String, dynamic> data) async {}
  Future<void> stopService() async {}
  Future<void> sendData(Map<String, dynamic> data) async {}
}

class ServiceInstance {
  final bool isForegroundService = false;
  Future<void> stopSelf() async {}
  Future<void> setForegroundNotificationInfo({required String title, required String content}) async {}
  Future<void> setAsForegroundService() async {}
  Future<void> setAsBackgroundService() async {}
  void on(String event, void Function(Map<String, dynamic> data) callback) {}
}

class AndroidConfiguration {
  final FutureOr<void> Function(ServiceInstance service) onStart;
  final bool autoStart;
  final bool isForegroundMode;
  final String? initialNotificationTitle;
  final String? initialNotificationContent;

  AndroidConfiguration({
    required this.onStart,
    required this.autoStart,
    required this.isForegroundMode,
    this.initialNotificationTitle,
    this.initialNotificationContent,
  });
}

class IosConfiguration {
  final FutureOr<void> Function(ServiceInstance service)? onBackground;

  IosConfiguration({this.onBackground});
}
