import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';

AppLocalizations l10n = AppLocalizationsEn();

/// fl_lib's strings, the app's, and material_ui's.
///
/// TODO: `AppLocalizations.localizationsDelegates` once gen-l10n emits
/// material_ui's delegates (#1591); it still lists flutter_localizations',
/// which material_ui's widgets do not read.
const appLocalizationsDelegates = <LocalizationsDelegate<Object?>>[
  LibLocalizations.delegate,
  // The Agent's chats, tools and provider settings — see fl_pi_llm_ui.
  LlmLocalizations.delegate,
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

extension LocaleX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
