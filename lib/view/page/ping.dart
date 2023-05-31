import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../../core/extension/uint8list.dart';
import '../../core/utils/ui.dart';
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
  late MediaQueryData _media;
  final List<PingResult> _results = [];
  final _serverProvider = locator<ServerProvider>();
  late S s;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    s = S.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Column(
          children: [
            height13,
            Input(
              controller: _textEditingController,
              hint: s.inputDomainHere,
              maxLines: 1,
              onSubmitted: (_) => doPing(),
            ),
            SizedBox(
              width: double.infinity,
              height: _media.size.height * 0.6,
              child: ListView.builder(
                controller: ScrollController(),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return _buildResultItem(result);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'ping',
        onPressed: () {
          try {
            doPing();
          } catch (e) {
            showSnackBar(context, Text('Error: \n$e'));
            rethrow;
          }
        },
        child: const Icon(Icons.play_arrow),
      ),
    );
  }

  Widget _buildResultItem(PingResult result) {
    final unknown = s.unknown;
    final ms = s.ms;
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
          style: textSize11,
        ),
        trailing: Text(
          '${s.pingAvg}${result.statistic?.avg?.toStringAsFixed(2) ?? s.unknown} $ms',
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
      return '$ip - ${s.noResult}';
    }
    final ttl = result.results?.first.ttl ?? unknown;
    final loss = result.statistic?.loss ?? unknown;
    final min = result.statistic?.min ?? unknown;
    final max = result.statistic?.max ?? unknown;
    return '$ip\n${s.ttl}: $ttl, ${s.loss}: $loss%\n${s.min}: $min $ms, ${s.max}: $max $ms';
  }

  Future<void> doPing() async {
    FocusScope.of(context).requestFocus(FocusNode());
    _results.clear();
    final target = _textEditingController.text.trim();
    if (target.isEmpty) {
      showSnackBar(context, Text(s.pingInputIP));
      return;
    }

    if (_serverProvider.servers.isEmpty) {
      showSnackBar(context, Text(s.pingNoServer));
      return;
    }

    /// avoid ping command injection
    if (!targetReg.hasMatch(target)) {
      showSnackBar(context, Text(s.pingInputIP));
      return;
    }

    await Future.wait(_serverProvider.servers.values.map((e) async {
      if (e.client == null) {
        return;
      }
      final result = await e.client!.run('ping -c 3 $target').string;
      _results.add(PingResult.parse(e.spi.name, result));
      setState(() {});
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
