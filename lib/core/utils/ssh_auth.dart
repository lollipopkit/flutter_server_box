import 'dart:async';

import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/res/provider.dart';

abstract final class KeybordInteractive {
  static FutureOr<List<String>?> defaultHandle(
    ServerPrivateInfo spi, {
    BuildContext? ctx,
  }) async {
    try {
      final res = await (ctx ?? Pros.app.ctx)?.showPwdDialog(
        title: '2FA ${l10n.pwd}',
        label: spi.id,
      );
      return res == null ? null : [res];
    } catch (e) {
      return null;
    }
  }
}
