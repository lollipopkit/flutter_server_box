import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

/// The args class for [AppRouteArg].
final class SpiRequiredArgs {
  /// The only required argument for this class.
  final Spi spi;

  const SpiRequiredArgs(this.spi);
}

class AppRoutes {
  final Widget page;
  final String title;

  AppRoutes(this.page, this.title);

  Future<T?> go<T>(BuildContext context) {
    return Navigator.push<T>(
      context,
      Stores.setting.cupertinoRoute.fetch()
          ? CupertinoPageRoute(builder: (context) => page)
          : MaterialPageRoute(builder: (context) => page),
    );
  }
}
