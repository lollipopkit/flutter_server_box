import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/generated/l10n/l10n.dart';

/// What `main` runs instead of the app when the launch cannot go on: [page]
/// alone, in the system's theme and locale.
///
/// Its own `MaterialApp` because `MyApp` reads settings out of a database
/// that is either refused or was never opened.
class RescueApp extends StatelessWidget {
  const RescueApp({super.key, required this.page});

  final Widget page;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The same list as `MyApp`: without `LibLocalizations.delegate` every
      // `libL10n.*` string on the page stays English while its own text is
      // translated.
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: LocaleUtil.resolve,
      // The system's, since the stored preference is in the database.
      themeMode: ThemeMode.system,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue).fixWindowsFont,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ).fixWindowsFont,
      // The other half of it: `libL10n` is a global that only this call
      // replaces, and `MyApp` makes it from its own home builder.
      home: Builder(
        builder: (context) {
          context.setLibL10n();
          return page;
        },
      ),
    );
  }
}
