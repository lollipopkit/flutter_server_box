import 'package:fl_lib/fl_lib.dart';
import 'package:plain_notification_token/plain_notification_token.dart';

Future<String?> getToken() async {
  if (!isIOS) return null;
  final instance = ApnsToken()..requestPermission();
  // Wait until Permission dialog closed
  await instance.onIosSettingsRegistered.first;
  return await instance.getToken();
}
