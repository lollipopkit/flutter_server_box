import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/view/widget/value_notifier.dart';

import '../../core/extension/uint8list.dart';
import '../../data/model/server/ping_result.dart';
import '../../data/provider/server.dart';
import '../../data/res/color.dart';
import '../../data/res/ui.dart';
import '../../locator.dart';
import '../widget/input_field.dart';
import '../widget/round_rect_card.dart';

/// Only permit ipv4 / ipv6 / domain chars
final targetReg = RegExp(r'[a-zA-Z0-9\.-_:]+');

class PingPage extends StatefulWidget {
  const PingPage({Key? key}) : super(key: key);

  @override
  _PingPageState createState() => _PingPageState();
}

class _PingPageState extends State<PingPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin {
  late TextEditingController _textEditingController;
  final _results = ValueNotifier(<PingResult>[]);
  final _serverProvider = locator<ServerProvider>();
  late S _s;

  bool get isInit => _results.value.isEmpty;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
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
      body: ValueBuilder(
        listenable: _results,
        build: _buildBody,
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'ping',
      onPressed: () {
        context.showRoundDialog(
          title: Text(_s.choose),
          child: Input(
            autoFocus: true,
            controller: _textEditingController,
            hint: _s.inputDomainHere,
            maxLines: 1,
            onSubmitted: (_) => _doPing(),
          ),
          actions: [
            TextButton(onPressed: _doPing, child: Text(_s.ok)),
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
        title: Text(_s.error),
        child: Text(e.toString()),
        actions: [
          TextButton(
            onPressed: () => copy2Clipboard(e.toString()),
            child: Text(_s.copy),
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
          _s.noResult,
          style: const TextStyle(fontSize: 18),
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
    final unknown = _s.unknown;
    final ms = _s.ms;
    return RoundRectCard(
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
        title: Text(
          result.serverName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        subtitle: Text(
          _buildPingSummary(result, unknown, ms),
          style: UIs.textSize11,
        ),
        trailing: Text(
          '${_s.pingAvg}${result.statistic?.avg?.toStringAsFixed(2) ?? _s.unknown} $ms',
          style: TextStyle(
            fontSize: 14,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  String _buildPingSummary(PingResult result, String unknown, String ms) {
    final ip = result.ip ?? unknown;
    if (result.results == null || result.results!.isEmpty) {
      return '$ip - ${_s.noResult}';
    }
    final ttl = result.results?.first.ttl ?? unknown;
    final loss = result.statistic?.loss ?? unknown;
    final min = result.statistic?.min ?? unknown;
    final max = result.statistic?.max ?? unknown;
    return '$ip\n${_s.ttl}: $ttl, ${_s.loss}: $loss%\n${_s.min}: $min $ms, ${_s.max}: $max $ms';
  }

  Future<void> doPing() async {
    FocusScope.of(context).requestFocus(FocusNode());
    _results.value.clear();
    final target = _textEditingController.text.trim();
    if (target.isEmpty) {
      context.showSnackBar(_s.pingInputIP);
      return;
    }

    if (_serverProvider.servers.isEmpty) {
      context.showSnackBar(_s.pingNoServer);
      return;
    }

    /// avoid ping command injection
    if (!targetReg.hasMatch(target)) {
      context.showSnackBar(_s.pingInputIP);
      return;
    }

    await Future.wait(_serverProvider.servers.values.map((e) async {
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

  @override
  Future<FutureOr<void>> afterFirstLayout(BuildContext context) async {
    if (_serverProvider.servers.isEmpty) {
      await _serverProvider.loadLocalData();
      await _serverProvider.refreshData();
    }
  }
}
