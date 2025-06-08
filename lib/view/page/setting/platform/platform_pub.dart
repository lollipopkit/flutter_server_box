import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/store.dart';

abstract final class PlatformPublicSettings {
  static Widget buildBioAuth() {
    return FutureWidget<bool>(
      future: LocalAuth.isAvail,
      loading: ListTile(
        leading: const Icon(Icons.fingerprint),
        title: Text(libL10n.bioAuth),
        subtitle: const Text('...', style: UIs.textGrey),
      ),
      error: (e, _) => ListTile(
        title: Text(libL10n.bioAuth),
        subtitle: Text('${libL10n.fail}: $e', style: UIs.textGrey),
      ),
      success: (can) {
        can ??= false;
        return ListTile(
          leading: const Icon(Icons.fingerprint),
          title: Text(libL10n.bioAuth),
          subtitle: can ? null : Text(libL10n.notExistFmt(libL10n.bioAuth), style: UIs.textGrey),
          trailing: can
              ? StoreSwitch(
                  prop: Stores.setting.useBioAuth,
                  callback: (val) async {
                    if (val) {
                      Stores.setting.useBioAuth.put(false);
                      return;
                    }
                    // Only auth when turn off (val == false)
                    final result = await LocalAuth.goWithResult();
                    // If failed, turn on again
                    if (result != AuthResult.success) {
                      Stores.setting.useBioAuth.put(true);
                    }
                  },
                )
              : null,
        );
      },
    );
  }
}
