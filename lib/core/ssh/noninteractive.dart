/// Tracks whether an unattended handshake reached a question only the user
/// can answer. SSH callbacks can report rejection without propagating its cause.
class SshInteractionRequired implements Exception {}

class NonInteractiveSsh {
  bool needsUser = false;

  void decline() => needsUser = true;
}
