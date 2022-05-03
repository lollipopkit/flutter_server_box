import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/ping_result.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/color.dart';
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

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
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
              buildInput(context, _textEditingController, maxLines: 1),
              _buildControl(),
              SizedBox(
                width: double.infinity,
                height: _media.size.height * 0.6,
                child: ListView.builder(
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
    return RoundRectCard(ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
      title: Text(result.serverName,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
      subtitle: Text(_buildPingSummary(result)),
      trailing: Text(
          'Avg: ' +
              (result.statistic?.avg?.toStringAsFixed(2) ?? 'unkown') +
              ' ms',
          style: TextStyle(fontSize: 14, color: primaryColor)),
    ));
  }

  String _buildPingSummary(PingResult result) {
    final ip = result.ip ?? 'unkown';
    final ttl = result.results?.first.ttl ?? 'unkown';
    final loss = result.statistic?.loss ?? 'unkown';
    final min = result.statistic?.min ?? 'unkown';
    final max = result.statistic?.max ?? 'unkown';
    return '$ip\nttl: $ttl, loss: $loss%\nmin: $min ms, max: $max ms';
  }

  Future<void> doPing() async {
    _results.clear();
    final target = _textEditingController.text.trim();
    if (target.isEmpty) {
      showSnackBar(context, const Text('Please input a target'));
      return;
    }
    for (var si in locator<ServerProvider>().servers) {
      if (si.client == null) {
        continue;
      }
      final result = await si.client!.run('ping -c 3 $target').string;
      _results.add(PingResult.parse(si.info.name, result));
      setState(() {});
    }
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
                  children: const [
                    Icon(Icons.stop),
                    SizedBox(
                      width: 7,
                    ),
                    Text('Clear')
                  ],
                ),
                onPressed: () {
                  _results.clear();
                },
              ),
              TextButton(
                style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(primaryColor)),
                child: Row(
                  children: const [
                    Icon(Icons.play_arrow),
                    SizedBox(
                      width: 7,
                    ),
                    Text('Start')
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
