abstract final class Urls {
  static const myGithub = 'https://github.com/lollipopkit';
  static const githubApi = 'https://api.github.com/repos/lollipopkit';
  static const thisRepo = '$myGithub/flutter_server_box';
  static const githubReleasesApi = '$githubApi/flutter_server_box/releases';
  static const appStore = 'https://apps.apple.com/app/id1586449703';
  static const appHelp = '$thisRepo#-help';
  static const appWiki = '$thisRepo/wiki';

  /// Where a crash report goes.
  ///
  /// The body is not prefilled through the query string: a report carries the
  /// previous run's log, which is far past what a URL can hold, and a truncated
  /// one would be a report missing the end — the part nearest the crash. It is
  /// put on the clipboard instead and this page is opened to paste it into.
  static const newIssue = '$thisRepo/issues/new';

  static const docs = 'https://serverbox.lollipopkit.com/docs';

  /// What `{DIST}` and `{BRIGHT}` mean, and what a usable image URL looks
  /// like.
  static const customLogoDoc = '$docs/advanced/custom-logo/';

  /// What a `monitor` agent is, and how to get one onto a server.
  ///
  /// Linked from the server editor, because the switch offers a way of
  /// reaching a server that does not exist until something is installed on it
  /// — not a thing a switch can convey on its own.
  static const monitorAgentDoc = '$docs/advanced/monitor-agent/';

  /// What `[remote_access]` grants, and that every switch under it is off
  /// until the agent's operator edits `config.toml`.
  ///
  /// Linked from the server page of an agent that grants nothing — the one
  /// place the absence of the whole function bar needs explaining, and where
  /// the reader may not be the person who has the file.
  static const monitorPermissionsDoc = '$monitorAgentDoc#permission-switches';

  /// How an alert rule is written: what a metric, a matcher and a threshold
  /// are, which combinations the agent actually evaluates, and when a rule
  /// stays quiet.
  ///
  /// Linked rather than restated in the form, because the parts worth knowing
  /// are exactly the ones a form cannot show: a threshold with no comparator
  /// means `<`, and a unit that does not fit its metric never fires.
  static const monitorRulesDoc = '$monitorAgentDoc#alert-rules';

  /// What is collected at each diagnostics level, and what is not.
  ///
  /// Linked from the intro page that asks the question and from the setting
  /// that revisits it. Three sentences on a radio tile can say what a level
  /// sends; they cannot say where it goes or how long it is kept, and consent
  /// given without somewhere to read that is consent to a summary.
  static const privacyPolicy = '$docs/privacy/';

  /// Where the city-level geo data is downloaded from.
  ///
  /// A manifest and two archives, fetched once; every individual lookup after
  /// that is local. The download is itself an ordinary HTTPS request, so it
  /// exposes whatever any request does — the caller's address, TLS metadata,
  /// timing — but it never says which address is being looked up, because the
  /// lookups happen on the device against the downloaded data. That is why
  /// there is no setting to point it elsewhere: there would be nothing for it
  /// to improve.
  static const geoData = 'https://ipgeo.lollipopkit.com';

  /// The second endpoint, for a network where the first will not answer.
  ///
  /// `releases/latest/download/<file>` resolves without a tag being known, so
  /// the fallback needs no lookup of its own. It carries the same logical data,
  /// but independently produced gzip archives may have different bytes, so the
  /// installer uses each endpoint's manifest and assets as one set.
  static const geoDataFallback =
      '$myGithub/ipgeo-shards/releases/latest/download';

  /// How the data is built, and where the DB-IP attribution lives.
  static const geoDataRepo = '$myGithub/ipgeo-shards';
}
