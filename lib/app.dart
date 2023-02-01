import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '/core/extension/colorx.dart';
import 'core/utils/ui.dart';
import 'data/res/build_data.dart';
import 'data/res/color.dart';
import 'data/store/setting.dart';
import 'generated/l10n.dart';
import 'locator.dart';
import 'view/page/home.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    setTransparentNavigationBar(context);
    return ValueListenableBuilder<int>(
      valueListenable: locator<SettingStore>().primaryColor.listenable(),
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
        final iconBtnTheme = IconButtonThemeData(
            style: ButtonStyle(
          iconColor: primaryColor.materialStateColor,
        ));

        return MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: S.delegate.supportedLocales,
          title: BuildData.name,
          theme: ThemeData(
            useMaterial3: false,
            primaryColor: primaryColor,
            primarySwatch: primaryColor.materialColor,
            appBarTheme: appBarTheme,
            floatingActionButtonTheme: fabTheme,
            iconTheme: iconTheme,
            iconButtonTheme: iconBtnTheme,
            primaryIconTheme: iconTheme,
            switchTheme: switchTheme,
            inputDecorationTheme: inputDecorationTheme,
            radioTheme: radioTheme,
          ),
          darkTheme: ThemeData.dark().copyWith(
            useMaterial3: false,
            floatingActionButtonTheme: fabTheme,
            iconTheme: iconTheme,
            iconButtonTheme: iconBtnTheme,
            primaryIconTheme: iconTheme,
            switchTheme: switchTheme,
            inputDecorationTheme: inputDecorationTheme,
            radioTheme: radioTheme,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: primaryColor.materialColor,
              brightness: Brightness.dark,
              accentColor: primaryColor
            )
          ),
          home: const MyHomePage(),
        );
      },
    );
  }
}
