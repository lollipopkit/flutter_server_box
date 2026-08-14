import 'dart:async';

/// What to do when the server says no.
///
/// SFTP has no notion of privilege: a refused rename is a refused rename, and
/// the only way further is to stop using SFTP and run the same change as a
/// shell command under `sudo`. That is a property of this backend — one with
/// no shell behind it has nowhere to escalate to — so it belongs beside it
/// rather than in the browser, which used to own the retry and therefore owned
/// it only for the pages that remembered to ask.
///
/// The contract is "run this command", not "here is a password": obtaining,
/// caching and forgetting the password stays on the side that already has a
/// screen to ask on, and the backend never holds one.
abstract interface class SftpEscalation {
  /// Whether escalating is possible at all. False for a session already
  /// running as root, where sudo would be the same user asking twice.
  bool get available;

  /// Skip the plain attempt entirely. For a user who has said they are working
  /// somewhere they know they cannot write, so every operation stops beginning
  /// with a refusal.
  bool get always;

  /// Asks whether to retry the refused operation with sudo. False, or a
  /// dismissed question, leaves the original error standing.
  Future<bool> confirmRetry();

  /// Runs [command] as root. Throws if it could not be run, including when the
  /// user declined to give a password.
  Future<void> run(String command);

  /// Told that an escalation worked, so a caller keeping a "sudo mode" switch
  /// can turn it on rather than asking again for the next file in the same
  /// directory.
  void onEscalated();
}

/// Runs [normal]; if the server refused for want of privilege, offers to run
/// [sudoCommand] as root instead.
///
/// The shape the SFTP page had, lifted out of it so that every operation gets
/// it rather than the ones somebody remembered to wrap.
Future<void> runWithEscalation({
  required Future<void> Function() normal,
  required String Function() sudoCommand,
  SftpEscalation? escalation,
}) async {
  if (escalation != null && escalation.available && escalation.always) {
    await escalation.run(sudoCommand());
    return;
  }

  try {
    await normal();
    return;
  } catch (e) {
    if (escalation == null || !escalation.available || !isPermissionDenied(e)) {
      rethrow;
    }
    if (!await escalation.confirmRetry()) rethrow;
  }

  await escalation.run(sudoCommand());
  escalation.onEscalated();
}

/// Whether an error reads as "you are not allowed to".
///
/// `code 3` is SFTP's `SSH_FX_PERMISSION_DENIED`, and `failure` is what a
/// server sends when it has decided not to be specific — which, for a write it
/// refused, usually means the same thing. Deliberately generous: the cost of
/// asking about something that was not a permission problem is one dialog the
/// user says no to, and the cost of missing one is an operation that just
/// fails.
bool isPermissionDenied(Object? error) {
  final message = '$error'.toLowerCase();
  return message.contains('permission denied') ||
      message.contains('access denied') ||
      message.contains('code 3') ||
      message.contains('failure');
}
