import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/locale.dart';

import 'core/utils/ui.dart';
import 'data/res/build_data.dart';
import 'data/res/color.dart';
import 'data/store/setting.dart';
import 'locator.dart';
import 'view/page/home.dart';

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  final _setting = locator<SettingStore>();

  @override
  Widget build(BuildContext context) {
    setTransparentNavigationBar(context);
    primaryColor = Color(_setting.primaryColor.fetch()!);

    return ValueListenableBuilder<int>(
      valueListenable: _setting.themeMode.listenable(),
      builder: (_, tMode, __) {
        final ok = tMode >= 0 && tMode <= ThemeMode.values.length - 1;
        final themeMode = ok ? ThemeMode.values[tMode] : ThemeMode.system;
        final localeStr = _setting.locale.fetch();
        final locale = localeStr?.toLocale;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          title: BuildData.name,
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: primaryColor,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: primaryColor,
          ),
          home: const HomePage(),
        );
      },
    );
  }
}
