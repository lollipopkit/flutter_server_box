/// No-op stub of device_info_plus for HarmonyOS.
class DeviceInfoPlugin {
  Future<AndroidDeviceInfo> get androidInfo async => AndroidDeviceInfo();
  Future<IosDeviceInfo> get iosInfo async => IosDeviceInfo();
}

class AndroidDeviceInfo {
  final List<String> systemFeatures = const <String>[];
  final String model = '';
  final String manufacturer = '';
  final int sdkInt = 0;
}

class IosDeviceInfo {
  final String model = '';
}
