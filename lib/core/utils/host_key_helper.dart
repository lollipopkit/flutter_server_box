import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

Future<bool> ensureHostKeyAcceptedForSftp(BuildContext context, Spi spi) async {
  final known = Stores.setting.sshKnownHostFingerprints.get();
  final hostId = spi.id.isNotEmpty ? spi.id : spi.oldId;
  final prefix = '$hostId::';
  if (known.keys.any((key) => key.startsWith(prefix))) {
    return true;
  }

  final (result, error) = await context.showLoadingDialog<bool>(
    fn: () async {
      await ensureKnownHostKey(
        spi,
        onKeyboardInteractive: (_) => KeybordInteractive.defaultHandle(spi, ctx: context),
      );
      return true;
    },
  );
  return error == null && result == true;
}
