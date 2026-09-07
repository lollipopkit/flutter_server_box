abstract final class Defaults {
  static const updateInterval = 3;

  /// How often the user's custom status commands run, in seconds.
  ///
  /// They used to run on every status poll, which meant arbitrary shell a user
  /// typed executing every three seconds and the readings beside it waiting on
  /// whichever one was slowest. An order of magnitude off that, and still
  /// fresh enough to read as live; `0` puts it back on every poll.
  ///
  /// Rounded up to a whole number of poll intervals, since that is when the
  /// app is talking to the server anyway — see `customCmdRefreshInterval`.
  static const customCmdInterval = 30;

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
