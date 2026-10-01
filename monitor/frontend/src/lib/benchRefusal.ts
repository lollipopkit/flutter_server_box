/// A benchmark request refused before it did anything arrives as a stable code
/// rather than as a sentence, so the panel phrases it in the viewer's own
/// language. So does a run that ended badly: both are strings this agent wrote
/// and both are drawn here.
///
/// The codes are `api::benchmark`'s own. Most are about the request; the two
/// that are not are still words the page has something better to say about than
/// the code does — `unsupported_platform` is the one the page has already drawn
/// above the form, and `already_running` says which of the two buttons to press
/// instead.
///
/// A word this build does not know is shown as the agent sent it: it is a
/// refusal added since, and a sentence invented here would misdescribe it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

export function benchRefusalText(code: string): string {
  const ll = get(LL)
  switch (code) {
    case 'already_running':
      return ll.benchmarkAlreadyRunning()
    case 'unsupported_platform':
      return ll.benchmarkUnsupportedPlatform()
    case 'work_dir_too_long':
      return ll.benchmarkWorkDirTooLong()
    case 'no_home_directory':
      return ll.benchmarkNoHome()
    case 'asset_unreadable':
      return ll.benchmarkAssetUnreadable()
    case 'no_entropy':
      return ll.benchmarkNoEntropy()
    case 'script_not_writable':
      return ll.benchmarkScriptNotWritable()
    case 'start_failed':
      return ll.benchmarkStartFailed()
    case 'history_unavailable':
      return ll.benchmarkHistoryUnavailable()
    case 'no_such_run':
      return ll.benchmarkNoSuchRun()
    case 'run_in_progress':
      return ll.benchmarkRunInProgress()
    default:
      return code
  }
}

/// Why a run in the history ended badly, phrased the same way and for the same
/// reason: the agent records a code, and a row in a fifteen-locale panel is not
/// the place for its English.
export function benchRunErrorText(code: string): string {
  const ll = get(LL)
  switch (code) {
    case 'launcher_failed':
      return ll.benchmarkRunErrorLauncherFailed()
    case 'nonzero_exit':
      return ll.benchmarkRunErrorNonzeroExit()
    case 'no_exit_code':
      return ll.benchmarkRunErrorNoExitCode()
    default:
      return code
  }
}
