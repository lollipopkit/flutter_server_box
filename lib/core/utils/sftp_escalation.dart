import 'dart:async';

import 'package:server_box/data/model/file/file_issue.dart';

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

  /// Runs [command] as root and answers what it printed. Throws if it could
  /// not be run, including when the user declined to give a password.
  ///
  /// The output matters because reading is escalated too: a directory this
  /// user may not list is exactly the case sudo exists for, and a `list` that
  /// could only be told "it worked" would have nothing to show.
  Future<String> run(String command);

  /// Told that an escalation worked, so a caller keeping a "sudo mode" switch
  /// can turn it on rather than asking again for the next file in the same
  /// directory.
  void onEscalated();
}

/// Runs [normal]; if the server refused for want of privilege, offers to run
/// [sudoCommand] as root instead and reads the answer back out of its output.
///
/// The shape the SFTP page had, lifted out of it so that every operation gets
/// it rather than the ones somebody remembered to wrap.
Future<T> escalate<T>({
  required Future<T> Function() normal,
  required String Function() sudoCommand,
  required FutureOr<T> Function(String output) fromOutput,
  SftpEscalation? escalation,
}) async {
  if (escalation != null && escalation.available && escalation.always) {
    return await fromOutput(await escalation.run(sudoCommand()));
  }

  try {
    return await normal();
  } catch (e) {
    if (escalation == null || !escalation.available || !isPermissionDenied(e)) {
      rethrow;
    }
    if (!await escalation.confirmRetry()) rethrow;
  }

  final result = await fromOutput(await escalation.run(sudoCommand()));
  escalation.onEscalated();
  return result;
}

/// [escalate] for an operation with nothing to report but whether it worked.
Future<void> runWithEscalation({
  required Future<void> Function() normal,
  required String Function() sudoCommand,
  SftpEscalation? escalation,
}) => escalate<void>(
  escalation: escalation,
  normal: normal,
  sudoCommand: sudoCommand,
  fromOutput: (_) {},
);

/// Whether an error reads as "you are not allowed to".
///
/// One classifier, shared with the page that has to name the same failures on
/// screen: "offer sudo" and "say permission denied" must not be able to
/// disagree about the same error.
bool isPermissionDenied(Object? error) =>
    classifyFileError(error) == FileIssue.denied;
