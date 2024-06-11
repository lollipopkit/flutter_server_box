import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/provider.dart';

import '../../data/model/server/ping_result.dart';

/// Only permit ipv4 / ipv6 / domain chars
final targetReg = RegExp(r'[a-zA-Z0-9\.-_:]+');

class PingPage extends StatefulWidget {
  const PingPage({super.key});

  @override
  State<PingPage> createState() => _PingPageState();
}

class _PingPageState extends State<PingPage>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _textEditingController;
  final _results = ValueNotifier(<PingResult>[]);
  bool get isInit => _results.value.isEmpty;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    super.dispose();
    _textEditingController.dispose();
    _results.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: _results,
        builder: (_, __) => _buildBody(),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'ping',
      onPressed: () {
        context.showRoundDialog(
          title: l10n.choose,
          child: Input(
            autoFocus: true,
            controller: _textEditingController,
            hint: l10n.inputDomainHere,
            maxLines: 1,
            onSubmitted: (_) => _doPing(),
          ),
          actions: [
            TextButton(onPressed: _doPing, child: Text(l10n.ok)),
          ],
        );
      },
      child: const Icon(Icons.search),
    );
  }

  Future<void> _doPing() async {
    context.pop();
    try {
      await doPing();
    } catch (e) {
      context.showRoundDialog(
        title: l10n.error,
        child: Text(e.toString()),
        actions: [
          TextButton(
            onPressed: () => Pfs.copy(e.toString()),
            child: Text(l10n.copy),
          ),
        ],
      );
      rethrow;
    }
  }

  Widget _buildBody() {
    if (isInit) {
      return Center(
        child: Text(
          l10n.noResult,
          style: const TextStyle(fontSize: 15),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(11),
      controller: ScrollController(),
      itemCount: _results.value.length,
      itemBuilder: (_, index) => _buildResultItem(_results.value[index]),
    );
  }

  Widget _buildResultItem(PingResult result) {
    final unknown = l10n.unknown;
    final ms = l10n.ms;
    return CardX(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
        title: Text(
          result.serverName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: UIs.primaryColor,
          ),
        ),
        subtitle: Text(
          _buildPingSummary(result, unknown, ms),
          style: UIs.text11,
        ),
        trailing: Text(
          '${l10n.pingAvg}${result.statistic?.avg?.toStringAsFixed(2) ?? l10n.unknown} $ms',
          style: TextStyle(
            fontSize: 14,
            color: UIs.primaryColor,
          ),
        ),
      ),
    );
  }

  String _buildPingSummary(PingResult result, String unknown, String ms) {
    final ip = result.ip ?? unknown;
    if (result.results == null || result.results!.isEmpty) {
      return '$ip - ${l10n.noResult}';
    }
    final ttl = result.results?.firstOrNull?.ttl ?? unknown;
    final loss = result.statistic?.loss ?? unknown;
    final min = result.statistic?.min ?? unknown;
    final max = result.statistic?.max ?? unknown;
    return '$ip\n${l10n.ttl}: $ttl, ${l10n.loss}: $loss%\n${l10n.min}: $min $ms, ${l10n.max}: $max $ms';
  }

  Future<void> doPing() async {
    FocusScope.of(context).requestFocus(FocusNode());
    _results.value.clear();
    final target = _textEditingController.text.trim();
    if (target.isEmpty) {
      context.showSnackBar(l10n.pingInputIP);
      return;
    }

    if (Pros.server.serverOrder.isEmpty) {
      context.showSnackBar(l10n.pingNoServer);
      return;
    }

    /// avoid ping command injection
    if (!targetReg.hasMatch(target)) {
      context.showSnackBar(l10n.pingInputIP);
      return;
    }

    await Future.wait(Pros.server.servers.map((e) async {
      if (e.client == null) {
        return;
      }
      final result = await e.client!.run('ping -c 3 $target').string;
      _results.value.add(PingResult.parse(e.spi.name, result));
      // [ValueNotifier] only notify when value is changed
      // But we just add a element to list without changing the list itself
      // So we need to notify manually
      //
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      _results.notifyListeners();
    }));
  }

  @override
  bool get wantKeepAlive => true;
}
