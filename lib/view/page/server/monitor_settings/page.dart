import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/view/page/server/monitor_settings/view.dart';
import 'package:server_box/view/page/server/monitor_settings/widgets.dart';

final class MonitorSettingsArgs {
  final MonitorHttpCredential monitor;

  /// The server's name, shown under the title.
  final String subtitle;

  /// See [MonitorSettingsView.onOwnPasswordChanged].
  final Future<void> Function(String newPassword)? onOwnPasswordChanged;

  const MonitorSettingsArgs({
    required this.monitor,
    required this.subtitle,
    this.onOwnPasswordChanged,
  });
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) => PopGuard(
        enabled: _ctrl.dirty,
        confirm: () => MonitorUi.confirmDiscard(context),
        child: Scaffold(
          appBar: CustomAppBar(
            title: TwoLineText(
              up: l10n.monitorSettings,
              down: widget.args.subtitle,
            ),
            actions: [
              if (_ctrl.ready)
                if (_ctrl.saving)
                  // Sized to the button it stands in for, so the bar does not
                  // twitch when a save starts.
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  // `IconButton`, which is what every other route's bar here
                  // uses — `Btn.icon` draws the icon at whatever size it is
                  // given inside 7 points of padding, so at 18 the whole target
                  // was 32 square, under both platforms' minimum. The 18pt rule
                  // in CLAUDE.md is about a *tab's* bar, which is shorter than
                  // this one.
                  IconButton(
                    tooltip: libL10n.save,
                    icon: const Icon(Icons.save),
                    onPressed: _ctrl.save,
                  ),
            ],
          ),
          body: MonitorSettingsView(
            monitor: widget.args.monitor,
            controller: _ctrl,
            onOwnPasswordChanged: widget.args.onOwnPasswordChanged,
          ),
        ),
      ),
    );
  }
}
