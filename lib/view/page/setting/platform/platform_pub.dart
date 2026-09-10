import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

abstract final class PlatformPublicSettings {
  /// Mobile only: there is no app switcher card to hide on a desktop, and
  /// neither platform channel implements this there.
  ///
  /// The native side keeps its own copy, so the switch has to push as well as
  /// store.
  ///
  /// A `validator` and not a `callback`: the push is what actually covers the
  /// app, so if the platform refuses it the switch has to stay where it was.
  /// Written the other way the preference was stored anyway, and the user was
  /// left reading "on" off a switch that had covered nothing.
  static Widget? get buildPrivacyBlur {
    if (!isIOS && !isAndroid) return null;
    return ListTile(
      leading: const Icon(Icons.blur_on),
      title: Text(l10n.privacyBlur),
      subtitle: Text(l10n.privacyBlurTip, style: UIs.textGrey),
      trailing: StoreSwitch(
        prop: Stores.setting.privacyBlur,
        validator: (val) async {
          final ok = await MethodChans.setPrivacyBlur(val);
          if (!ok) Toast.error(libL10n.fail);
          return ok;
        },
      ),
    );
  }

  static Widget get buildBioAuth {
    return FutureWidget<bool>(
      future: LocalAuth.isAvail,
      loading: const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      success: (canAuth) {
        if (canAuth != true) return const SizedBox.shrink();
        return ExpandTile(
          leading: const Icon(Icons.fingerprint),
          title: Text(libL10n.bioAuth),
          children: [_buildBioAuth(), _buildBioAuthDelay()],
        ).cardx;
      },
    );
  }

  static Widget _buildBioAuth() {
    return ListTile(
      title: Text(libL10n.switch_),
      trailing: StoreSwitch(
        prop: Stores.setting.useBioAuth,
        validator: (val) async {
          if (val) return true;
          return await LocalAuth.goWithResult() == AuthResult.success;
        },
      ),
    );
  }

  static Widget _buildBioAuthDelay() {
    return ListTile(
      title: Text('${libL10n.delay} (${libL10n.second})'),
      trailing: Stores.setting.delayBioAuthLock.fieldWidget(),
    );
  }
}
