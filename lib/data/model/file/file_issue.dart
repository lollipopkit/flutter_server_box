/// What a failed file operation actually means.
///
/// Read out of the error's text rather than its type, because the same four
/// answers arrive as `PathNotFoundException` from `dart:io`, as
/// `SftpStatusError` from a server, and one day as an HTTP status from a
/// monitor agent. A page that wants to say "this folder is gone" should not
/// have to know which of those it is looking at.
///
/// Deliberately generous, and ordered: the cost of guessing wrong is a heading
/// that is less specific than it could be, with the server's own words printed
/// underneath either way.
enum FileIssue {
  /// Nothing there — deleted, renamed, or never existed.
  notFound,

  /// This user is not allowed to. The one that has a way past it, where the
  /// backend has a shell behind it.
  denied,

  /// The far side stopped answering.
  timeout,

  unknown,
}

FileIssue classifyFileError(Object? error) {
  final message = '$error'.toLowerCase();

  // First, because a "no such file" is often reported with words that the
  // refusal test below would also match.
  if (message.contains('no such file') ||
      message.contains('pathnotfoundexception') ||
      // `SSH_FX_NO_SUCH_FILE`, as dartssh2 prints it.
      message.contains('code 2')) {
    return FileIssue.notFound;
  }

  if (message.contains('timed out') || message.contains('timeout')) {
    return FileIssue.timeout;
  }

  // `code 3` is `SSH_FX_PERMISSION_DENIED`, and `failure` is what a server
  // sends when it has decided not to be specific — which, for a write it
  // refused, usually means the same thing. 403 is a monitor agent refusing a
  // path outside the roots it serves; matched on dio's whole phrase rather
  // than on the bare number, which a path is free to contain.
  if (message.contains('permission denied') ||
      message.contains('access denied') ||
      message.contains('status code of 403') ||
      message.contains('403 forbidden') ||
      message.contains('code 3') ||
      message.contains('failure')) {
    return FileIssue.denied;
  }

  return FileIssue.unknown;
}
