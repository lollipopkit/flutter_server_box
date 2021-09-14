import 'package:charts_flutter/flutter.dart' as chart;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:ssh2/ssh2.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/view/widget/circle_pie.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage>
    with AutomaticKeepAliveClientMixin {
  late MediaQueryData _media;
  late ThemeData _theme;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _theme = Theme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: GestureDetector(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: AnimationLimiter(
              child: Column(
                  children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 377),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [const SizedBox(height: 13), ..._buildServerCards()],
          ))),
        ),
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showSnackBar(context, const Text(''));
        },
        tooltip: 'add a server',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<List<String>>? _getData() async {
    final client = SSHClient(
      host: '',
      port: 0,
      username: '',
      passwordOrKey: '',
    );
    await client.connect();
    final cpu = await client.execute(
            "top -bn1 | grep load | awk '{printf \"%.2f\", \$(NF-2)}'") ??
        'failed';
    final mem = await client
            .execute("free -m | awk 'NR==2{printf \"%s/%sMB\", \$3,\$2}'") ??
        'failed';
    return [cpu.trim(), mem.trim()];
  }

  Widget _buildEachServerCard() {
    return FutureBuilder<List<String>>(
      future: _getData(),
      builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Text("Error: ${snapshot.error}");
          } else {
            return _buildEachCardContent(snapshot);
          }
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }

  Widget _buildEachCardContent(AsyncSnapshot snapshot) {
    final cpuPercent = double.parse(snapshot.data![0]) * 100;
    final memSplit = snapshot.data![1].replaceFirst('MB', '').split('/');
    final memPercent = int.parse(memSplit[0]) / int.parse(memSplit[1]) * 100;
    final cpuData = [
      IndexPercent(0, cpuPercent.toInt()),
    ];
    final memData = [
      IndexPercent(0, memPercent.toInt()),
    ];
    return Card(
      child: Padding(padding:const EdgeInsets.all(13) , child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(' Jilin', style: TextStyle(fontWeight: FontWeight.bold),), 
          const SizedBox(height: 7,),
          Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPercentCircle(cpuPercent, 'CPU', [
          chart.Series<IndexPercent, int>(
            id: 'CPU',
            domainFn: (IndexPercent cpu, _) => cpu.id,
            measureFn: (IndexPercent cpu, _) => cpu.percent,
            data: cpuData,
          )
        ]),
        _buildPercentCircle(memPercent, 'MEM', [
          chart.Series<IndexPercent, int>(
            id: 'MEM',
            domainFn: (IndexPercent sales, _) => sales.id,
            measureFn: (IndexPercent sales, _) => sales.percent,
            data: memData,
          )
        ])
      ],
    )
        ],
      ),),
    );
  }

  Widget _buildPercentCircle(
      double percent, String title, List<chart.Series<IndexPercent, int>> series) {
    return SizedBox(
      width: _media.size.width * 0.2,
      height: _media.size.height * 0.1,
      child: Stack(
        children: [
          DonutPieChart.withRandomData(),
          Positioned(
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
            ),
            left: 0,
            right: 0,
            top: 0,
            bottom: 0
          ),
          Positioned(
              child: Text(title, textAlign: TextAlign.center),
              bottom: 0,
              left: 0,
              right: 0)
        ],
      ),
    );
  }

  List<Widget> _buildServerCards() {
    return [_buildEachServerCard()];
  }

  @override
  bool get wantKeepAlive => true;
}
