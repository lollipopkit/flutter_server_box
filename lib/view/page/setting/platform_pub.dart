import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/utils/platform/auth.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/future_widget.dart';
import 'package:toolbox/view/widget/store_switch.dart';

class PlatformPublicSettings {
  static Widget buildBioAuth() {
    return FutureWidget<bool>(
      future: BioAuth.isAvail,
      loading: ListTile(
        title: Text(l10n.bioAuth),
        subtitle: Text(l10n.serverTabLoading, style: UIs.textGrey),
      ),
      error: (e, __) => ListTile(
        title: Text(l10n.bioAuth),
        subtitle: Text('${l10n.failed}: $e', style: UIs.textGrey),
      ),
      success: (can) {
        return ListTile(
          title: Text(l10n.bioAuth),
          subtitle: can == true
              ? null
              : const Text(
                  'Not available',
                  style: UIs.textGrey,
                ),
          trailing: can == true
              ? StoreSwitch(
                  prop: Stores.setting.useBioAuth,
                  func: (val) async {
                    if (val) {
                      Stores.setting.useBioAuth.put(false);
                      return;
                    }
                    // Only auth when turn off (val == false)
                    final result = await BioAuth.auth(l10n.authRequired);
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
