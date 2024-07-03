import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/l10n/gen_l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/rebuild.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/home/home.dart';
import 'package:icons_plus/icons_plus.dart';

part 'intro.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    _setup(context);
    return ListenableBuilder(
      listenable: RNodes.app,
      builder: (context, _) {
        if (!Stores.setting.useSystemPrimaryColor.fetch()) {
          UIs.colorSeed = Color(Stores.setting.primaryColor.fetch());
          return _buildApp(context);
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
              UIs.primaryColor = light.primary;
            } else if (!context.isDark && dark != null) {
              UIs.primaryColor = dark.primary;
            }
            return _buildApp(context, light: lightTheme, dark: darkTheme);
          },
        );
      },
    );
  }

  Widget _buildApp(BuildContext ctx, {ThemeData? light, ThemeData? dark}) {
    final tMode = Stores.setting.themeMode.fetch();
    // Issue #57
    final themeMode = switch (tMode) {
      1 || 2 => ThemeMode.values[tMode],
      3 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final locale = Stores.setting.locale.fetch().toLocale;

    light = (light ??
            ThemeData(
              useMaterial3: true,
              colorSchemeSeed: UIs.colorSeed,
            ))
        .useSystemChineseFont(Brightness.light);
    dark = (dark ??
            ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorSchemeSeed: UIs.colorSeed,
            ))
        .useSystemChineseFont(Brightness.dark);

    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: LocaleUtil.resolve,
      title: BuildData.name,
      themeMode: themeMode,
      theme: light,
      darkTheme: tMode < 3 ? dark : dark.toAmoled,
      home: Builder(
        builder: (context) {
          context.setLibL10n();
          final appL10n = AppLocalizations.of(context);
          if (appL10n != null) l10n = appL10n;

          final intros = _IntroPage.builders;
          if (intros.isNotEmpty) {
            return _IntroPage(intros);
          }

          return const HomePage();
        },
      ),
    );
  }
}

void _setup(BuildContext context) async {
  SystemUIs.setTransparentNavigationBar(context);
}
