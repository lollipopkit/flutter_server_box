import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/res/setting_range.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';

/// Shared state and dialog helpers exposed by [AppSettingsPage] to its
/// standalone section libraries without circular imports.
abstract class AppSettingsHost<W extends ConsumerStatefulWidget>
    extends ConsumerState<W> {
  SettingStore get setting => Stores.setting;

  String? get savedCrashReport;
  void clearSavedCrashReport();

  bool? get bioAuthAvail;

  TextEditingController get sshOpacityCtrl;
  TextEditingController get sshBlurCtrl;
  TextEditingController get textScalerCtrl;
  TextEditingController get serverLogoCtrl;
  TextEditingController get serverMarkCtrl;

  /// Opens the MCP server settings section as a standalone page.
  void openMcpSettings();

  /// Redraws after something a listenable does not cover.
  ///
  /// The Linux page reads `Rootfs.profiles`, which is built by scanning a
  /// directory rather than from a store key, so nothing notifies when an
  /// install or a removal changes it.
  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> showTextSettingDialog({
    required String title,
    required String initialValue,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onSave,
    bool suggestion = false,
  }) {
    return Future<void>.sync(
      () => withTextFieldController((ctrl) async {
        ctrl.text = initialValue;

        void save() {
          onSave(ctrl.text.trim());
          context.popSheet();
        }

        await context.showSheet<bool>(
          title: title,
          child: Input(
            controller: ctrl,
            autoFocus: true,
            label: label,
            hint: hint,
            icon: icon,
            suggestion: suggestion,
            onSubmitted: (_) => save(),
          ),
          actions: Btn.ok(onTap: save).toList,
        );
      }),
    );
  }

  void showFontSizeDialog(SqliteProp<double> property) {
    final ctrl = TextEditingController(text: property.fetch().toString());
    void onSave() {
      context.popSheet();
      final fontSize = double.tryParse(ctrl.text);
      if (fontSize == null ||
          !SettingRange.contains(SettingRange.fontSize, fontSize)) {
        context.showSheet(
          title: libL10n.fail,
          child: Text('${libL10n.invalid}: ${ctrl.text}'),
        );
        return;
      }
      property.set(fontSize);
    }

    unawaited(
      context
          .showSheet<void>(
            title: libL10n.fontSize,
            child: Input(
              controller: ctrl,
              autoFocus: true,
              type: TextInputType.number,
              icon: Icons.font_download,
              suggestion: false,
              onSubmitted: (_) => onSave(),
            ),
            actions: Btn.ok(onTap: onSave).toList,
          )
          .whenComplete(() => disposeAfterExit(ctrl)),
    );
  }

  /// Frees a dialog's controller once its route has finished leaving.
  ///
  /// A second is far longer than any dialog transition and costs a controller
  /// held that much longer; the alternative is delaying the caller, and what
  /// follows this is a download.
  void disposeAfterExit(TextEditingController ctrl) {
    Future.delayed(const Duration(seconds: 1), ctrl.dispose);
  }
}
