import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';

/// The agent's minimum, said by the form before the agent says it.
const kMonitorMinPassword = 8;

/// The agent's current password and a new one typed twice, for
/// `PUT /me/password`. Null when the dialog was dismissed or the two new ones
/// do not do.
///
/// The controllers are the dialog's to dispose ([DisposeWith]): the answer
/// arrives while its fields are still animating out.
Future<({String current, String next})?> askMonitorPasswordChange(
  BuildContext context,
) async {
  final current = TextEditingController();
  final first = TextEditingController();
  final second = TextEditingController();
  final ok = await context.showRoundDialog<bool>(
    title: l10n.monitorChangePassword,
    child: DisposeWith(
      notifiers: [current, first, second],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            controller: current,
            label: l10n.monitorCurrentPassword,
            icon: Icons.password,
            obscureText: true,
            suggestion: false,
            autoFocus: true,
          ),
          Input(
            controller: first,
            label: l10n.monitorNewPassword,
            hint: l10n.monitorPasswordTooShort,
            icon: Icons.password,
            obscureText: true,
            suggestion: false,
          ),
          Input(
            controller: second,
            label: libL10n.confirm,
            icon: Icons.password,
            obscureText: true,
            suggestion: false,
            onSubmitted: (_) => context.popDialog(true),
          ),
        ],
      ),
    ),
    actions: Btnx.cancelOk,
  );
  if (ok != true || current.text.isEmpty) return null;
  final (a, b) = (first.text, second.text);
  if (a.length < kMonitorMinPassword) {
    Toast.show(l10n.monitorPasswordTooShort);
    return null;
  }
  if (a != b) {
    Toast.show(l10n.monitorPasswordMismatch);
    return null;
  }
  return (current: current.text, next: a);
}

/// What to tell someone whose password change the agent refused.
String monitorPasswordErrText(Object e) {
  if (e is! MonitorHttpErr) return '$e';
  return switch (e.type) {
    MonitorHttpErrType.reauth => l10n.monitorErrReauth,
    MonitorHttpErrType.forbidden => l10n.monitorNoRemoteAccess,
    _ => e.message ?? '$e',
  };
}
