import 'package:dio/dio.dart';
import 'package:toolbox/data/model/app/update.dart';
import 'package:toolbox/data/res/url.dart';

class AppService {
  Future<Map> getNotify() async {
    final resp = await Dio().get('$baseUrl/notify.json');
    return resp.data;
  }

  Future<AppUpdate> getUpdate() async {
    final resp = await Dio().get('$baseUrl/update.json');
    return AppUpdate.fromJson(resp.data);
  }
}
