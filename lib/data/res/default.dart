abstract final class Defaults {
  static const updateInterval = 3;

  static const editorTheme = 'a11y-light';
  static const editorDarkTheme = 'monokai';

  /// What goes into the guest's `/etc/resolv.conf`.
  ///
  /// Public resolvers, because an app can read the system's on neither
  /// platform. Two of them, so that one being unreachable is not the end of it.
  ///
  /// The mirror has no counterpart here: it belongs to the distribution, so it
  /// is `LinuxDistro.defaultMirror`.
  static const linuxDns = '8.8.8.8, 1.1.1.1';

  /// What an interactive terminal in the guest runs.
  ///
  /// Every distribution has one here, which is why it is the fallback and not
  /// a distribution's own field.
  static const linuxShell = '/bin/sh';
}
