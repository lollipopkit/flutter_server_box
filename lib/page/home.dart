import 'package:flutter/material.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/page/convert.dart';
import 'package:toolbox/page/debug.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final List<String> _tabs = ['编码', 'Ping', '1', '2', '3'];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () =>
              AppRoute(const DebugPage(), 'Debug Page').go(context),
          child: Text(widget.title),
        ),
        bottom: TabBar(
          tabs: _tabs.map((e) => Tab(text: e)).toList(),
          controller: _tabController,
        ),
      ),
      body: TabBarView(controller: _tabController, children: const [
        EncodePage(),
        EncodePage(),
        EncodePage(),
        EncodePage(),
        EncodePage()
      ]),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
