import { describe, expect, it } from 'vitest'
import {
  attachProgramStatus,
  parseProgress,
  parseReport,
  ProgramStatusRecords,
  QUERY_REPLY,
  type OscParser,
} from '../lib/programStatus'

const b64 = (text: string) => btoa(String.fromCharCode(...new TextEncoder().encode(text)))

describe('parseReport', () => {
  it('reads every key', () => {
    expect(
      parseReport(
        `state=blocked:kind=permission:progress=40:app=terraform:id=deploy/us-east:title=${b64('US East')}:msg=${b64('Apply 3?')}`,
      ),
    ).toEqual({
      state: 'blocked',
      id: ['deploy', 'us-east'],
      kind: 'permission',
      progress: 40,
      app: 'terraform',
      title: 'US East',
      msg: 'Apply 3?',
    })
  })

  it('requires a known state, skips malformed pairs, last value wins', () => {
    expect(parseReport('app=x')).toBeNull()
    expect(parseReport('state=busy')).toBeNull()
    expect(parseReport('junk:=x:state=idle:foo=bar:state=done')?.state).toBe('done')
    expect(parseReport('state=clear')).toEqual({ state: null, id: [] })
  })

  it('refuses what the spec refuses', () => {
    expect(parseReport('state=idle:abcdefghijklmnopq=1')).toBeNull()
    expect(parseReport('state=idle:id=a//b')).toBeNull()
    expect(parseReport(`state=idle:id=${Array(9).fill('a').join('/')}`)).toBeNull()
    expect(parseReport(`state=done:msg=${b64('a\nb')}`)).toBeNull()
    expect(parseReport(`state=done:msg=${b64('a'.repeat(2049))}`)).toBeNull()
    expect(parseReport(`state=done:app=${'a'.repeat(33)}`)).toBeNull()
    expect(parseReport(`state=done:x=${'a'.repeat(4100)}`)).toBeNull()
  })

  it('keeps kind and progress only where they apply, and strips invisibles', () => {
    expect(parseReport('state=done:kind=auth:progress=10')).toEqual({ state: 'done', id: [] })
    expect(parseReport('state=done:msg=aGk')?.msg).toBe('hi')
    expect(parseReport(`state=done:msg=${b64('a\u202Eb\u200Bc')}`)?.msg).toBe('abc')
  })
})

describe('parseProgress', () => {
  it('maps OSC 9;4 and leaves OSC 9 notifications alone', () => {
    expect(parseProgress('4;0')).toBeNull()
    expect(parseProgress('4;1;50')).toEqual({ state: 'normal', percent: 50 })
    expect(parseProgress('4;3;20')).toEqual({ state: 'indeterminate' })
    expect(parseProgress('4;9')).toBeUndefined()
    expect(parseProgress('hello')).toBeUndefined()
  })
})

describe('ProgramStatusRecords', () => {
  const report = (payload: string) => parseReport(payload)!

  it('replaces, clears with descendants, and evicts the least recent', () => {
    const records = new ProgramStatusRecords(3)
    records.report(report('state=working:app=deploy'))
    records.report(report('state=working:id=a'))
    records.report(report('state=blocked:id=a/b'))
    expect(records.appOf(records.records[2])).toBe('deploy')
    records.report(report('state=clear:id=a'))
    expect(records.records.map((r) => r.key)).toEqual([''])
    for (const id of ['x', 'y', 'z']) records.report(report(`state=idle:id=${id}`))
    expect(records.records.map((r) => r.key)).toEqual(['x', 'y', 'z'])
  })

  it('a prompt or exit drops what only lasts while running', () => {
    const records = new ProgramStatusRecords()
    for (const p of ['state=working:id=w', 'state=blocked:id=b', 'state=done:id=d', 'state=error:id=e']) {
      records.report(report(p))
    }
    records.setProgress({ state: 'normal', percent: 5 })
    expect(records.state).toBe('blocked')
    records.mark('A')
    expect(records.records.map((r) => r.key)).toEqual(['d', 'e'])
    expect(records.progress).toBeNull()
    records.report(report('state=working'))
    records.processExited()
    expect(records.state).toBe('error')
  })
})

describe('attachProgramStatus', () => {
  function fakeParser() {
    const osc = new Map<number, (data: string) => boolean | Promise<boolean>>()
    let esc: (() => boolean | Promise<boolean>) | undefined
    const parser: OscParser = {
      registerOscHandler(ident, callback) {
        osc.set(ident, callback)
        return { dispose: () => osc.delete(ident) }
      },
      registerEscHandler(_id, callback) {
        esc = callback
        return { dispose: () => (esc = undefined) }
      },
    }
    return { parser, osc, ris: () => esc?.() }
  }

  it('feeds records, answers the query, and lets other OSC 9 through', () => {
    const { parser, osc, ris } = fakeParser()
    const records = new ProgramStatusRecords()
    const replies: string[] = []
    const detach = attachProgramStatus(parser, records, (d) => replies.push(d))

    expect(osc.get(7501)!('?')).toBe(true)
    expect(replies).toEqual([QUERY_REPLY])
    expect(osc.get(7501)!('state=bogus')).toBe(true)
    expect(osc.get(7501)!('state=done')).toBe(true)
    expect(osc.get(9)!('hello')).toBe(false)
    expect(osc.get(9)!('4;2')).toBe(true)
    osc.get(133)!('D;1')
    expect(records.command).toEqual({ running: false, exitCode: 1 })
    expect(records.state).toBe('error')

    expect(ris()).toBe(false)
    expect(records.isEmpty).toBe(true)
    detach()
    expect(osc.size).toBe(0)
  })
})
