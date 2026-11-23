/// Tracks whether an unattended handshake reached a question only the user
/// can answer. SSH callbacks can report rejection without propagating its cause.
class SshInteractionRequired implements Exception {}

class NonInteractiveSsh {
  bool needsUser = false;

  void decline() => needsUser = true;

  /// A handshake authenticated anyway: what it declined did not stop it, and
  /// is not why anything after it fails.
  void settle() => needsUser = false;
}
