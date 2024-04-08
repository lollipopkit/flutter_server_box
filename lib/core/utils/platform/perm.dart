import 'package:permission_handler/permission_handler.dart';

abstract final class PermUtils {
  static Future<bool> request(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) {
      return true;
    } else {
      final result = await permission.request();
      return result.isGranted;
    }
  }
}
