import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/analysis.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/locale.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/rebuild.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/page/home/home.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    _setup(context);
    return ListenableBuilder(
      listenable: RebuildNodes.app,
      builder: (_, __) {
        if (!Stores.setting.useSystemPrimaryColor.fetch()) {
          primaryColor = Color(Stores.setting.primaryColor.fetch());
          return _buildApp();
        }
        return DynamicColorBuilder(
          builder: (light, dark) {
            final lightTheme = ThemeData(
              useMaterial3: true,
              colorScheme: light,
            );
            final darkTheme = ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: dark,
            );
            if (context.isDark && light != null) {
              primaryColor = light.primary;
            } else if (!context.isDark && dark != null) {
              primaryColor = dark.primary;
            }
            return _buildApp(light: lightTheme, dark: darkTheme);
          },
        );
      },
    );
  }

  Widget _buildApp({ThemeData? light, ThemeData? dark}) {
    final tMode = Stores.setting.themeMode.fetch();
    // Issue #57
    final themeMode = switch (tMode) {
      1 || 2 => ThemeMode.values[tMode],
      3 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final locale = Stores.setting.locale.fetch().toLocale;

    light ??= ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryColor,
    );
    dark ??= ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: primaryColor,
    );

    return MaterialApp(
      locale: locale,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      title: BuildData.name,
      themeMode: themeMode,
      theme: light,
      darkTheme: tMode < 3 ? dark : _getAmoledTheme(dark),
      home: const HomePage(),
    );
  }
}

void _setup(BuildContext context) async {
  setTransparentNavigationBar(context);
  Analysis.init();
}

ThemeData _getAmoledTheme(ThemeData darkTheme) => darkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      dialogBackgroundColor: Colors.black,
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.black),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      dialogTheme: const DialogTheme(backgroundColor: Colors.black),
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: Colors.black),
      listTileTheme: const ListTileThemeData(tileColor: Colors.transparent),
      cardTheme: const CardTheme(color: Colors.black12),
      navigationBarTheme:
          const NavigationBarThemeData(backgroundColor: Colors.black),
      popupMenuTheme: const PopupMenuThemeData(color: Colors.black),
    );
