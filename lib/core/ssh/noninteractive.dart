/// Tracks whether an unattended handshake reached a question only the user
/// can answer. SSH callbacks can report rejection without propagating its cause.
class SshInteractionRequired implements Exception {}

class NonInteractiveSsh {
  bool needsUser = false;

  void decline() => needsUser = true;

  /// A handshake authenticated anyway, or a jump candidate was given up for
  /// the next: what was declined is not why anything after it fails.
  void settle() => needsUser = false;
}
