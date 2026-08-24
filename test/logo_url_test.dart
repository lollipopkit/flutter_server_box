/// Rewriting a GitHub page URL to the one that serves the file.
///
/// The address bar gives you `/blob/` or `/tree/`, both of which return HTML.
/// It reaches the image decoder as `Invalid image data` and the log says
/// nothing about the URL, so the obvious thing to paste was the thing that
/// could not work.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/logo_url.dart';

void main() {
  test('a blob URL becomes the raw one', () {
    expect(
      resolveLogoUrl(
        'https://github.com/lollipopkit/flutter_server_box/blob/main/assets/logo.png',
      ),
      'https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/assets/logo.png',
    );
  });

  test('and so does a tree URL', () {
    expect(
      resolveLogoUrl(
        'https://github.com/lollipopkit/flutter_server_box/tree/6db223ec/assets/linux/x.png',
      ),
      'https://raw.githubusercontent.com/lollipopkit/flutter_server_box/6db223ec/assets/linux/x.png',
    );
  });

  test('the placeholders survive the rewrite literally', () {
    // `getLogoUrl` substitutes these when the logo is drawn, by looking for
    // the literal braces. Percent-encoding them — which is what rebuilding
    // the URL through `Uri` does — leaves a URL that matches nothing and a
    // 404 with no explanation.
    expect(
      resolveLogoUrl(
        'https://github.com/o/r/tree/sha/assets/linux/{DIST}-{BRIGHT}.png',
      ),
      'https://raw.githubusercontent.com/o/r/sha/assets/linux/{DIST}-{BRIGHT}.png',
    );
  });

  test('a URL that already serves bytes is untouched', () {
    const raw =
        'https://raw.githubusercontent.com/o/r/main/assets/{DIST}.png';
    expect(resolveLogoUrl(raw), raw);
  });

  test('so is anything that is not GitHub', () {
    const other = 'https://example.com/logo.png';
    expect(resolveLogoUrl(other), other);
  });

  test('and a GitHub URL that names no file', () {
    for (final url in const [
      'https://github.com/lollipopkit/flutter_server_box',
      'https://github.com/lollipopkit/flutter_server_box/releases',
      'https://github.com/lollipopkit/flutter_server_box/blob/main',
    ]) {
      expect(resolveLogoUrl(url), url, reason: '$url names no file');
    }
  });

  test('surrounding whitespace does not defeat the match', () {
    expect(
      resolveLogoUrl('  https://github.com/o/r/blob/main/a.png  '),
      'https://raw.githubusercontent.com/o/r/main/a.png',
    );
  });

  test('something unparseable comes back as it went in', () {
    expect(resolveLogoUrl(''), '');
    expect(resolveLogoUrl('not a url'), 'not a url');
  });
}
