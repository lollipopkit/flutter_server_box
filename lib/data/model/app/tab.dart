import 'package:flutter/material.dart';
import 'package:server_box/view/page/ping.dart';
import 'package:server_box/view/page/server/tab.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/ssh/tab.dart';

enum AppTab {
  server,
  ssh,
  snippet,
  ping,
  ;

  Widget get page {
    switch (this) {
      case server:
        return const ServerPage();
      case snippet:
        return const SnippetListPage();
      case ssh:
        return const SSHTabPage();
      case ping:
        return const PingPage();
    }
  }
}
