import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

/// A row the settings page draws, described without naming its own row type.
///
/// This file is imported *by* the settings page, so it cannot see the type
/// that page builds its groups out of. A label and a builder is everything
/// that type needs — see `SettingsRowSpecX.row`.
typedef SettingsRowSpec = ({String label, Widget Function() build});

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
  static SettingsRowSpec? get privacyBlur {
    if (!isIOS && !isAndroid) return null;
    final label = l10n.privacyBlur;
    return (
      label: label,
      build: () => ListTile(
        leading: const Icon(Icons.blur_on),
        title: Text(label),
        subtitle: Text(l10n.privacyBlurTip, style: UIs.textGrey),
        trailing: StoreSwitch(
          prop: Stores.setting.privacyBlur,
          validator: (val) async {
            final ok = await MethodChans.setPrivacyBlur(val);
            if (!ok) Toast.error(libL10n.fail);
            return ok;
          },
        ),
      ),
    );
  }

  /// Whether this device can ask for a fingerprint or a face at all.
  ///
  /// Asked once when the page opens rather than by a builder in the row: the
  /// group the row is in has to know whether to exist, and a row that appears
  /// a frame later left a hairline with nothing under it.
  static Future<bool> get bioAuthAvailable async {
    if (!isIOS && !isAndroid && !isWindows) return false;
    return await LocalAuth.isAvail;
  }

  /// The switch and the delay under it, as one row of a group.
  static Widget buildBioAuthRows() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [_buildBioAuth(), _buildBioAuthDelay()],
    );
  }

  static Widget _buildBioAuth() {
    return ListTile(
      leading: const Icon(Icons.fingerprint),
      title: Text(libL10n.bioAuth),
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
      leading: const Icon(Icons.timer_outlined),
      title: Text('${libL10n.delay} (${libL10n.second})'),
      trailing: Stores.setting.delayBioAuthLock.fieldWidget(),
    );
  }
}
