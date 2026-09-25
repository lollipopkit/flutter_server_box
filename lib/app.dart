import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/app_font.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/utils/local_server.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/home.dart';
import 'package:server_box/view/widget/app_background.dart';
import 'package:server_box/view/widget/diagnostics_level_picker.dart';
import 'package:server_box/view/widget/session_keep_alive_notice.dart';
import 'package:server_box/view/widget/theme_splash.dart';

part 'intro.dart';

Widget _buildHomeWithWindowFrame() {
  return VirtualWindowFrame(title: BuildData.name, child: const HomePage());
}

/// Every theme this app builds, differing only in brightness and seed.
///
/// Four of these are constructed — a seed from the settings or from the
/// system, each in both brightnesses — and anything not passed here is a
/// property three of them silently do not have.
ThemeData _theme({Color? seed, Brightness? brightness}) {
  final cardRadius =
      (ThemePackages.preview.value?.cardRadius ??
              Stores.setting.appCardRadius.fetch())
          .clamp(0.0, 40.0);
  final tileRadius =
      (ThemePackages.preview.value?.tileRadius ??
              Stores.setting.appTileRadius.fetch())
          .clamp(0.0, 40.0);
  final buttonRadius =
      (ThemePackages.preview.value?.buttonRadius ??
              Stores.setting.appButtonRadius.fetch())
          .clamp(0.0, 40.0);
  var colorScheme = ColorScheme.fromSeed(
    seedColor:
        seed ??
        Color(
          ThemePackages.preview.value?.seed ?? Stores.setting.colorSeed.fetch(),
        ),
    brightness: brightness ?? Brightness.light,
  );
  if (ThemePackages.preview.value != null ||
      Stores.setting.appThemePaletteEnabled.fetch()) {
    colorScheme = ThemePackages.applyPalette(
      colorScheme,
      ThemePackages.activePalette(dark: brightness == Brightness.dark),
    );
  }
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cardRadius),
  );
  final tileShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tileRadius),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(buttonRadius),
  );
  final buttonStyle = ButtonStyle(shape: WidgetStatePropertyAll(buttonShape));
  final fontFamilies = AppFont.families;
  final backgroundStyle =
      ThemePackages.preview.value?.backgroundStyle ??
      Stores.setting.appBackgroundStyle.fetch();
  final backgroundPath = (ThemePackages.preview.value != null
      ? ThemePackages.preview.value!.backgroundPath ?? ''
      : Stores.setting.appBackgroundPath.fetch());
  final hasBackground =
      backgroundStyle == BackgroundStyle.gradient ||
      (backgroundStyle == BackgroundStyle.image && backgroundPath.isNotEmpty);
  // Resolve fonts before deriving component styles so titles and tiles keep
  // the same fallback fonts as ordinary text.
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: fontFamilies.firstOrNull,
    fontFamilyFallback: fontFamilies.length > 1
        ? fontFamilies.skip(1).toList()
        : null,
    scaffoldBackgroundColor: hasBackground ? Colors.transparent : null,
    // The page over a background is transparent, so two of them over each
    // other during a transition are two sets of rows on the same pixels. The
    // background's own transitions give each moving page the background, which
    // is what makes the arriving one cover the one below — see
    // [AppPageTransitions]. Null without a background: an opaque page needs no
    // help, and the platform's own transition is the right one.
    pageTransitionsTheme: hasBackground ? AppPageTransitions.backgrounded : null,
    cardTheme: CardThemeData(shape: cardShape, elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    navigationBarTheme: NavigationBarThemeData(indicatorShape: buttonShape),
    dialogTheme: DialogThemeData(shape: cardShape),
    // `centerTitle` for the bars that are a plain `AppBar` rather than a
    // `CustomAppBar`, which now defaults to the same thing itself.
    appBarTheme: AppBarTheme(
      scrolledUnderElevation: 0,
      centerTitle: false,
      // A bar over a background image or a gradient is the background's as
      // well. The page under it is transparent on purpose, and a bar resolving
      // the scheme's `surface` — which is what Material's own default is —
      // drew a strip of a colour the wallpaper does not have across the top of
      // it. Null where the page has no background, so the scheme's surface is
      // still what a bar is.
      backgroundColor: hasBackground ? Colors.transparent : null,
    ),
    listTileTheme: _listTileTheme.copyWith(shape: tileShape),
    // Material's back button is an arrow with a shaft on Android and a bare
    // `arrow_back_ios_new` on Apple — two glyphs for one control, decided by
    // the platform rather than by this app. A chevron is the one every pane,
    // sheet and expandable row here already uses for "there is more this way",
    // so the bar's own way back is drawn with the same mark.
    actionIconTheme: const ActionIconThemeData(
      backButtonIconBuilder: _backButtonIcon,
    ),
    // A `Switch` is 52x32, and `padded` grows its *tap target* to 48 high —
    // taller than the row it is the trailing widget of, so every row carrying
    // one was sized by its switch instead of by its text. The rows are 44 and
    // the whole row toggles, so the target is not lost with the padding.
    switchTheme: const SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ).fixWindowsFont;
  // Copied onto the resolved one rather than passed to the constructor: an
  // `IconThemeData` carrying only a size has a null colour, and `Icon` answers
  // a null colour with `IconThemeData.fallback()` — black, in both themes.
  //
  // 24 is Material's, drawn to be recognised on its own. Every icon this app
  // puts in a tile sits beside the word for the same thing, where it is a mark
  // in the margin rather than the thing being read, and at 24 it outweighed
  // the label. 19 is what the tiles that set a size already use.
  //
  // Only reaches a bare `Icon`. `AppBar`, `IconButton`, `NavigationBar` and
  // the rail each resolve a size from their own defaults and are unaffected.
  final styled = base.copyWith(
    iconTheme: base.iconTheme.copyWith(size: 19),
    // Material's bar title is `titleLarge` at 22, drawn for a page that is one
    // thing. Every bar in this app sits over a form or a list whose own rows
    // are 14, and at 22 the name of the page outweighed everything on it —
    // pages had started passing a 20 of their own to get out from under it.
    //
    // `inherit: false` for the same reason [listTileTheme] needs it below:
    // `AnimatedTheme` lerps this against the previous theme's, and
    // `TextStyle.lerp` throws when the two ends disagree about it.
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        inherit: false,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: base.colorScheme.onSurface,
      ),
    ),
    // Material's tile is a destination in a menu, so its title is `bodyLarge`
    // at 16 and its subtitle `bodyMedium` at 14. These are rows of a form,
    // where the title is a field's name and the subtitle is what it is set to,
    // and 16 made every tile outweigh the `Input` beside it.
    //
    // `inherit: false` is load-bearing and not a detail. `AnimatedTheme` lerps
    // a whole `ThemeData` on every theme change, so `ListTileThemeData.lerp`
    // interpolates a style given here against whatever the theme before it
    // had — `null`, the first time — and `TextStyle.lerp` throws outright when
    // the two ends disagree about `inherit`. Material's own defaults are
    // `inherit: false`; the app's `textTheme` is not, so a style taken from it
    // and handed over unchanged brought the whole page down.
    //
    // `dense` would be the way to do this without a style at all, but it is a
    // `copyWith(fontSize: 13)` applied *after* this one, so the two cannot be
    // combined — dense simply wins.
    listTileTheme: _listTileTheme.copyWith(
      shape: tileShape,
      titleTextStyle: base.textTheme.bodyLarge?.copyWith(
        inherit: false,
        fontSize: 14,
        color: base.colorScheme.onSurface,
      ),
      subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
        inherit: false,
        fontSize: 12,
        color: base.colorScheme.onSurfaceVariant,
      ),
    ),
  );
  return ThemePackages.activeTheme?.components.apply(styled) ?? styled;
}

