/// The steps `/snippets/plan` answers with, driven into a terminal.
///
/// Separated from the page that runs them because this is the half worth
/// asserting without a DOM or a socket: which bytes `${ctrl+c}` sends, what
/// `${sleep 2}` waits for, and the fact that the two are one ordered sequence.
/// The agent decides *what* the steps are — this module only carries them out,
/// so a script means the same thing in both clients.
import type { SnippetStep } from '../types'

/// Where the keystrokes go.
///
/// One function taking text, because a terminal takes text: a control character
/// and an Enter are bytes like any other, and this is the shape `Terminal`'s
/// input already has. A sink that has gone stale — the pane closed, another
/// server selected — is the sink's own business to ignore, which is why this is
/// a callback rather than a session.
export type StepSink = (text: string) => void

/// Waits. Replaceable so a test does not spend the script's own delays.
export type Sleeper = (seconds: number) => Promise<void>

/// Whether the rest of the script should still be typed, asked between steps.
///
/// A script is typed into one shell, and a shell that went away between two
/// steps must not receive the second half: a reconnect rejoins the same shell,
/// but a session that was ended and opened again is a different one, and half a
/// script typed into it runs against a machine state nobody chose. That it also
/// serves a stop button is the same question asked by the operator.
export type KeepAlive = () => boolean

export const realSleep: Sleeper = (seconds) =>
  new Promise((resolve) => setTimeout(resolve, seconds * 1000))

/// Enter. A terminal's Return key is a carriage return, not a newline: the line
/// discipline is the tty's, and `\n` is what a *shell* writes, not what a
/// keyboard sends.
const ENTER = '\r'

/// The bytes one step contributes, without any waiting.
///
/// Exported for its own test and for the page to show what a step is about to
/// do; `runSteps` is what a caller normally wants.
///
/// The two modifiers are encoded the way a terminal's own key input encodes
/// them rather than as a convention of this panel's: Alt is the ESC prefix, and
/// Ctrl is the character's low five bits — `0x01` for `a`, `0x03` for `c`. A
/// key that has no such form (`${ctrl+1}`) keeps its own value, which is what
/// the tty receives for it too.
export function stepText(step: SnippetStep): string {
  switch (step.type) {
    case 'text':
      return step.text
    case 'enter':
      return ENTER.repeat(step.times)
    case 'sleep':
      return ''
    case 'combo': {
      const key = step.ctrl ? withCtrl(step.key) : step.key
      return `${step.alt ? '\x1b' : ''}${key}${step.rest}`
    }
  }
}

/// The character with Ctrl held, as the byte a tty reads for it.
function withCtrl(key: string): string {
  const code = key.codePointAt(0) ?? 0
  // `& 0x1f` is the whole of the mapping for the characters that have one:
  // `@`, `A`–`Z`, `[`, `\`, `]`, `^`, `_` become 0x00–0x1f, and the lowercase
  // range lands on the same values as its uppercase form.
  return code >= 0x40 && code <= 0x7f ? String.fromCharCode(code & 0x1f) : key
}

/// Types the whole script, waiting where it says to.
///
/// Refuses nothing and returns nothing: the agent has already rejected a script
/// it cannot expand, so every step here is one it asked for. The waits are
/// sequential and the whole thing is one sequence — `${sleep 2}ls` must not
/// type the list before the two seconds are up, since that is the difference
/// between a script and two keystrokes.
///
/// A step in progress is never interrupted: a keystroke is not a step that
/// takes time, and a sleep that stopped early would send the next command to a
/// machine that is not ready for it.
export async function runSteps(
  steps: SnippetStep[],
  sink: StepSink,
  sleep: Sleeper = realSleep,
  keepAlive?: KeepAlive,
): Promise<void> {
  for (const step of steps) {
    if (keepAlive && !keepAlive()) return
    if (step.type === 'sleep') {
      await sleep(step.seconds)
      continue
    }
    sink(stepText(step))
  }
}
