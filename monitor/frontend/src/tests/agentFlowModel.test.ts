import { describe, expect, it } from 'vitest'
import type { Entry, Flow, Message } from '../lib/agentApi'
import { byDay, changesMemory, columns, currentStep, deriveSteps, firstOf, termRows } from '../desk/agent/flowModel'

let seq = 0
const entry = (message: Message): Entry => ({ id: `e${++seq}`, type: 'message', seq, message })
const user = (text: string) => entry({ role: 'user', content: [{ type: 'text', text }] })
const say = (text: string, ...calls: { id: string; name: string; arguments: Record<string, unknown> }[]) =>
  entry({ role: 'assistant', content: [{ type: 'text', text }, ...calls.map((c) => ({ type: 'toolCall' as const, ...c }))] })
const result = (toolCallId: string, details: Record<string, unknown>, isError = false) =>
  entry({ role: 'toolResult', toolCallId, content: [{ type: 'text', text: 'r' }], details, isError })

describe('a task read from its session', () => {
  it('makes a step of each tool call, with what the model said before it', () => {
    const entries = [
      user('update the packages'),
      say('Reading what can be upgraded.', { id: 'c1', name: 'run_command', arguments: { command: 'apt list --upgradable', title: 'Read', area: 'system', effect: 'read' } }),
      result('c1', { exitCode: 0, lines: [[1, 'Listing... Done']], omitted: 0, omittedAt: 1 }),
      say('Here is the plan.', { id: 'c2', name: 'propose_plan', arguments: { title: 'Upgrade', summary: 's', steps: [{ text: 'Upgrade', command: 'apt-get -y upgrade' }] } }),
    ]
    const { prompt, steps } = deriveSteps(entries, 'waiting', { id: 'p', kind: 'confirm', toolCallId: 'c2', title: 'Upgrade' }, null)
    expect(prompt).toBe('update the packages')
    expect(steps.map((s) => [s.kind, s.state, s.title])).toEqual([
      ['command', 'done', 'Read'],
      ['plan', 'waiting', 'Upgrade'],
    ])
    expect(steps[0].summary).toBe('Reading what can be upgraded.')
    expect(steps[0].output).toEqual([[1, 'Listing... Done']])
    expect(steps[1].waiting).toBe('confirm')
    expect(steps[1].plan[0].command).toBe('apt-get -y upgrade')
    expect(currentStep(steps)).toBe(1)
  })

  it('tells a failed command, a declined one and one cut off by a stop apart', () => {
    const entries = [
      user('x'),
      say('', { id: 'a', name: 'run_command', arguments: { command: 'false', title: 'A', area: 'files', effect: 'read' } }),
      result('a', { exitCode: 1, lines: [[2, 'nope']] }),
      say('', { id: 'b', name: 'run_command', arguments: { command: 'rm x', title: 'B', area: 'files', effect: 'danger' } }),
      result('b', { declined: true }),
      say('', { id: 'c', name: 'run_command', arguments: { command: 'sleep 9', title: 'C', area: 'files', effect: 'read' } }),
    ]
    const { steps } = deriveSteps(entries, 'cancelled', null, null)
    expect(steps.map((s) => s.state)).toEqual(['failed', 'cancelled', 'cancelled'])
  })

  it('shows the running command its live output, and the model at work between steps', () => {
    const entries = [
      user('x'),
      say('', { id: 'a', name: 'run_command', arguments: { command: 'apt-get -y upgrade', title: 'Install', area: 'system', effect: 'change' } }),
    ]
    const live = { toolCallId: 'a', lines: [[1, 'Setting up openssl'] as [1, string]], omitted: 3 }
    const running = deriveSteps(entries, 'running', null, live).steps
    expect(running.map((s) => s.state)).toEqual(['running'])
    expect(running[0].output).toEqual(live.lines)
    expect(running[0].omitted).toBe(3)

    const between = deriveSteps([...entries, result('a', { exitCode: 0, lines: [] })], 'running', null, null, 'Now checking')
    expect(between.steps.map((s) => [s.kind, s.state])).toEqual([
      ['command', 'done'],
      ['thinking', 'running'],
    ])
    expect(between.steps[1].summary).toBe('Now checking')
  })

  it('keeps the conversation: an answer without a step is a reply, later words go to the last step', () => {
    const entries = [user('hi'), say('Hello.'), user('again'), say('Hello again.')]
    const { steps } = deriveSteps(entries, 'done', null, null)
    expect(steps).toHaveLength(1)
    expect(steps[0].kind).toBe('reply')
    expect(steps[0].summary).toBe('Hello.')
    expect(steps[0].chat).toEqual([
      { me: true, text: 'again' },
      { me: false, text: 'Hello again.' },
    ])
  })

  it('makes a memory step of a memory tool, done once it answers', () => {
    const entries = [
      user('remember apt'),
      say('Saving.', { id: 'm1', name: 'memory_write', arguments: { path: '/memories/user.md', content: 'apt' } }),
      result('m1', {}),
      say('', { id: 'm2', name: 'memory_view', arguments: {} }),
      result('m2', {}),
    ]
    const { steps } = deriveSteps(entries, 'done', null, null)
    expect(steps.map((s) => [s.kind, s.title, s.state])).toEqual([
      ['memory', '/memories/user.md', 'done'],
      ['memory', '/memories', 'done'],
    ])
    expect(steps.map(changesMemory)).toEqual([true, false])
  })

  it('shows why the model failed', () => {
    const failed = entry({ role: 'assistant', content: [], stopReason: 'error', errorMessage: '401 Unauthorized' })
    const { steps } = deriveSteps([user('hi'), failed], 'failed', null, null)
    expect(steps[0].error).toBe('401 Unauthorized')
  })
})

