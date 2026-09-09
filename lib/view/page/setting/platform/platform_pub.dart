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
      success: (canAuth) {
        // A `final` rather than `can ??= false`: both closures below capture
        // it, and a captured variable is not promoted.
        final can = canAuth ?? false;
        final unavailable = can
            ? null
            : Text(libL10n.notExistFmt(libL10n.bioAuth), style: UIs.textGrey);
        return ValBuilder(
          listenable: Stores.setting.useBioAuth.listenable(),
          builder: (on) {
            // The switch used to be absent whenever the device could not
            // authenticate, which is right until the setting is on anyway —
            // and a backup restored from a phone puts it there. Then the one
            // control that would turn it off was missing on exactly the
            // devices that needed it, and the lock screen had nothing behind
            // it to open (#1406). `home.dart` turns it off by itself now; this
            // is what is left if that write ever fails.
            if (!can && !on) {
              return ListTile(
                title: Text(libL10n.switch_),
                subtitle: unavailable,
              );
            }
            return ListTile(
              title: Text(libL10n.switch_),
              subtitle: unavailable,
              trailing: StoreSwitch(
                prop: Stores.setting.useBioAuth,
                // A `validator` and not a `callback`, for the reason spelled
                // out above `buildPrivacyBlur`: `StoreSwitch` writes the new
                // value after the callback regardless, so the old code's
                // "authenticate, and put the old value back if it failed" was
                // overwritten a line later. Turning the lock *off* took no
                // authentication at all — anyone holding an unlocked device
                // could remove it, which is the one thing this check is for.
                validator: (val) async {
                  if (val) return can;
                  // Except where nothing can be proven. Asking a machine with
                  // no sensor to authenticate before it may stop asking for
                  // authentication is the deadlock again, one screen along.
                  if (!can) return true;
                  return await LocalAuth.goWithResult() == AuthResult.success;
                },
              ),
            );
          },
        );
      },
    );
  }
}
