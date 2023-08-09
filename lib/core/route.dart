import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/analysis.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';

import 'utils/ui.dart';

class AppRoute {
  final Widget page;
  final String title;

  AppRoute(this.page, this.title);

  Future<T?> go<T>(BuildContext context) {
    Analysis.recordView(title);
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<T?> checkClientAndGo<T>({
    required BuildContext context,
    required S s,
    required String id,
  }) {
    final server = locator<ServerProvider>().servers[id];
    if (server == null || server.client == null) {
      showSnackBar(context, Text(s.waitConnection));
      return Future.value(null);
    }
    return go(context);
  }
}
