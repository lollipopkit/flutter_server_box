import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/locale.dart';
import 'package:toolbox/data/res/rebuild.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/value_notifier.dart';

import 'core/utils/ui.dart';
import 'data/res/build_data.dart';
import 'data/res/color.dart';
import 'view/page/full_screen.dart';
import 'view/page/home.dart';

/// After upgrading to flutter 3.13,
/// the shadow color of the drawer is white (maybe a bug).
/// Only on [iOS].
/// TODO: remember to remove it after the bug is fixed.
const _drawerTheme = DrawerThemeData(
  shadowColor: Colors.black12,
);

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    setTransparentNavigationBar(context);
    final child = _wrapTheme(context);
    if (Stores.setting.useSystemPrimaryColor.fetch()) {
      return _wrapSystemColor(context, child);
    }
    return child;
  }

  Widget _wrapTheme(BuildContext context) {
    return ValueBuilder(
      listenable: RebuildNodes.app,
      build: () {
        final tMode = Stores.setting.themeMode.fetch();
        // Issue #57
        var themeMode = ThemeMode.system;
        switch (tMode) {
          case 1 || 2:
            themeMode = ThemeMode.values[tMode];
            break;
          case 3:
            themeMode = ThemeMode.dark;
            break;
        }
        final locale = Stores.setting.locale.fetch().toLocale;
        final darkTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: primaryColor,
          drawerTheme: _drawerTheme,
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
          darkTheme: tMode < 3 ? darkTheme : _getAmoledTheme(darkTheme),
          home: Stores.setting.fullScreen.fetch()
              ? const FullScreenPage()
              : const HomePage(),
        );
      },
    );
  }

  Widget _wrapSystemColor(BuildContext context, Widget child) {
    return DynamicColorBuilder(builder: (light, dark) {
      if (context.isDark && light != null) {
        primaryColor = light.primary;
      } else if (!context.isDark && dark != null) {
        primaryColor = dark.primary;
      }
      return child;
    });
  }
}

ThemeData _getAmoledTheme(ThemeData darkTheme) => darkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      dialogBackgroundColor: Colors.black,
      drawerTheme: _drawerTheme.copyWith(backgroundColor: Colors.black),
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
