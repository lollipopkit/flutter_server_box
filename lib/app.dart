import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/utils/misc.dart';

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
    final fontName = getFileName(_setting.fontPath.fetch());
    return ValueListenableBuilder<int>(
      valueListenable: _setting.primaryColor.listenable(),
      builder: (_, colorValue, __) {
        primaryColor = Color(colorValue);

        final textStyle = TextStyle(color: primaryColor);
        final materialColor = primaryColor.materialStateColor;
        final materialColorAlpha =
            primaryColor.withOpacity(0.7).materialStateColor;
        final fabTheme =
            FloatingActionButtonThemeData(backgroundColor: primaryColor);
        final switchTheme = SwitchThemeData(
          thumbColor: materialColor,
          trackColor: materialColorAlpha,
        );
        final appBarTheme = AppBarTheme(backgroundColor: primaryColor);
        final iconTheme = IconThemeData(color: primaryColor);
        final inputDecorationTheme = InputDecorationTheme(
          labelStyle: textStyle,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: primaryColor),
          ),
        );
        final radioTheme = RadioThemeData(
          fillColor: materialColor,
        );
        return ValueListenableBuilder<int>(
          valueListenable: _setting.themeMode.listenable(),
          builder: (_, tMode, __) {
            final ok = tMode >= 0 && tMode <= ThemeMode.values.length - 1;
            final themeMode = ok ? ThemeMode.values[tMode] : ThemeMode.system;

            final theme = ThemeData(
              useMaterial3: false,
              fontFamily: fontName,
              primaryColor: primaryColor,
              primarySwatch: primaryColor.materialColor,
              appBarTheme: appBarTheme,
              floatingActionButtonTheme: fabTheme,
              iconTheme: iconTheme,
              primaryIconTheme: iconTheme,
              switchTheme: switchTheme,
              inputDecorationTheme: inputDecorationTheme,
              radioTheme: radioTheme,
            );

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              title: BuildData.name,
              themeMode: themeMode,
              theme: theme,
              darkTheme: theme.copyWith(
                colorScheme: ColorScheme.fromSwatch(
                  primarySwatch: primaryColor.materialColor,
                  brightness: Brightness.dark,
                  accentColor: primaryColor,
                ),
              ),
              home: const MyHomePage(),
            );
          },
        );
      },
    );
  }
}
