import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/home.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  MaterialStateProperty<Color?> getMaterialStateColor(Color primaryColor) {
    return MaterialStateProperty.resolveWith((states) {
      const Set<MaterialState> interactiveStates = <MaterialState>{
        MaterialState.pressed,
        MaterialState.hovered,
        MaterialState.focused,
        MaterialState.selected
      };
      if (states.any(interactiveStates.contains)) {
        return primaryColor;
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
        valueListenable: locator<SettingStore>().primaryColor.listenable(),
        builder: (_, value, __) {
          final primaryColor = Color(value);
          final textStyle = TextStyle(color: primaryColor);
          return MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            title: BuildData.name,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: primaryColor,
              appBarTheme: AppBarTheme(backgroundColor: primaryColor),
              floatingActionButtonTheme:
                  FloatingActionButtonThemeData(backgroundColor: primaryColor),
              iconTheme: IconThemeData(color: primaryColor),
              primaryIconTheme: IconThemeData(color: primaryColor),
              switchTheme: SwitchThemeData(
                thumbColor: getMaterialStateColor(primaryColor),
                trackColor:
                    getMaterialStateColor(primaryColor.withOpacity(0.7)),
              ),
              buttonTheme: ButtonThemeData(splashColor: primaryColor),
              inputDecorationTheme: InputDecorationTheme(
                  labelStyle: textStyle,
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: primaryColor))),
              radioTheme: RadioThemeData(
                fillColor: getMaterialStateColor(primaryColor),
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
                primaryColor: primaryColor,
                floatingActionButtonTheme: FloatingActionButtonThemeData(
                    backgroundColor: primaryColor),
                iconTheme: IconThemeData(color: primaryColor),
                primaryIconTheme: IconThemeData(color: primaryColor),
                switchTheme: SwitchThemeData(
                  thumbColor: getMaterialStateColor(primaryColor),
                  trackColor:
                      getMaterialStateColor(primaryColor.withOpacity(0.7)),
                ),
                buttonTheme: ButtonThemeData(splashColor: primaryColor),
                inputDecorationTheme: InputDecorationTheme(
                    labelStyle: textStyle,
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: primaryColor))),
                radioTheme: RadioThemeData(
                    fillColor: getMaterialStateColor(primaryColor))),
            home: MyHomePage(primaryColor: primaryColor),
          );
        });
  }
}
