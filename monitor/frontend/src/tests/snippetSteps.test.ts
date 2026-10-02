import { describe, expect, it } from 'vitest'
import { runSteps, stepText } from '../lib/snippetSteps'
import type { SnippetStep } from '../types'

/// What a step contributes, as the bytes a terminal receives. The four arms of
/// `SnippetStep` are `sbm_parser::snippet::Step`'s and the agent is the one that
/// produced them, so what is asserted here is the reading rather than the
/// grammar: a change to `${ctrl+c}` in Rust that this module did not follow
/// would send a different byte than the app sends for the same script.
describe('what a step types', () => {
  it('sends text as written', () => {
    expect(stepText({ type: 'text', text: 'systemctl restart nginx' })).toBe(
      'systemctl restart nginx',
    )
  })

  it('sends Return rather than a newline', () => {
    // A keyboard's Return is `\r`. `\n` is what a shell *writes*, and a tty in
    // canonical mode treats the two differently.
    expect(stepText({ type: 'enter', times: 1 })).toBe('\r')
    expect(stepText({ type: 'enter', times: 2 })).toBe('\r\r')
  })

  it('sends nothing for a wait', () => {
    expect(stepText({ type: 'sleep', seconds: 30 })).toBe('')
  })

  it('sends Ctrl as the character low five bits', () => {
    // The whole of the mapping for the characters that have one: `c` and `C`
    // land on 0x03, `[` on 0x1b, `@` on 0x00.
    expect(stepText({ type: 'combo', ctrl: true, alt: false, key: 'c', rest: '' })).toBe('\x03')
    expect(stepText({ type: 'combo', ctrl: true, alt: false, key: 'C', rest: '' })).toBe('\x03')
    expect(stepText({ type: 'combo', ctrl: true, alt: false, key: '[', rest: '' })).toBe('\x1b')
    expect(stepText({ type: 'combo', ctrl: true, alt: false, key: '@', rest: '' })).toBe('\x00')
  })

  it('sends Alt as the escape prefix', () => {
    expect(stepText({ type: 'combo', ctrl: false, alt: true, key: 'x', rest: '' })).toBe('\x1bx')
    // Both held: the prefix goes first, as a terminal's own key input has it.
    expect(stepText({ type: 'combo', ctrl: true, alt: true, key: 'c', rest: '' })).toBe('\x1b\x03')
  })

  it('keeps a key that has no control form', () => {
    // `${ctrl+1}` is a script the shared language allows and the tty reads as
    // the character itself; dropping it would type nothing at all.
    expect(stepText({ type: 'combo', ctrl: true, alt: false, key: '1', rest: '' })).toBe('1')
  })

  it('sends what follows the key', () => {
    // `rest` is the tail the parser kept from one directive, sent in the same
    // keystroke group as the key it belongs to.
    expect(stepText({ type: 'combo', ctrl: true, alt: false, key: 'c', rest: 'ls' })).toBe('\x03ls')
  })
})

describe('the whole script', () => {
  /// The steps in order, with the sink's output and the sleeps recorded.
  async function drive(steps: SnippetStep[], keepAlive?: () => boolean) {
    const typed: string[] = []
    const waited: number[] = []
    await runSteps(
      steps,
      (text) => typed.push(text),
      async (seconds) => {
        waited.push(seconds)
      },
      keepAlive,
    )
    return { typed, waited }
  }

  it('types in order and waits where it says to', async () => {
    const { typed, waited } = await drive([
      { type: 'text', text: 'ls' },
      { type: 'enter', times: 1 },
      { type: 'sleep', seconds: 2 },
      { type: 'text', text: 'df -h' },
      { type: 'enter', times: 1 },
    ])
    expect(typed).toEqual(['ls', '\r', 'df -h', '\r'])
    expect(waited).toEqual([2])
  })

  it('waits before typing what follows the wait', async () => {
    // The order of the two is the whole meaning of `${sleep 2}df -h`: a script
    // that typed the command first would be two keystrokes rather than one
    // script, and the machine would be asked before it was ready.
    const order: string[] = []
    await runSteps(
      [
        { type: 'sleep', seconds: 2 },
        { type: 'text', text: 'df -h' },
      ],
      (text) => order.push(`typed ${text}`),
      async () => {
        order.push('waited')
      },
    )
    expect(order).toEqual(['waited', 'typed df -h'])
  })

  it('stops between steps when the shell is gone', async () => {
    const typed: string[] = []
    let alive = true
    await runSteps(
      [
        { type: 'text', text: 'first' },
        { type: 'text', text: 'second' },
        { type: 'text', text: 'third' },
      ],
      (text) => {
        typed.push(text)
        // The socket dropped while the first command was being typed.
        alive = false
      },
      async () => {},
      () => alive,
    )
    // A step in flight is not interrupted — half a command is one nobody wrote
    // — and the rest is not typed into a shell that may be a different one.
    expect(typed).toEqual(['first'])
  })

  it('types everything when nothing says otherwise', async () => {
    const { typed } = await drive([
      { type: 'text', text: 'a' },
      { type: 'text', text: 'b' },
    ])
    expect(typed).toEqual(['a', 'b'])
  })
})
