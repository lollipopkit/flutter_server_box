import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/data/model/server/discovery_result.dart';

part 'widget.dart';

class SshDiscoveryPage extends ConsumerStatefulWidget {
  const SshDiscoveryPage({super.key});

  static const route = AppRouteNoArg<List<SshDiscoveryResult>>(
    page: SshDiscoveryPage.new,
    path: '/servers/discovery',
  );

  @override
  ConsumerState<SshDiscoveryPage> createState() => _SshDiscoveryPageState();
}

class _SshDiscoveryPageState extends ConsumerState<SshDiscoveryPage> {
  final _config = ValueNotifier(const SshDiscoveryConfig());
  final _discoveryResults = ValueNotifier<List<SshDiscoveryResult>>([]);
  final _isDiscovering = ValueNotifier(false);
  final _discoveryReport = ValueNotifier<SshDiscoveryReport?>(null);

  @override
  void dispose() {
    _config.dispose();
    _discoveryResults.dispose();
    _isDiscovering.dispose();
    _discoveryReport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.discoverSshServers),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings)],
      ),
      body: _buildBody(),
      floatingActionButton: _isDiscovering.listenVal((discovering) {
        if (discovering) return UIs.placeholder;
        return _buildFAB();
      }),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildSummary(),
        Expanded(child: _buildResultsList()),
      ],
    );
  }

  Widget _buildSummary() {
    return _discoveryReport.listenVal((report) {
      if (report == null) {
        return UIs.placeholder;
      }

      return Container(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.discoverySummary, style: const TextStyle(fontWeight: FontWeight.bold)),
                UIs.height7,
                Text('${libL10n.found}: ${report.count} ${libL10n.servers}'),
                Text('${libL10n.duration}: ${report.durationMs}ms'),
                Text(
                  '${l10n.finishedAt}: ${DateTime.parse(report.generatedAt).toLocal().toString().substring(0, 16)}',
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildResultsList() {
    return _discoveryResults.listenVal((results) {
      if (results.isEmpty) {
        return _isDiscovering.listenVal((discovering) {
          if (discovering) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [CircularProgressIndicator(), UIs.height13, Text('Discovering SSH servers...')],
              ),
            );
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(BoxIcons.bx_search, size: 64, color: UIs.textGrey.color),
                UIs.height13,
                Text(l10n.tapToStartDiscovery, style: UIs.textGrey),
              ],
            ),
          );
        });
      }

      return ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final result = results[index];
          return _buildResultTile(result, index);
        },
      );
    });
  }

  Widget _buildResultTile(SshDiscoveryResult result, int index) {
    return ListTile(
      leading: Icon(
        result.isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: result.isSelected ? Colors.green : null,
      ),
      title: Text(result.ip),
      subtitle: result.banner != null
          ? Text(result.banner!, style: const TextStyle(fontSize: 12))
          : Text('Port ${result.port}', style: UIs.textGrey),
      trailing: const Icon(BoxIcons.bx_server),
      onTap: () {
        final updated = result.copyWith(isSelected: !result.isSelected);
        final newResults = List<SshDiscoveryResult>.from(_discoveryResults.value);
        newResults[index] = updated;
        _discoveryResults.value = newResults;
      },
    );
  }

  Widget _buildFAB() {
    return _discoveryResults.listenVal((results) {
      final selectedResults = results.where((r) => r.isSelected).toList();
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutBack)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.centerRight,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        child: selectedResults.isNotEmpty
            ? FloatingActionButton.extended(
                key: const ValueKey('import'),
                heroTag: 'import_fab',
                onPressed: () => _importSelected(),
                icon: const Icon(Icons.add),
                label: Text('${libL10n.import} (${selectedResults.length})'),
              )
            : FloatingActionButton.extended(
                key: const ValueKey('discovery'),
                heroTag: 'discovery_fab',
                onPressed: _startDiscovery,
                icon: const Icon(BoxIcons.bx_search),
                label: Text(libL10n.search),
              ),
      );
    });
  }

  Future<void> _startDiscovery() async {
    _isDiscovering.value = true;
    _discoveryResults.value = [];
    _discoveryReport.value = null;

    try {
      final report = await SshDiscoveryService.discover(_config.value);
      _discoveryReport.value = report;
      _discoveryResults.value = report.items;
    } catch (e) {
      if (mounted) {
        context.showSnackBar('${l10n.discoveryFailed}: $e');
      }
    } finally {
      _isDiscovering.value = false;
    }
  }

  void _showSettings() {
    context.showRoundDialog(
      child: _DiscoverySettingsDialog(config: _config.value, onChanged: (config) => _config.value = config),
      actions: Btnx.oks,
    );
  }

  void _importSelected() {
    final selected = _discoveryResults.value.where((r) => r.isSelected).toList();
    if (selected.isEmpty) return;

    context.pop(selected);
  }
}
