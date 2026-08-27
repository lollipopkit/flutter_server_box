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
    GetIt.instance.registerSingleton<SettingStore>(
      SettingStore('setting_test')..init(),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
    // Awaited: it returns a future, and the next test's `openTestDb` would
    // otherwise race a close still in flight.
    await SqliteDb.close();
  });

  String? url({
    Dist? dist = Dist.debian,
    bool dark = false,
    String mark = '',
    Map<String, String> names = const {},
  }) {
    GetIt.instance<SettingStore>()
      ..serverMarkUrl.put(mark)
      ..distNameMap.put(names);
    return distMarkUrl(dist: dist, dark: dark);
  }

  test('nothing configured fetches nothing', () {
    // The out-of-the-box state, and the one that matters: no address means no
    // request, for any server, ever. A shipped mark may still be drawn — that
    // is an asset, not a fetch, and it is decided in `DistIconOf`.
    expect(url(), isNull);
    expect(url(dist: Dist.debian), isNull, reason: 'a bundled one included');
  });

  test('an address wins over a bundled mark', () {
    // Somebody who chose a collection wants it used for every row, not for
    // fifty-eight of them with five exceptions drawn from the bundle.
    expect(Dist.debian.markAsset, isNotNull, reason: 'debian is bundled');
    expect(
      url(mark: 'https://ex.com/{DIST}.svg', dist: Dist.debian),
      'https://ex.com/debian.svg',
    );
  });

  test('the template expands to the distribution', () {
    expect(
      url(mark: 'https://ex.com/{DIST}.svg', dist: Dist.rhel),
      'https://ex.com/rhel.svg',
    );
  });

  test('a template with no distribution to put in it draws nothing', () {
    // Rather than requesting the literal `{DIST}`, which is a 404 per row and
    // a line in somebody's server log.
    expect(url(mark: 'https://ex.com/{DIST}.svg', dist: null), isNull);
  });

  test(
    'an address without the token works for a server with no distribution',
    () {
      // A single fixed image is a legitimate thing to configure, and it does not
      // depend on recognising anything.
      expect(
        url(mark: 'https://ex.com/one.png', dist: null),
        'https://ex.com/one.png',
      );
    },
  );

  test('{BRIGHT} follows the theme', () {
    expect(
      url(mark: 'https://ex.com/{DIST}-{BRIGHT}.svg', dark: true),
      'https://ex.com/debian-dark.svg',
    );
    expect(
      url(mark: 'https://ex.com/{DIST}-{BRIGHT}.svg'),
      'https://ex.com/debian-light.svg',
    );
  });

  test('the logo address is a different setting and is not used here', () {
    // A mark is not the logo: the logo is the large image on a server's own
    // page. Reading `serverLogoUrl` here would put a full-width picture in a
    // 20px slot on every row, and emptying the mark would not stop it.
    GetIt.instance<SettingStore>().serverLogoUrl.put('https://logo/{DIST}.png');
    expect(url(), isNull);
  });

  test('a GitHub page address is rewritten to the one that serves bytes', () {
    // What the address bar gives you. Left alone it fetches HTML, which the
    // decoder reports as invalid image data and says nothing about why.
    expect(
      url(mark: 'https://github.com/o/r/blob/main/i/{DIST}.svg'),
      'https://raw.githubusercontent.com/o/r/main/i/debian.svg',
    );
  });

  group('the name overrides', () {
    // No table is shipped: the file names belong to whichever collection the
    // user pointed at, so a mapping right for one is wrong for the next.
    test('replace what {DIST} expands to, for the ones listed', () {
      expect(
        url(
          mark: 'https://ex.com/{DIST}.svg',
          dist: Dist.rhel,
          names: const {'rhel': 'redhat'},
        ),
        'https://ex.com/redhat.svg',
      );
    });

    test('and leave every other distribution alone', () {
      // The normal case: a handful of exceptions, sixty-odd untouched.
      expect(
        url(
          mark: 'https://ex.com/{DIST}.svg',
          dist: Dist.debian,
          names: const {'rhel': 'redhat', 'arch': 'archlinux'},
        ),
        'https://ex.com/debian.svg',
      );
    });

    test('an entry for something not installed changes nothing', () {
      expect(
        url(mark: 'https://ex.com/{DIST}.svg', names: const {'nope': 'x'}),
        'https://ex.com/debian.svg',
      );
    });
  });

  test('anything that is not http or https is refused', () {
    // The value is user-entered and reaches an image loader. Checked by
    // scheme, not by prefix: the four letters of "http" begin a great many
    // things that are not it.
    for (final bad in [
      'file:///etc/passwd',
      'javascript:alert(1)',
      'data:image/svg+xml,<svg/>',
      '/local/path.svg',
      'httpx://elsewhere/a.svg',
      'httpfoo:whatever',
    ]) {
      expect(url(mark: bad), isNull, reason: '$bad must not be fetched');
    }
  });

  test('and http and https are accepted', () {
    expect(url(mark: 'http://ex.com/a.svg'), 'http://ex.com/a.svg');
    expect(url(mark: 'HTTPS://ex.com/a.svg'), 'HTTPS://ex.com/a.svg');
  });
}
