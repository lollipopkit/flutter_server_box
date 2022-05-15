import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/ping_result.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class PingPage extends StatefulWidget {
  const PingPage({Key? key}) : super(key: key);

  @override
  _PingPageState createState() => _PingPageState();
}

class _PingPageState extends State<PingPage>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _textEditingController;
  late MediaQueryData _media;
  final List<PingResult> _results = [];
  late S s;
  static const summaryTextStyle = TextStyle(
    fontSize: 12,
  );

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: GestureDetector(
        child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Column(children: [
              const SizedBox(height: 13),
              buildInput(context, _textEditingController,
                  maxLines: 1, onSubmitted: (_) => doPing()),
              _buildControl(),
              SizedBox(
                width: double.infinity,
                height: _media.size.height * 0.6,
                child: ListView.builder(
                    controller: ScrollController(),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return _buildResultItem(result);
                    }),
              ),
            ])),
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      ),
    );
  }

  Widget _buildResultItem(PingResult result) {
    final unknown = s.unknown;
    final ms = s.ms;
    return RoundRectCard(ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
      title: Text(result.serverName,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
      subtitle: Text(
        _buildPingSummary(result, unknown, ms),
        style: summaryTextStyle,
      ),
      trailing: Text(
          '${s.pingAvg}${result.statistic?.avg?.toStringAsFixed(2) ?? s.unknown} $ms',
          style: TextStyle(fontSize: 14, color: primaryColor)),
    ));
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
    _results.clear();
    final target = _textEditingController.text.trim();
    if (target.isEmpty) {
      showSnackBar(context, Text(s.pingInputIP));
      return;
    }

    await Future.wait(locator<ServerProvider>().servers.map((e) async {
      if (e.client == null) {
        return;
      }
      final result = await e.client!.run('ping -c 3 $target').string;
      _results.add(PingResult.parse(e.info.name, result));
      setState(() {});
    }));
  }

  Widget _buildControl() {
    return SizedBox(
      height: 57,
      child: RoundRectCard(
        InkWell(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(primaryColor)),
                child: Row(
                  children: [
                    const Icon(Icons.delete),
                    const SizedBox(
                      width: 7,
                    ),
                    Text(s.clear)
                  ],
                ),
                onPressed: () {
                  _results.clear();
                  setState(() {});
                },
              ),
              TextButton(
                style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(primaryColor)),
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow),
                    const SizedBox(
                      width: 7,
                    ),
                    Text(s.start)
                  ],
                ),
                onPressed: () {
                  try {
                    doPing();
                  } catch (e) {
                    showSnackBar(context, Text('Error: \n$e'));
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
