import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/locale.dart';
import 'package:toolbox/view/page/full_screen.dart';

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
    final fullScreen = _setting.fullScreen.fetch()!;

    return ValueListenableBuilder<int>(
      valueListenable: _setting.themeMode.listenable(),
      builder: (_, tMode, __) {
        final isAMOLED = tMode >= 0 && tMode <= ThemeMode.values.length - 1;
        // Issue #57
        // if not [ok] -> [AMOLED] mode, use [ThemeMode.dark]
        final themeMode = isAMOLED ? ThemeMode.values[tMode] : ThemeMode.dark;
        final locale = _setting.locale.fetch()?.toLocale;
        final darkTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: primaryColor,
        );

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
          darkTheme: isAMOLED ? darkTheme : _getAmoledTheme(darkTheme),
          home: fullScreen ? const FullScreenPage() : const HomePage(),
        );
      },
    );
  }
}

ThemeData _getAmoledTheme(ThemeData darkTheme) => darkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      dialogBackgroundColor: Colors.black,
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.black),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      dialogTheme: const DialogTheme(backgroundColor: Colors.black),
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: Colors.black),
      listTileTheme: const ListTileThemeData(tileColor: Colors.black12),
      cardTheme: const CardTheme(color: Colors.black12),
      navigationBarTheme:
          const NavigationBarThemeData(backgroundColor: Colors.black),
      popupMenuTheme: const PopupMenuThemeData(color: Colors.black),
    );
