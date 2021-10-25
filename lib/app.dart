import 'package:flutter/material.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/home.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
        valueListenable: locator<SettingStore>().primaryColor.listenable(),
        builder: (_, value, __) {
          final primaryColor = Color(value);
          return MaterialApp(
            title: 'ToolBox',
            theme: ThemeData(
              primaryColor: primaryColor,
              appBarTheme: AppBarTheme(backgroundColor: primaryColor),
              floatingActionButtonTheme:
                  FloatingActionButtonThemeData(backgroundColor: primaryColor),
              iconTheme: IconThemeData(color: primaryColor),
              primaryIconTheme: IconThemeData(color: primaryColor),
            ),
            darkTheme: ThemeData.dark().copyWith(primaryColor: primaryColor),
            home: MyHomePage(primaryColor: primaryColor),
          );
        });
  }
}
