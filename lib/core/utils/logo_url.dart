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
