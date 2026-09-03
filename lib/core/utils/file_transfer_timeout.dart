/// Shared floor for transfer stream timeouts.
///
/// Commands answer at once or not at all; transfers are bounded by the gap
/// between bytes. Five seconds of silence on a slow link is not a stall.
/// Both SFTP and SCP backends therefore floor their stream timeout at 60s
/// (see SftpIdleWatchdog.minIdle).
library;

const kMinTransferStreamTimeout = Duration(seconds: 60);

/// Returns `timeout` bounded below by [kMinTransferStreamTimeout], or null
/// if [timeout] is null (wait forever, as transfers with their own progress do).
Duration? transferStreamTimeout(Duration? timeout) {
  if (timeout == null) return null;
  return timeout < kMinTransferStreamTimeout
      ? kMinTransferStreamTimeout
      : timeout;
}
