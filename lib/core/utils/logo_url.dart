import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/store/stores.dart';

/// The URL a GitHub link actually serves the image from.
///
/// `https://github.com/<owner>/<repo>/blob/<ref>/<path>` and its `tree/`
/// sibling are pages, not files: what comes back is HTML, which reaches the
/// image decoder as `Invalid image data` and says nothing about why. Copying
/// one out of the address bar is the obvious thing to do, so the address bar's
/// form is accepted and rewritten to the one that serves bytes.
///
/// Everything else is returned untouched, including a `raw.githubusercontent`
/// URL that is already right. The path is carried across verbatim, so
/// `{DIST}` and `{BRIGHT}` survive.
String resolveLogoUrl(String url) {
  final trimmed = url.trim();
  final match = _githubPage.firstMatch(trimmed);
  if (match == null) return trimmed;
  return 'https://raw.githubusercontent.com/'
      '${match[1]}/${match[2]}/${match[3]}';
}

/// `owner / repo / (blob|tree) / ref / at least one more segment`.
///
/// The tail has to hold a `/` so that a URL naming a branch and no file —
/// `…/blob/main` — is left alone rather than rewritten to a directory listing.
///
/// Matched and reassembled as text rather than through `Uri`, which
/// percent-encodes the braces: `{DIST}` would come back as `%7BDIST%7D`, and
/// the substitution done when the logo is drawn looks for the literal form and
/// would find nothing.
final _githubPage = RegExp(
  r'^https?://(?:www\.)?github\.com/([^/]+)/([^/]+)/(?:blob|tree)/([^/]+/.+)$',
);

/// Whether [url] is one this app will fetch: `http` or `https`, and nothing
/// else.
///
/// By scheme, not by prefix. `startsWith('http')` — which is what this
/// replaces — is also true of `httpx://`, `httpfoo:` and anything else that
/// begins with those four letters, and the value is user-entered and ends up
/// at an image loader.
bool isFetchableLogoUrl(String url) {
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

/// The placeholders an address may carry: the distribution's file name, and
/// `light` or `dark`.
const distToken = '{DIST}';
const brightToken = '{BRIGHT}';

/// The address a server's mark is fetched from, or null if there is none.
///
/// Four marks ship with the app — the ones whose artwork carries a licence
/// permitting it, see [Dist.markAsset] — and everything else is drawn from an
/// address the user configured. This resolves that address; the shipped files
/// are the fallback when there is none.
///
/// **A mark is not the logo.** The logo is the large image at the top of a
/// server's own page and comes from `serverLogoUrl`; this is the small one
/// beside its name in a list, and comes from `serverMarkUrl`. Two addresses
/// because they want two pictures: artwork that reads at full width is a
/// smudge at 20px, and an icon that works at 20px is lost on a detail page.
///
/// Null in three cases, all of which draw nothing: no address configured, an
/// address that wants `{DIST}` for a machine whose distribution is not known,
/// and one whose scheme is neither http nor https. The last is a guard rather
/// than a nicety — the value is user-entered and reaches an image loader.
String? distMarkUrl({required Dist? dist, required bool dark}) {
  final configured = Stores.setting.serverMarkUrl.fetch();
  if (configured.isEmpty) return null;

  var url = resolveLogoUrl(configured);
  if (url.contains(distToken)) {
    if (dist == null) return null;
    url = url.replaceAll(distToken, distFileName(dist));
  }
  url = url.replaceAll(brightToken, dark ? 'dark' : 'light');
  if (!isFetchableLogoUrl(url)) return null;
  return url;
}

/// What `{DIST}` becomes for [dist] — its own case name unless the user has
/// said otherwise.
///
/// The case name is the app's published contract and cannot change. But it
/// only matches the file names of the collection it was written against, and
/// the collection is now the user's choice: font-logos names Arch `archlinux`
/// and RHEL `redhat`, so somebody pointing `{DIST}` at it needs those two
/// renamed and the other sixty-odd left alone.
///
/// No table is shipped for this on purpose. There is no single right one — a
/// mapping correct for one collection is wrong for the next — and a wrong
/// entry would be worse than none, since it silently fetches the wrong logo
/// rather than nothing. `Stores.setting.distNameMap` is where the exceptions
/// go, edited by hand.
String distFileName(Dist dist) =>
    Stores.setting.distNameMap.fetch()[dist.name] ?? dist.name;
