// Every language the app offers must be one every delegate has strings for.
// fl_pi_llm had no Italian, Korean or Azerbaijani: the home page's builder
// threw before it set the app's own strings, so switching to Italian left
// half the settings in English and the next launch on a blank page (#1643).
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/generated/l10n/l10n.dart';

void main() {
  test('every delegate supports every offered locale', () {
    final unsupported = [
      for (final locale in AppLocalizations.supportedLocales)
        for (final delegate in appLocalizationsDelegates)
          if (!delegate.isSupported(locale)) '${delegate.type} $locale',
    ];
    expect(unsupported, isEmpty);
  });
}
