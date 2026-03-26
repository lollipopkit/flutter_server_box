import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/res/store.dart';

class ConnectionStatsPage extends StatefulWidget {
  const ConnectionStatsPage({super.key});

  static const route = AppRouteNoArg(page: ConnectionStatsPage.new, path: '/server/conn_stats');

  @override
  State<ConnectionStatsPage> createState() => _ConnectionStatsPageState();
}

class _ConnectionStatsPageState extends State<ConnectionStatsPage> {
  List<ServerConnectionStats> _serverStats = [];
  bool _isLoading = true;
  bool _isCompacting = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      _isLoading = true;
    });

    final stats = Stores.connectionStats.getAllServerStats();
    setState(() {
      _serverStats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.connectionStats),
        actions: [
          IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh), tooltip: libL10n.refresh),
          IconButton(
            onPressed: _showClearAllDialog,
            icon: const Icon(Icons.clear_all, color: Colors.red),
            tooltip: libL10n.clear,
          ),
          IconButton(
            onPressed: _isCompacting ? null : _showCompactDialog,
            icon: _isCompacting
                ? SizedLoading.small
                : const Icon(Icons.compress),
            tooltip: l10n.compactDatabase,
          ),
        ],
      ),
      body: _buildBody,
    );
  }

  Widget get _buildBody {
    if (_isLoading) {
      return const Center(child: SizedLoading.large);
    }
    if (_serverStats.isEmpty) {
      return Center(child: Text(l10n.noConnectionStatsData));
    }

    return ListView.builder(
      itemCount: _serverStats.length,
      itemBuilder: (context, index) {
        final stats = _serverStats[index];
        return _buildServerStatsCard(stats);
      },
    );
  }

  Widget _buildServerStatsCard(ServerConnectionStats stats) {
    final successRate = stats.totalAttempts == 0 ? 'N/A' : '${(stats.successRate * 100).toStringAsFixed(1)}%';
    final lastSuccessTime = stats.lastSuccessTime;
    final lastFailureTime = stats.lastFailureTime;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stats.serverName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${libL10n.success}: $successRate',
                style: TextStyle(
                  fontSize: 16,
                  color: stats.successRate >= 0.8
                      ? Colors.green
                      : stats.successRate >= 0.5
                      ? Colors.orange
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(libL10n.totalAttempts, stats.totalAttempts.toString(), Icons.all_inclusive),
              _buildStatItem(
                libL10n.success,
                stats.successCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatItem(libL10n.fail, stats.failureCount.toString(), Icons.error, Colors.red),
            ],
          ),
          if (lastSuccessTime != null || lastFailureTime != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            if (lastSuccessTime != null)
              _buildTimeItem(l10n.lastSuccess, lastSuccessTime, Icons.check_circle, Colors.green),
            if (lastFailureTime != null)
              _buildTimeItem(l10n.lastFailure, lastFailureTime, Icons.error, Colors.red),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.recentConnections, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => _showServerDetailsDialog(stats), child: Text(l10n.viewDetails)),
            ],
          ),
          const SizedBox(height: 8),
          ...stats.recentConnections.take(3).map(_buildConnectionItem),
        ],
      ),
    ).cardx;
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color ?? Colors.grey),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTimeItem(String label, DateTime time, IconData icon, Color color) {
    final timeStr = time.simple();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          UIs.width7,
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(timeStr, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildConnectionItem(ConnectionStat stat) {
    final timeStr = stat.timestamp.simple();
    final isSuccess = stat.result.isSuccess;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            size: 16,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          UIs.width7,
          Text(timeStr, style: const TextStyle(fontSize: 12)),
          UIs.width7,
          Expanded(
            child: Text(
              isSuccess ? '${libL10n.success} (${stat.durationMs}ms)' : stat.result.displayName,
              style: TextStyle(fontSize: 12, color: isSuccess ? Colors.green : Colors.red),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showCompactDialog() {
    final path = '${Paths.doc}${Pfs.seperator}connection_stats_enc.hive';
    final file = File(path);
    final oldSize = file.existsSync() ? file.lengthSync() : 0;
    final sizeStr = oldSize < 1000 ? '$oldSize B' : oldSize < 1000 * 1000 ? '${(oldSize / 1000).toStringAsFixed(1)} KB' : '${(oldSize / (1000 * 1000)).toStringAsFixed(1)} MB';

    context.showRoundDialog(
      title: l10n.compactDatabase,
      child: Text(l10n.compactDatabaseContent(sizeStr)),
      actions: [
        TextButton(onPressed: context.pop, child: Text(libL10n.cancel)),
        TextButton(
          onPressed: () async {
            context.pop();
            setState(() => _isCompacting = true);
            try {
              await Stores.connectionStats.compact();
              final newSize = file.existsSync() ? file.lengthSync() : 0;
              final newSizeStr = newSize < 1000 ? '$newSize B' : newSize < 1000 * 1000 ? '${(newSize / 1000).toStringAsFixed(1)} KB' : '${(newSize / (1000 * 1000)).toStringAsFixed(1)} MB';
              if (mounted) {
                setState(() => _isCompacting = false);
                context.showSnackBar('${libL10n.success}: $sizeStr -> $newSizeStr');
              }
            } catch (e) {
               if (mounted) {
                 setState(() => _isCompacting = false);
                 context.showSnackBar('${libL10n.error}: $e');
               }
             }
          },
          child: Text(libL10n.confirm),
        ),
      ],
    );
  }
}

extension on _ConnectionStatsPageState {
  void _showServerDetailsDialog(ServerConnectionStats stats) {
    context.showRoundDialog(
      title: '${stats.serverName} - ${l10n.connectionDetails}',
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: ListView.separated(
          itemCount: stats.recentConnections.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final stat = stats.recentConnections[index];
            final timeStr = stat.timestamp.simple();
            final isSuccess = stat.result.isSuccess;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              title: Text(timeStr),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSuccess
                        ? '${libL10n.success} (${stat.durationMs}ms)'
                        : '${libL10n.fail}: ${stat.result.displayName}',
                    style: TextStyle(color: isSuccess ? Colors.green : Colors.red),
                  ),
                  if (!isSuccess && stat.errorMessage.isNotEmpty)
                    Text(
                      stat.errorMessage,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: context.pop, child: Text(libL10n.close)),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showClearServerStatsDialog(stats);
          },
          child: Text(l10n.clearThisServerStats, style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  void _showClearAllDialog() {
    context.showRoundDialog(
      title: l10n.clearAllStatsTitle,
      child: Text(l10n.clearAllStatsContent),
      actions: [
        TextButton(onPressed: context.pop, child: Text(libL10n.cancel)),
        CountDownBtn(
          onTap: () {
            context.pop();
            Stores.connectionStats.clearAll();
            _loadStats();
          },
          text: libL10n.ok,
          afterColor: Colors.red,
        ),
      ],
    );
  }

  void _showClearServerStatsDialog(ServerConnectionStats stats) {
    context.showRoundDialog(
      title: l10n.clearServerStatsTitle(stats.serverName),
      child: Text(l10n.clearServerStatsContent(stats.serverName)),
      actions: [
        TextButton(onPressed: context.pop, child: Text(libL10n.cancel)),
        CountDownBtn(
          onTap: () {
            context.pop();
            Stores.connectionStats.clearServerStats(stats.serverId);
            _loadStats();
          },
          text: libL10n.ok,
          afterColor: Colors.red,
        ),
      ],
    );
  }
}
