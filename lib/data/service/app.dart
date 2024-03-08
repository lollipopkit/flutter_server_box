import 'package:dio/dio.dart';
import 'package:toolbox/data/res/store.dart';

import '../model/app/update.dart';
import '../res/url.dart';

class AppService {
  Future<AppUpdate> getUpdate() async {
    final useCDN = Stores.setting.useCdn.fetch() == 1;
    final resp =
        await Dio().get('${useCDN ? Urls.cdnBase : Urls.resBase}/update.json');
    return AppUpdate.fromJson(resp.data);
  }
}
