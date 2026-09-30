/// A symbol of this app that a theme package may carry an image or a color
/// for, other than a tab's.
///
/// The key is a field rather than the value's own name: the spelling is
/// namespaced and dotted, so it is not an identifier. The keys this app
/// declares to the shared theme code (`ThemeIcons` in `theme_host.dart`) are
/// the tabs' and these, so a symbol here is one a widget can look up without
/// repeating the spelling.
enum ThemeNavIcon {
  more('nav.more'),
  settings('nav.settings'),
  tune('nav.tune'),
  privacy('nav.privacy'),
  agent('nav.agent'),
  tabs('nav.tabs'),
  server('nav.server'),
  sort('nav.sort'),
  terminal('nav.terminal'),
  folder('nav.folder'),
  cloud('nav.cloud'),
  snippet('nav.snippet'),
  inbox('nav.inbox'),
  key('nav.key'),
  info('nav.info'),
  download('nav.download'),
  desktop('nav.desktop');

  const ThemeNavIcon(this.iconKey);

  /// What a manifest's `icons.images` and `icons.colors` are keyed by, and what
  /// a widget asks the active package for.
  ///
  /// Not `key`: a value is named `key` too, and a case's name is a static member
  /// of the enum.
  final String iconKey;
}
