import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app.dart';

abstract final class KeybordInteractive {
  static FutureOr<List<String>?> defaultHandle(
    Spi spi, {
    BuildContext? ctx,
  }) async {
    try {
      final res = await (ctx ?? AppProvider.ctx)?.showPwdDialog(
        title: l10n.pwd,
        id: spi.id,
        label: spi.id,
      );
      return res == null ? null : [res];
    } catch (e) {
      return null;
    }
  }
}
