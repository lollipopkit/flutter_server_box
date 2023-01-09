import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toolbox/core/extension/colorx.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/home.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    setTransparentNavigationBar(context);
    return ValueListenableBuilder<int>(
        valueListenable: locator<SettingStore>().primaryColor.listenable(),
        builder: (_, value, __) {
          final primaryColor = Color(value);
          final textStyle = TextStyle(color: primaryColor);
          final materialColor = primaryColor.materialStateColor;
          final materialColorAlpha =
              primaryColor.withOpacity(0.7).materialStateColor;
          return MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: S.delegate.supportedLocales,
            title: BuildData.name,
            theme: ThemeData(
              primaryColor: primaryColor,
              appBarTheme: AppBarTheme(backgroundColor: primaryColor),
              floatingActionButtonTheme:
                  FloatingActionButtonThemeData(backgroundColor: primaryColor),
              iconTheme: IconThemeData(color: primaryColor),
              primaryIconTheme: IconThemeData(color: primaryColor),
              switchTheme: SwitchThemeData(
                thumbColor: materialColor,
                trackColor: materialColorAlpha,
              ),
              buttonTheme: ButtonThemeData(splashColor: primaryColor),
              inputDecorationTheme: InputDecorationTheme(
                labelStyle: textStyle,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
              radioTheme: RadioThemeData(
                fillColor: materialColor,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: primaryColor,
              floatingActionButtonTheme:
                  FloatingActionButtonThemeData(backgroundColor: primaryColor),
              iconTheme: IconThemeData(color: primaryColor),
              primaryIconTheme: IconThemeData(color: primaryColor),
              switchTheme: SwitchThemeData(
                thumbColor: materialColor,
                trackColor: materialColorAlpha,
              ),
              buttonTheme: ButtonThemeData(splashColor: primaryColor),
              inputDecorationTheme: InputDecorationTheme(
                labelStyle: textStyle,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
              radioTheme: RadioThemeData(
                fillColor: materialColor,
              ),
            ),
            home: MyHomePage(primaryColor: primaryColor),
          );
        });
  }
}
