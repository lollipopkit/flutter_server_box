import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/view/page/server/monitor_settings/view.dart';

final class MonitorSettingsArgs {
  final MonitorHttpCredential monitor;

  /// The server's name, shown under the title.
  final String subtitle;

  const MonitorSettingsArgs({required this.monitor, required this.subtitle});
}

/// [MonitorSettingsView] as a page, which is how a server's own detail page
/// opens it.
///
/// The bar is this side's, because only a route has one — the tab hosts the
/// same view in a column and draws its own. What the bar needs comes from
/// [MonitorSettingsController], so neither host reaches into the view.
final class MonitorSettingsPage extends StatefulWidget {
  final MonitorSettingsArgs args;

  const MonitorSettingsPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorSettingsArgs>(
    page: MonitorSettingsPage.new,
    path: '/server/monitor_settings',
  );

  @override
  State<MonitorSettingsPage> createState() => _MonitorSettingsPageState();
}

final class _MonitorSettingsPageState extends State<MonitorSettingsPage> {
  final _ctrl = MonitorSettingsController();

  /// Set once the user has agreed to lose the edits.
  ///
  /// The view still reports dirty — nothing here can clear its form — so
  /// without this the pop that follows the confirmation is intercepted by the
  /// same `canPop` that asked for it, and the dialog reopens itself.
  bool _discarding = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) => PopScope(
        canPop: _discarding || !_ctrl.dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: Scaffold(
          appBar: CustomAppBar(
            centerTitle: true,
            title: TwoLineText(
              up: l10n.monitorSettings,
              down: widget.args.subtitle,
            ),
            actions: [
              if (_ctrl.ready)
                if (_ctrl.saving)
                  const Padding(
                    padding: EdgeInsets.all(13),
                    child: SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Btn.icon(
                    text: libL10n.save,
                    icon: const Icon(Icons.save, size: 18),
                    onTap: _ctrl.save,
                  ),
            ],
          ),
          body: MonitorSettingsView(
            monitor: widget.args.monitor,
            controller: _ctrl,
          ),
        ),
      ),
    );
  }

  /// Closing the page is this side's job, which is why the dialog is here and
  /// not in the view: the tab has nothing to pop.
  Future<void> _confirmDiscard() async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue(libL10n.delete)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    setState(() => _discarding = true);
    // `canPop` is read while the route builds, so the pop has to come after
    // the frame that rebuilds it with the flag set.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.pop();
  }
}
