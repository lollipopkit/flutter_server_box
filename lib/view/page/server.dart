import 'package:after_layout/after_layout.dart';
import 'package:charts_flutter/flutter.dart' as chart;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:ssh2/ssh2.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/disk_info.dart';
import 'package:toolbox/data/model/server_private_info.dart';
import 'package:toolbox/data/model/server_status.dart';
import 'package:toolbox/data/model/tcp_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/circle_pie.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin {
  late MediaQueryData _media;
  late ThemeData _theme;
  bool useKey = false;

  final nameController = TextEditingController();
  final ipController = TextEditingController();
  final portController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final keyController = TextEditingController();
  final ipFocusNode = FocusNode();
  final portFocusNode = FocusNode();
  final usernameFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();

  late ServerProvider serverProvider;
  final cachedServerStatus = <ServerStatus?>[];

  @override
  void initState() {
    super.initState();
    serverProvider = locator<ServerProvider>();
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
              child: Consumer<ServerProvider>(builder: (_, pro, __) {
            return Column(
                children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 377),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: [
                const SizedBox(height: 13),
                ...pro.servers
                    .map((e) => _buildEachServerCard(e, pro.servers.indexOf(e)))
              ],
            ));
          })),
        ),
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showRoundDialog(context, '新建服务器连接', _buildTextInputField(context), [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭')),
            TextButton(
                onPressed: () {
                  final authorization = keyController.text.isEmpty
                      ? passwordController.text
                      : {
                          "privateKey": keyController.text,
                          "passphrase": passwordController.text
                        };
                  serverProvider.addServer(ServerPrivateInfo(
                      name: nameController.text,
                      ip: ipController.text,
                      port: int.parse(portController.text),
                      user: usernameController.text,
                      authorization: authorization));
                  nameController.clear();
                  ipController.clear();
                  portController.clear();
                  usernameController.clear();
                  passwordController.clear();
                  keyController.clear();
                  Navigator.of(context).pop();
                },
                child: const Text('连接'))
          ]);
        },
        tooltip: 'add a server',
        heroTag: 'server page fab',
        child: const Icon(Icons.add),
      ),
    );
  }

  InputDecoration _buildDecoration(String label, {TextStyle? textStyle}) {
    return InputDecoration(labelText: label, labelStyle: textStyle);
  }

  Widget _buildTextInputField(BuildContext ctx) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            keyboardType: TextInputType.text,
            decoration: _buildDecoration('名称'),
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(ipFocusNode),
          ),
          TextField(
            controller: ipController,
            focusNode: ipFocusNode,
            keyboardType: TextInputType.text,
            decoration: _buildDecoration('IP'),
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(usernameFocusNode),
          ),
          TextField(
            controller: portController,
            focusNode: portFocusNode,
            keyboardType: TextInputType.number,
            decoration: _buildDecoration('Port'),
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(usernameFocusNode),
          ),
          TextField(
            controller: usernameController,
            focusNode: usernameFocusNode,
            keyboardType: TextInputType.text,
            decoration: _buildDecoration('用户名'),
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(passwordFocusNode),
          ),
          TextField(
            controller: keyController,
            keyboardType: TextInputType.text,
            decoration: _buildDecoration('密钥(可选)'),
            onSubmitted: (_) => {},
          ),
          TextField(
            controller: passwordController,
            focusNode: passwordFocusNode,
            obscureText: true,
            keyboardType: TextInputType.text,
            decoration: _buildDecoration('密码'),
            onSubmitted: (_) => {},
          ),
        ],
      ),
    );
  }

  Future<ServerStatus>? _getData(ServerPrivateInfo info) async {
    final client = SSHClient(
      host: info.ip!,
      port: info.port!,
      username: info.user!,
      passwordOrKey: info.authorization,
    );

    await client.connect();
    final cpu = await client.execute(
            "top -bn1 | grep load | awk '{printf \"%.2f\", \$(NF-2)}'") ??
        '0';
    final mem = await client.execute('free -m') ?? '';
    final sysVer = await client.execute('cat /etc/issue.net') ?? 'Unkown';
    final upTime = await client.execute('uptime') ?? 'Failed';
    final disk = await client.execute('df -h') ?? 'Failed';
    final tcp = await client.execute('cat /proc/net/snmp') ?? 'Failed';

    return ServerStatus(
        cpuPercent: double.parse(cpu.trim()),
        memList: _getMem(mem),
        sysVer: sysVer.trim(),
        disk: _getDisk(disk),
        uptime: _getUpTime(upTime),
        tcp: _getTcp(tcp));
  }

  String _getUpTime(String raw) {
    return raw.split('up ')[1].split(', ')[0];
  }

  TcpStatus _getTcp(String raw) {
    final lines = raw.split('\n');
    int idx = 0;
    for (var item in lines) {
      if (item.contains('Tcp:')) {
        idx++;
      }
      if (idx == 2) {
        final vals = item.split(RegExp(r'\s{1,}'));
        return TcpStatus(
            maxConn: vals[5].i,
            active: vals[6].i,
            passive: vals[7].i,
            fail: vals[8].i);
      }
    }
    return TcpStatus(maxConn: 0, active: 0, passive: 0, fail: 0);
  }

  List<DiskInfo> _getDisk(String disk) {
    final list = <DiskInfo>[];
    final items = disk.split('\n');
    for (var item in items) {
      if (items.indexOf(item) == 0 || item.isEmpty) {
        continue;
      }
      final vals = item.split(RegExp(r'\s{1,}'));
      list.add(DiskInfo(
          mountPath: vals[1],
          mountLocation: vals[5],
          usedPercent: double.parse(vals[4].replaceFirst('%', '')),
          used: vals[2],
          size: vals[1],
          avail: vals[3]));
    }
    return list;
  }

  List<int> _getMem(String mem) {
    for (var item in mem.split('\n')) {
      if (item.contains('Mem:')) {
        return RegExp(r'[1-9][0-9]*')
            .allMatches(item)
            .map((e) => int.parse(item.substring(e.start, e.end)))
            .toList();
      }
    }
    return [];
  }

  Widget _buildEachServerCard(ServerPrivateInfo e, int index) {
    return FutureBuilder<ServerStatus>(
      future: _getData(e),
      builder: (BuildContext context, AsyncSnapshot<ServerStatus> snapshot) {
        return GestureDetector(
          child: _buildEachCardContent(snapshot, e.name ?? '', index),
          onLongPress: () =>
              showRoundDialog(context, '是否删除', const Text('删除后无法恢复'), [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('否')),
            TextButton(
                onPressed: () {
                  serverProvider.delServer(e);
                  Navigator.of(context).pop();
                },
                child: const Text('是'))
          ]),
        );
      },
    );
  }

  Widget _buildEachCardContent(
      AsyncSnapshot<ServerStatus> snapshot, String serverName, int index) {
    Widget child;
    if (snapshot.connectionState != ConnectionState.done) {
      if (cachedServerStatus.length > index && cachedServerStatus.elementAt(index) != null) {
          child = _buildRealServerCard(cachedServerStatus.elementAt(index)!, serverName);
      } else {
        child = _buildRealServerCard(
            ServerStatus(
                cpuPercent: 0,
                memList: [100, 0],
                disk: [
                  DiskInfo(
                      mountLocation: '',
                      mountPath: '',
                      used: '',
                      size: '',
                      avail: '',
                      usedPercent: 0)
                ],
                sysVer: '',
                uptime: '',
                tcp: TcpStatus(maxConn: 0, active: 0, passive: 0, fail: 0)),
            serverName);
      }
    } else if (snapshot.hasError) {
      child = Column(
        children: [
          Text(
            serverName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Center(
            child: Text("Error: ${snapshot.error}"),
          )
        ],
      );
    } else {
      if (cachedServerStatus.length <= index) {
        cachedServerStatus.add(snapshot.data!);
      } else {
        cachedServerStatus[index] = snapshot.data!;
      }
      child = _buildRealServerCard(snapshot.data!, serverName);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: child,
      ),
    );
  }

  Widget _buildRealServerCard(ServerStatus ss, String serverName) {
    final cpuData = [
      IndexPercent(0, ss.cpuPercent!.toInt()),
      IndexPercent(1, 100 - ss.cpuPercent!.toInt()),
    ];
    final memData = <IndexPercent>[];
    for (var e in ss.memList!) {
      memData.add(IndexPercent(ss.memList!.indexOf(e), e!.toInt()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              serverName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(ss.uptime!,
                style: TextStyle(
                    color: _theme.textTheme.bodyText1!.color!.withAlpha(100)))
          ],
        ),
        const SizedBox(
          height: 13,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPercentCircle(ss.cpuPercent!, 'CPU', [
              chart.Series<IndexPercent, int>(
                id: 'CPU',
                domainFn: (IndexPercent cpu, _) => cpu.id,
                measureFn: (IndexPercent cpu, _) => cpu.percent,
                data: cpuData,
              )
            ]),
            _buildPercentCircle(
                ss.memList![1]! / ss.memList![0]! * 100, 'Mem', [
              chart.Series<IndexPercent, int>(
                id: 'Mem',
                domainFn: (IndexPercent sales, _) => sales.id,
                measureFn: (IndexPercent sales, _) => sales.percent,
                data: memData,
              )
            ]),
            _buildIOData('Net', ss.tcp!.maxConn!.toString(), '0kb/s'),
            _buildIOData('Disk', '0kb/s', '0kb/s')
          ],
        )
      ],
    );
  }

  Widget _buildIOData(String title, String up, String down) {
    return SizedBox(
      width: _media.size.width * 0.2,
      height: _media.size.height * 0.1,
      child: Stack(
        children: [
          Positioned(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '↓$up',
                  textAlign: TextAlign.start,
                ),
                Text(
                  '↑$down',
                  textAlign: TextAlign.center,
                )
              ],
            ),
            top: _media.size.height * 0.012,
            left: 0,
            right: 0,
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

  Widget _buildPercentCircle(double percent, String title,
      List<chart.Series<IndexPercent, int>> series) {
    return SizedBox(
      width: _media.size.width * 0.2,
      height: _media.size.height * 0.1,
      child: Stack(
        children: [
          DonutPieChart(series),
          Positioned(
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
            ),
            left: 0,
            right: 0,
            top: _media.size.height * 0.03,
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

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    await GetIt.I.allReady();
    await locator<ServerProvider>().loadData();
  }
}
