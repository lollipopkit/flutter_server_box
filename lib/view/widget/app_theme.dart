import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/service/app_font.dart';
import 'package:server_box/core/service/theme_components.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/app_background.dart';

/// What [buildAppTheme] builds a theme from: the app's own settings, or one
/// theme package on its own.
final class AppThemeSource {
  const AppThemeSource({
    required this.seed,
    required this.cardRadius,
    required this.tileRadius,
    required this.buttonRadius,
    required this.hasBackground,
    this.paletteLight,
    this.paletteDark,
    this.components = const ThemeComponents.empty(),
  });

  /// The theme the app is drawing: the preview while one is on, else the
  /// settings a selected theme wrote.
  factory AppThemeSource.current() {
    final preview = ThemePackages.preview.value;
    final settings = Stores.setting;
    final backgroundStyle =
        preview?.backgroundStyle ?? settings.appBackgroundStyle.fetch();
    final backgroundPath = preview != null
        ? preview.backgroundPath ?? ''
        : settings.appBackgroundPath.fetch();
    final palette = preview != null || settings.appThemePaletteEnabled.fetch();
    return AppThemeSource(
      seed: preview?.seed ?? settings.colorSeed.fetch(),
      cardRadius: preview?.cardRadius ?? settings.appCardRadius.fetch(),
      tileRadius: preview?.tileRadius ?? settings.appTileRadius.fetch(),
      buttonRadius: preview?.buttonRadius ?? settings.appButtonRadius.fetch(),
      hasBackground: _hasBackground(backgroundStyle, backgroundPath),
      paletteLight: palette ? ThemePackages.activePalette(dark: false) : null,
      paletteDark: palette ? ThemePackages.activePalette(dark: true) : null,
      components:
          ThemePackages.activeTheme?.components ??
          const ThemeComponents.empty(),
    );
  }

  /// [package] as the app would draw it once applied.
  factory AppThemeSource.of(ThemePackage package) => AppThemeSource(
    seed: package.seed,
    cardRadius: package.cardRadius,
    tileRadius: package.tileRadius,
    buttonRadius: package.buttonRadius,
    hasBackground: _hasBackground(
      package.backgroundStyle,
      package.backgroundPath ?? '',
    ),
    paletteLight: package.paletteLight,
    paletteDark: package.paletteDark,
    components: package.components,
  );

  final int seed;
  final double cardRadius;
  final double tileRadius;
  final double buttonRadius;

  /// Whether pages stand on a gradient or an image, and are transparent.
  final bool hasBackground;

  /// The palette per brightness, or null to keep what the seed generates.
  final Map<String, int>? paletteLight;
  final Map<String, int>? paletteDark;
  final ThemeComponents components;

  static bool _hasBackground(BackgroundStyle style, String path) =>
      style == BackgroundStyle.gradient ||
      (style == BackgroundStyle.image && path.isNotEmpty);
}

/// Every theme this app builds, differing only in brightness and seed.
///
/// Four of these are constructed for the app — a seed from the settings or
/// from the system, each in both brightnesses — and anything not passed here
/// is a property three of them silently do not have. The theme store builds
/// one more per theme it previews, from that theme's own [AppThemeSource], so
/// a preview is the theme the app would draw and not a picture of it.
ThemeData buildAppTheme(
  AppThemeSource source, {
  Color? seed,
  Brightness? brightness,
}) {
  final cardRadius = source.cardRadius.clamp(0.0, 40.0);
  final tileRadius = source.tileRadius.clamp(0.0, 40.0);
  final buttonRadius = source.buttonRadius.clamp(0.0, 40.0);
  var colorScheme = ColorScheme.fromSeed(
    seedColor: seed ?? Color(source.seed),
    brightness: brightness ?? Brightness.light,
  );
  if (brightness == Brightness.dark ? source.paletteDark : source.paletteLight
      case final palette?) {
    colorScheme = ThemePackages.applyPalette(colorScheme, palette);
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
  final hasBackground = source.hasBackground;
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
    // Every plain `Divider`/`VerticalDivider` a hairline, as the seams and
    // section rules are: Material's own is drawn for a light background and
    // reads as a bright line on a dark one, next to hairlines that do not.
    dividerTheme: DividerThemeData(color: Hairline.of(colorScheme)),
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
  return source.components.apply(styled);
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

