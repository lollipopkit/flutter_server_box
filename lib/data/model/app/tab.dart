import 'package:flutter/material.dart';
import 'package:toolbox/view/page/ping.dart';
import 'package:toolbox/view/page/server/tab.dart';
import 'package:toolbox/view/page/snippet/list.dart';

enum AppTab {
  server,
  snippet,
  ping;

  Widget get page {
    switch (this) {
      case server:
        return const ServerPage();
      case snippet:
        return const SnippetListPage();
      case ping:
        return const PingPage();
    }
  }
}
