import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:window_manager/window_manager.dart';

abstract final class PlatformPublicSettings {
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
                  callback: (val) async {
                    if (val) {
                      Stores.setting.useBioAuth.put(false);
                      return;
                    }
                    // Only auth when turn off (val == false)
                    final result = await BioAuth.goWithResult();
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

  static Widget buildSaveWindowSize() {
    final isBusy = false.vn;
    // Only show [FadeIn] when previous state is busy.
    var lastIsBusy = false;
    final prop = Stores.setting.windowSize;

    return ListTile(
      title: Text(l10n.rememberWindowSize),

      /// Copied from `fl_build/view/store_switch`
      trailing: ValBuilder(
        listenable: isBusy,
        builder: (busy) {
          return ValBuilder(
            listenable: prop.listenable(),
            builder: (value) {
              if (busy) {
                lastIsBusy = true;
                return UIs.centerSizedLoadingSmall.paddingOnly(right: 17);
              }

              final switcher = Switch(
                value: value.isNotEmpty,
                onChanged: (value) async {
                  isBusy.value = true;
                  final size = await windowManager.getSize();
                  isBusy.value = false;
                  prop.put(size.toIntStr());
                },
              );

              if (lastIsBusy) {
                final ret = FadeIn(child: switcher);
                lastIsBusy = false;
                return ret;
              }

              return switcher;
            },
          );
        },
      ),
    );
  }
}
