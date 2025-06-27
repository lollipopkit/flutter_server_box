import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/res/store.dart';

extension LogoExt on Server {
  String? getLogoUrl(BuildContext context) {
    var logoUrl = spi.custom?.logoUrl ?? Stores.setting.serverLogoUrl.fetch().selfNotEmptyOrNull;
    if (logoUrl == null) {
      return null;
    }
    final dist = status.more[StatusCmdType.sys]?.dist;
    if (dist != null) {
      logoUrl = logoUrl.replaceFirst('{DIST}', dist.name);
    }
    logoUrl = logoUrl.replaceFirst('{BRIGHT}', context.isDark ? 'dark' : 'light');
    return logoUrl;
  }
}
