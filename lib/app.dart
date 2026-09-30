import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmL10nX;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/motion.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/core/utils/local_server.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/home.dart';
import 'package:server_box/view/widget/diagnostics_level_picker.dart';
import 'package:server_box/view/widget/session_keep_alive_notice.dart';

part 'intro.dart';

Widget _buildHomeWithWindowFrame() {
  return VirtualWindowFrame(title: BuildData.name, child: const HomePage());
}

ThemeData _theme({Color? seed, Brightness? brightness}) => buildAppTheme(
  AppThemeSource.current(),
  seed: seed,
  brightness: brightness,
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<List<IntroPageBuilder>> _introFuture = _IntroPage.builders;
  bool _transparentNavBarConfigured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_transparentNavBarConfigured) return;
    _transparentNavBarConfigured = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemUIs.setTransparentNavigationBar(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        RNodes.app,
        ThemePackages.preview,
        Stores.setting.locale.listenable(),
      ]),
      builder: (context, _) {
        if (!(ThemePackages.preview.value?.systemColor ??
            Stores.setting.useSystemPrimaryColor.fetch())) {
          return _build(context);
        }

        return _buildDynamicColor(context);
      },
    );
  }

  Widget _build(BuildContext context) {
    final colorSeed = Color(
      ThemePackages.preview.value?.seed ?? Stores.setting.colorSeed.fetch(),
    );

    UIs.colorSeed = colorSeed;
    UIs.primaryColor = colorSeed;

    return _buildApp(
      context,
      light: _theme(seed: UIs.colorSeed),
      dark: _theme(seed: UIs.colorSeed, brightness: Brightness.dark),
    );
  }

  Widget _buildDynamicColor(BuildContext context) {
    return DynamicColorBuilder(
      builder: (light, dark) {
        final lightSeed = light?.primary;
        final darkSeed = dark?.primary;

        final lightTheme = _theme(seed: lightSeed);
        final darkTheme = _theme(seed: darkSeed, brightness: Brightness.dark);

        if (context.isDark && dark != null) {
          UIs.primaryColor = dark.primary;
          UIs.colorSeed = dark.primary;
        } else if (!context.isDark && light != null) {
          UIs.primaryColor = light.primary;
          UIs.colorSeed = light.primary;
        } else {
          final fallbackColor = Color(
            ThemePackages.preview.value?.seed ??
                Stores.setting.colorSeed.fetch(),
          );
          UIs.primaryColor = fallbackColor;
          UIs.colorSeed = fallbackColor;
        }

        return _buildApp(context, light: lightTheme, dark: darkTheme);
      },
    );
  }

  /// Hand the theme to the app name drawn behind the Dynamic Island, which is
  /// a native view and cannot read it. Deduplicated in [MethodChans].
  void _syncIslandBrandColors(BuildContext ctx) {
    if (!isIOS) return;
    final scheme = Theme.of(ctx).colorScheme;
    unawaited(
      MethodChans.setIslandBrandColors(
        scheme.primary.toARGB32(),
        scheme.onPrimary.toARGB32(),
      ),
    );
  }

  Widget _buildApp(
    BuildContext ctx, {
    required ThemeData light,
    required ThemeData dark,
  }) {
    final themeMode = ThemePackages.effectiveMode;
    final locale = Stores.setting.locale.fetch().toLocale;

    return MaterialApp(
      key: ValueKey(locale),
      restorationScopeId: 'serverbox',
      navigatorKey: AppNavigator.key,
      // It sits over the top-right corner, which is where every page's app bar
      // keeps its actions — and it says nothing a debug build does not already
      // say everywhere else.
      debugShowCheckedModeBanner: false,
      // Outside the breakpoints builder: a toast is sized against the window,
      // not against the scaled layout the breakpoints hand to the pages.
      builder: (ctx, child) {
        // Here rather than at launch: this `ctx` is below the theme, so it
        // rebuilds when the seed color, the brightness or the system's dynamic
        // color changes — each of which the native badge has to follow.
        _syncIslandBrandColors(ctx);
        // The same three changes the chart colours are worked out from, and
        // this runs before any page builds — see [ChartPalette.resolve].
        // `UIs.colorSeed` rather than the scheme's primary: it is the colour
        // that was picked, which the two builders above keep current whether
        // it came from the setting or from the system.
        ChartPalette.resolve(UIs.colorSeed, dark: ctx.isDark);
        final content = ToastHost(
          // Under the host, whose toasts it raises, and over every page:
          // a remote session closes as idle whichever page is showing.
          child: SessionKeepAliveNotices(
            child: ResponsivePoints.builder(ctx, child),
          ),
        );
        // The one background the whole app stands on. A page takes a copy of
        // it while it moves, so that it covers the page below — see
        // [AppPageTransitions].
        //
        // Under [MotionScope], which says for everything below whether the
        // app moves less — see [AppMotion].
        // TODO: remove once the dependencies below that still import
        // package:flutter/material.dart migrate to material_ui (#1591). It
        // hands them the theme and localizations, which they look up by the
        // legacy types.
        // ignore: deprecated_member_use
        return MaterialUiCompatibilityBridge(
          child: MotionScope(
            child: ThemeSplashGate(child: AppBackground(child: content)),
          ),
        );
      },
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: LocaleUtil.resolve,
      navigatorObservers: [AppRouteObserver.instance],
      title: BuildData.name,
      themeMode: themeMode,
      theme: light,
      darkTheme: dark,
      home: FutureBuilder<List<IntroPageBuilder>>(
        future: _introFuture,
        builder: (context, snapshot) {
          context.setLibL10n();
          context.setLlmL10n();
          final appL10n = AppLocalizations.of(context);
          if (appL10n != null) l10n = appL10n;

          Widget child;
          var hasWindowFrame = false;
          if (snapshot.connectionState == ConnectionState.waiting) {
            child = const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else {
            final intros = snapshot.data ?? [];
            if (intros.isNotEmpty) {
              child = _IntroPage(intros);
            } else {
              child = _buildHomeWithWindowFrame();
              hasWindowFrame = true;
            }
          }

          if (hasWindowFrame) return child;
          return VirtualWindowFrame(title: BuildData.name, child: child);
        },
      ),
    );
  }
}
