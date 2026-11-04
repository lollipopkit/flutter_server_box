import 'dart:io';

import 'package:xterm/core.dart';

/// Which keyboard the person at the terminal is typing on.
///
/// The **host's** platform, not the server's: this decides how key presses are
/// turned into bytes, and the keys are being pressed here.
///
/// Left at [TerminalTargetPlatform.unknown] — which is `Terminal`'s default,
/// and what this app passed for as long as it had a terminal — every keytab
/// entry that distinguishes a Mac takes the other branch. Option+Left then
/// sends `\E[1;5D` instead of `\Eb`, which a shell ignores, so word movement
/// simply does nothing; and `AltInputHandler`, which stands aside on macOS so
/// that Option can still compose characters, starts turning Option+e into an
/// escape sequence instead of `é`.
///
/// iOS answers `macos`, deliberately. The keytab's condition is
/// `platform == macos` exactly, and what it selects is the Apple keyboard
/// convention — Option composes, Option+arrow moves by word. An iPad with a
/// hardware keyboard follows that convention; an iPhone has no Option key to
/// disagree with.
TerminalTargetPlatform get hostTerminalPlatform {
  if (Platform.isMacOS || Platform.isIOS) return TerminalTargetPlatform.macos;
  if (Platform.isAndroid) return TerminalTargetPlatform.android;
  if (Platform.isLinux) return TerminalTargetPlatform.linux;
  if (Platform.isWindows) return TerminalTargetPlatform.windows;
  if (Platform.isFuchsia) return TerminalTargetPlatform.fuchsia;
  return TerminalTargetPlatform.unknown;
}
