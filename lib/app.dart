import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/home.dart';

part 'intro.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<List<IntroPageBuilder>> _introFuture = _IntroPage.builders;

  @override
  Widget build(BuildContext context) {
    _setup(context);

    Stores.setting.useSystemPrimaryColor.fetch();

    return ListenableBuilder(
      listenable: RNodes.app,
      builder: (context, _) {
        if (!Stores.setting.useSystemPrimaryColor.fetch()) {
          return _build(context);
        }

        return _buildDynamicColor(context);
      },
    );
  }

  Widget _build(BuildContext context) {
    final colorSeed = Color(Stores.setting.colorSeed.fetch());

    UIs.colorSeed = colorSeed;
    UIs.primaryColor = colorSeed;

    return _buildApp(
      context,
      light: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: UIs.colorSeed,
        appBarTheme: AppBarTheme(scrolledUnderElevation: 0.0),
      ),
      dark: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: UIs.colorSeed,
        appBarTheme: AppBarTheme(scrolledUnderElevation: 0.0),
      ),
    );
  }

  Widget _buildDynamicColor(BuildContext context) {
    return DynamicColorBuilder(
      builder: (light, dark) {
        final lightSeed = light?.primary;
        final darkSeed = dark?.primary;

        final lightTheme = ThemeData(
          useMaterial3: true,
          colorSchemeSeed: lightSeed,
          appBarTheme: AppBarTheme(scrolledUnderElevation: 0.0),
        );
        final darkTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: darkSeed,
          appBarTheme: AppBarTheme(scrolledUnderElevation: 0.0),
        );

        if (context.isDark && dark != null) {
          UIs.primaryColor = dark.primary;
          UIs.colorSeed = dark.primary;
        } else if (!context.isDark && light != null) {
          UIs.primaryColor = light.primary;
          UIs.colorSeed = light.primary;
        } else {
          final fallbackColor = Color(Stores.setting.colorSeed.fetch());
          UIs.primaryColor = fallbackColor;
          UIs.colorSeed = fallbackColor;
        }

        return _buildApp(context, light: lightTheme, dark: darkTheme);
      },
    );
  }

  Widget _buildApp(BuildContext ctx, {required ThemeData light, required ThemeData dark}) {
    final tMode = Stores.setting.themeMode.fetch();
    // Issue #57
    final themeMode = switch (tMode) {
      1 || 2 => ThemeMode.values[tMode],
      3 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final locale = Stores.setting.locale.fetch().toLocale;

    return MaterialApp(
      key: ValueKey(locale),
      navigatorKey: AppNavigator.key,
      builder: ResponsivePoints.builder,
      locale: locale,
      localizationsDelegates: const [LibLocalizations.delegate, ...AppLocalizations.localizationsDelegates],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: LocaleUtil.resolve,
      navigatorObservers: [AppRouteObserver.instance],
      title: BuildData.name,
      themeMode: themeMode,
      theme: light.fixWindowsFont,
      darkTheme: (tMode < 3 ? dark : dark.toAmoled).fixWindowsFont,
      home: FutureBuilder<List<IntroPageBuilder>>(
        future: _introFuture,
        builder: (context, snapshot) {
          context.setLibL10n();
          final appL10n = AppLocalizations.of(context);
          if (appL10n != null) l10n = appL10n;

          Widget child;
          if (snapshot.connectionState == ConnectionState.waiting) {
            child = const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else {
            final intros = snapshot.data ?? [];
            if (intros.isNotEmpty) {
              child = _IntroPage(intros);
            } else {
              child = const HomePage();
            }
          }

          return VirtualWindowFrame(title: BuildData.name, child: child);
        },
      ),
    );
  }
}

void _setup(BuildContext context) async {
  SystemUIs.setTransparentNavigationBar(context);
}