const flow = (id: string, status: Flow['status'], finishedAt: string | null = null): Flow => ({
  id,
  title: id,
  status,
  line: '',
  areas: [],
  createdAt: '2026-10-09T00:00:00Z',
  updatedAt: finishedAt ?? '2026-10-09T00:00:00Z',
  startedAt: null,
  finishedAt,
  waiting: null,
})

describe('the home page', () => {
  it('puts a failed task with the ones waiting: both need the account', () => {
    const c = columns([flow('a', 'running'), flow('b', 'queued'), flow('c', 'waiting'), flow('d', 'failed'), flow('e', 'done'), flow('f', 'cancelled')])
    expect(c.running.map((f) => f.id)).toEqual(['a'])
    expect(c.queued.map((f) => f.id)).toEqual(['b'])
    expect(c.waiting.map((f) => f.id)).toEqual(['c', 'd'])
    expect(c.done.map((f) => f.id)).toEqual(['e', 'f'])
  })

  it('groups finished tasks by day and keeps the first few', () => {
    const now = new Date(2026, 9, 9, 15, 0)
    const at = (d: number, h: number) => new Date(2026, 9, d, h).toISOString()
    const groups = byDay([flow('a', 'done', at(9, 9)), flow('b', 'done', at(8, 23)), flow('c', 'done', at(6, 1)), flow('d', 'done', at(5, 1))], now)
    expect(groups.map((g) => [g.day, g.flows.map((f) => f.id)])).toEqual([
      ['today', ['a']],
      ['yesterday', ['b']],
      ['earlier', ['c', 'd']],
    ])
    expect(firstOf(groups, 3).map((g) => g.flows.length)).toEqual([1, 1, 1])
  })
})

describe('the output', () => {
  const lines = Array.from({ length: 200 }, (_, i) => [i % 50 === 0 ? 2 : 1, `l${i}`] as [1 | 2, string])

  it('folds a long output and keeps the line numbers', () => {
    const rows = termRows(lines, { errorsOnly: false, expanded: false, omitted: 0, omittedAt: 200, keep: 40 })
    expect(rows).toHaveLength(81)
    expect(rows[40]).toEqual({ fold: 'expand', count: 120 })
    expect(rows[41]).toEqual({ n: 161, line: [1, 'l160'] })
  })

  it('shows errors alone, and the lines the agent did not keep', () => {
    expect(termRows(lines, { errorsOnly: true, expanded: false, omitted: 0, omittedAt: 200 }).length).toBe(4)
    const rows = termRows(lines.slice(0, 4), { errorsOnly: false, expanded: true, omitted: 1000, omittedAt: 2 })
    expect(rows.map((r) => ('n' in r ? r.n : r.fold))).toEqual([1, 2, 'omitted', 1003, 1004])
  })
})
