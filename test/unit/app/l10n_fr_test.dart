import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/generated/l10n/l10n_fr.dart';

void main() {
  test('French process count uses the singular only for one', () {
    final l10n = AppLocalizationsFr();

    expect(l10n.processCount(0), '0 processus');
    expect(l10n.processCount(1), '1 processus');
    expect(l10n.processCount(2), '2 processus');
  });
}
