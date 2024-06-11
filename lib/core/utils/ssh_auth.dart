import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/provider.dart';

abstract final class KeybordInteractive {
  static FutureOr<List<String>?> defaultHandle(
    ServerPrivateInfo spi, {
    BuildContext? ctx,
  }) async {
    try {
      final res = await (ctx ?? Pros.app.ctx)?.showPwdDialog(
        title: '2FA ${l10n.pwd}',
        id: spi.id,
        label: spi.id,
      );
      return res == null ? null : [res];
    } catch (e) {
      return null;
    }
  }
}
