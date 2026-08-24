/// What a recognised distribution turns into, now that the app ships no
/// pictures: an address the user wrote down.
///
/// The failures worth catching are all silent ones. An unconfigured install
/// that starts fetching something anyway is the whole point of the change
/// undone. A template still holding a literal `{DIST}` reaches an image loader
/// as a 404 per row. And a value that is not http reaches that loader as
/// whatever scheme the user typed.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/dist_icon.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    // `distMarkUrl` reads the global setting through the locator, so it has to
    // be the same instance this test writes to.
    GetIt.instance.registerSingleton<SettingStore>(SettingStore.forTest()..init());
  });

  tearDown(() async {
    await GetIt.instance.reset();
    SqliteDb.close();
  });

  String? url({
    Dist? dist = Dist.debian,
    String? override,
    bool dark = false,
    String global = '',
  }) {
    GetIt.instance<SettingStore>().serverLogoUrl.put(global);
    return distMarkUrl(dist: dist, override: override, dark: dark);
  }

  test('nothing configured fetches nothing', () {
    // The out-of-the-box state, and the one that matters: no address means no
    // request, for any server, ever.
    expect(url(), isNull);
  });

  test('the template expands to the distribution', () {
    expect(
      url(global: 'https://ex.com/{DIST}.svg', dist: Dist.rhel),
      'https://ex.com/rhel.svg',
    );
  });

  test('a template with no distribution to put in it draws nothing', () {
    // Rather than requesting the literal `{DIST}`, which is a 404 per row and
    // a line in somebody's server log.
    expect(url(global: 'https://ex.com/{DIST}.svg', dist: null), isNull);
  });

  test('an address without the token works for a server with no distribution', () {
    // A single fixed image is a legitimate thing to configure, and it does not
    // depend on recognising anything.
    expect(url(global: 'https://ex.com/one.png', dist: null), 'https://ex.com/one.png');
  });

  test('{BRIGHT} follows the theme', () {
    expect(
      url(global: 'https://ex.com/{DIST}-{BRIGHT}.svg', dark: true),
      'https://ex.com/debian-dark.svg',
    );
    expect(
      url(global: 'https://ex.com/{DIST}-{BRIGHT}.svg'),
      'https://ex.com/debian-light.svg',
    );
  });

  test("a server's own address wins over the global one", () {
    expect(
      url(global: 'https://global/{DIST}.svg', override: 'https://mine/{DIST}.png'),
      'https://mine/{DIST}.png'.replaceAll('{DIST}', 'debian'),
    );
  });

  test('a GitHub page address is rewritten to the one that serves bytes', () {
    // What the address bar gives you. Left alone it fetches HTML, which the
    // decoder reports as invalid image data and says nothing about why.
    expect(
      url(global: 'https://github.com/o/r/blob/main/i/{DIST}.svg'),
      'https://raw.githubusercontent.com/o/r/main/i/debian.svg',
    );
  });

  test('anything that is not http is refused', () {
    // The value is user-entered and reaches an image loader.
    for (final bad in [
      'file:///etc/passwd',
      'javascript:alert(1)',
      'data:image/svg+xml,<svg/>',
      '/local/path.svg',
    ]) {
      expect(url(global: bad), isNull, reason: '$bad must not be fetched');
    }
  });
}