/// A top-level function so that [ActionIconThemeData] can be `const` — a
/// closure here would rebuild the theme's identity on every call.
Widget _backButtonIcon(BuildContext context) => const Icon(Icons.chevron_left);

/// Material's own metrics are drawn for a list of destinations, one tap each.
/// Most of this app's tiles are rows of a form — a label, what it is set to,
/// and a way in — stacked a dozen at a time inside a card each, where 16pt of
/// padding and a 72pt floor under a two-line row is most of a phone screen
/// spent on the gaps between six settings.
///
/// The numbers are this codebase's own: 13 is `UIs.height13`, the card padding
/// and the card radius, and 44 is the smallest thing worth aiming a thumb at.
/// Set here rather than on each tile because a form that is loose in one page
/// and tight in the next reads as a mistake in whichever one is seen second.
const _listTileTheme = ListTileThemeData(
  contentPadding: EdgeInsets.symmetric(horizontal: 13),
  horizontalTitleGap: 13,
  // Material pads a leading narrower than 40 out to 40, which puts an icon and
  // its label a whole glyph apart. The gap above is then the only thing
  // between them, which is what it reads as.
  minLeadingWidth: 0,
  minVerticalPadding: 9,
  minTileHeight: 44,
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
        return ThemeSplashGate(child: AppBackground(child: content));
      },
      locale: locale,
      localizationsDelegates: const [
        LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates,
      ],
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
