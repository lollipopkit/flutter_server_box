import 'package:flutter/material.dart';
import 'package:toolbox/view/page/server/tab.dart';
import 'package:toolbox/view/page/snippet/list.dart';
import 'package:toolbox/view/page/ssh/tab.dart';

enum AppTab {
  server,
  ssh,
  snippet,
  ;

  Widget get page {
    switch (this) {
      case server:
        return const ServerPage();
      case snippet:
        return const SnippetListPage();
      case ssh:
        return const SSHTabPage();
    }
  }
}
