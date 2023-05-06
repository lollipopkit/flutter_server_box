import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '/core/extension/colorx.dart';
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

    final primarySwatch = primaryColor.materialColor;

    return ValueListenableBuilder<int>(
      valueListenable: _setting.themeMode.listenable(),
      builder: (_, tMode, __) {
        final ok = tMode >= 0 && tMode <= ThemeMode.values.length - 1;
        final themeMode = ok ? ThemeMode.values[tMode] : ThemeMode.system;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          title: BuildData.name,
          themeMode: themeMode,
          theme: ThemeData.light(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: primarySwatch,
              accentColor: primaryColor,
            ),
            switchTheme: ThemeData.light(useMaterial3: true).switchTheme,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSwatch(
              brightness: Brightness.dark,
              primarySwatch: primarySwatch,
              accentColor: primaryColor,
            ),
          ),
          home: const MyHomePage(),
        );
      },
    );
  }
}
