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
  /// like. The wiki this used to point at says nothing about either.
  static const customLogoDoc = '$docs/advanced/custom-logo/';

  /// What a `monitor` agent is, and how to get one onto a server.
  ///
  /// Linked from the server editor rather than only from the docs site: the
  /// switch offers a way of reaching a server that does not exist until
  /// something has been installed on it, which is not a thing a switch can
  /// convey on its own.
  static const monitorAgentDoc = '$docs/advanced/monitor-agent/';

  /// What is collected at each diagnostics level, and what is not.
  ///
  /// Linked from the intro page that asks the question and from the setting
  /// that revisits it. Three sentences on a radio tile can say what a level
  /// sends; they cannot say where it goes, how long it is kept, or what a
  /// report has been checked not to contain — and consent given without
  /// somewhere to read that is consent to a summary.
  static const privacyPolicy = '$docs/privacy/';
}
