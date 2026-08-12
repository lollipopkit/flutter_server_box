import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/data/model/server/discovery_result.dart';

part 'settings.dart';

/// Sweeps the local network for hosts listening on an SSH port, and hands back
/// the one that was picked.
///
/// A dialog rather than a page, and one host rather than many. It exists to
/// fill in a few fields of the form behind it; a page that replaces that form
/// to do so loses sight of what it was opened for, and a set of hosts has
/// nowhere to go in a form describing one.
class SshDiscoveryDialog extends StatefulWidget {
  const SshDiscoveryDialog._();

  /// Shows it. Returns what was picked, or null.
  static Future<SshDiscoveryResult?> show(BuildContext context) {
    return context.showRoundDialog<SshDiscoveryResult>(
      title: l10n.discoverSshServers,
      child: const SshDiscoveryDialog._(),
      actions: [Btn.cancel()],
    );
  }

  @override
  State<SshDiscoveryDialog> createState() => _SshDiscoveryDialogState();
}

class _SshDiscoveryDialogState extends State<SshDiscoveryDialog> {
  final _config = ValueNotifier(const SshDiscoveryConfig());
  final _results = ValueNotifier<List<SshDiscoveryResult>>([]);
  final _scanning = ValueNotifier(false);
  final _report = ValueNotifier<SshDiscoveryReport?>(null);

  @override
  void dispose() {
    _config.dispose();
    _results.dispose();
    _scanning.dispose();
    _report.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      // Tall enough to be worth scrolling, short enough to stay a dialog.
      height: 380,
      child: Column(
        children: [
          _buildBar(),
          const Divider(height: 1),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  /// What the last sweep found, and the two things that can be done about it.
  Widget _buildBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: _report.listenVal((report) {
              if (report == null) return UIs.placeholder;
              return Text(
                '${libL10n.found}: ${report.count} · ${report.durationMs}ms',
                style: UIs.text12Grey,
              );
            }),
          ),
          IconButton(
            tooltip: l10n.discoverySettings,
            icon: const Icon(Icons.settings, size: 18),
            onPressed: _showSettings,
          ),
          _scanning.listenVal(
            (scanning) => IconButton(
              tooltip: libL10n.search,
              icon: scanning
                  ? SizedLoading.small
                  : const Icon(BoxIcons.bx_search, size: 18),
              onPressed: scanning ? null : _scan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return _results.listenVal((results) {
      if (results.isEmpty) {
        return _scanning.listenVal(
          (scanning) => Center(
            child: Text(
              scanning ? libL10n.loadingEllipsis : l10n.tapToStartDiscovery,
              style: UIs.textGrey,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: results.length,
        itemBuilder: (_, index) {
          final result = results[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(BoxIcons.bx_server, size: 20),
            title: Text('${result.ip}:${result.port}', style: UIs.text13),
            // What the host said when it answered. It names an SSH build
            // rather than a machine, so nothing is filled in from it — but it
            // is how someone tells two addresses apart before picking one.
            subtitle: result.banner == null
                ? null
                : Text(
                    result.banner!,
                    style: UIs.text12Grey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.popDialog(result),
          );
        },
      );
    });
  }

  Future<void> _scan() async {
    _scanning.value = true;
    _results.value = [];
    _report.value = null;

    try {
      final report = await SshDiscoveryService.discover(_config.value);
      if (!mounted) return;
      _report.value = report;
      _results.value = report.items;
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('${l10n.discoveryFailed}: $e');
    } finally {
      if (mounted) _scanning.value = false;
    }
  }

  void _showSettings() {
    context.showRoundDialog(
      child: _DiscoverySettingsDialog(
        config: _config.value,
        onChanged: (config) => _config.value = config,
      ),
      actions: Btnx.oks,
    );
  }
}
