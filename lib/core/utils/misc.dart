import 'package:file_picker/file_picker.dart';
import 'package:plain_notification_token/plain_notification_token.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/res/provider.dart';

Future<String?> pickOneFile() async {
  Pros.app.moveBg = false;
  final result = await FilePicker.platform.pickFiles(type: FileType.any);
  Pros.app.moveBg = true;
  return result?.files.single.path;
}

Future<String?> getToken() async {
  if (isIOS) {
    final plainNotificationToken = PlainNotificationToken();
    plainNotificationToken.requestPermission();

    // If you want to wait until Permission dialog close,
    // you need wait changing setting registered.
    await plainNotificationToken.onIosSettingsRegistered.first;
    return await plainNotificationToken.getToken();
  }
  return null;
}

String? getFileName(String? path) {
  if (path == null) {
    return null;
  }
  return path.split('/').last;
}

/// Join two path with `/`
String pathJoin(String path1, String path2) {
  return path1 + (path1.endsWith('/') ? '' : '/') + path2;
}

/// Check if a url is a file url (ends with a file extension)
bool isFileUrl(String url) => url.split('/').last.contains('.');
