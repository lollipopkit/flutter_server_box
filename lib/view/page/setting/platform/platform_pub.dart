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
    return ExpandTile(
      leading: const Icon(Icons.fingerprint),
      title: Text(libL10n.bioAuth),
      children: [_buildBioAuth(), _buildBioAuthDelay()],
    );
  }

  static Widget _buildBioAuthDelay() {
    return FutureWidget<bool>(
      future: LocalAuth.isAvail,
      loading: ListTile(
        title: Text('${libL10n.delay} (${libL10n.second})'),
        subtitle: const Text('...', style: UIs.textGrey),
      ),
      error: (e, _) => ListTile(
        title: Text('${libL10n.delay} (${libL10n.second})'),
        subtitle: Text('${libL10n.fail}: $e', style: UIs.textGrey),
      ),
      success: (can) {
        return ListTile(
          title: Text('${libL10n.delay} (${libL10n.second})'),
          trailing: can == true
              ? Stores.setting.delayBioAuthLock.fieldWidget()
              : null,
        );
      },
    );
  }

  static Widget _buildBioAuth() {
    return FutureWidget<bool>(
      future: LocalAuth.isAvail,
      loading: ListTile(
        title: Text(libL10n.switch_),
        subtitle: const Text('...', style: UIs.textGrey),
      ),
      error: (e, _) => ListTile(
        title: Text(libL10n.switch_),
        subtitle: Text('${libL10n.fail}: $e', style: UIs.textGrey),
      ),
      success: (can) {
        can ??= false;
        return ListTile(
          title: Text(libL10n.switch_),
          subtitle: can
              ? null
              : Text(libL10n.notExistFmt(libL10n.bioAuth), style: UIs.textGrey),
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
