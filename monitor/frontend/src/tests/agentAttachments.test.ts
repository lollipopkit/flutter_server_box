import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { Upload } from '../lib/agentApi'

type Pending = { name: string; resolve: (u: Upload) => void; reject: (e: unknown) => void; progress?: (p: number) => void; signal?: AbortSignal }
let uploads: Pending[] = []
const discard = vi.fn(async () => {})

vi.mock('../lib/agentApi', () => ({
  agentApi: {
    upload: vi.fn(
      (_e: unknown, _b: Blob, name: string, opts: { onProgress?: (p: number) => void; signal?: AbortSignal } = {}) =>
        new Promise<Upload>((resolve, reject) => {
          uploads.push({ name, resolve, reject, progress: opts.onProgress, signal: opts.signal })
          opts.signal?.addEventListener('abort', () => reject(new Error('aborted')))
        }),
    ),
    discard: (...a: unknown[]) => discard(...(a as [])),
  },
}))

const { Attachments } = await import('../desk/agent/attachments.svelte')
const { autosize } = await import('../desk/agent/autosize')

const entry = { url: 'https://127.0.0.1:3770', token: 't', id: 's' } as never
const file = (name: string, size: number, type = 'text/plain') => new File([new Uint8Array(size)], name, { type })
const settle = () => new Promise((r) => setTimeout(r, 0))

describe('Attachments', () => {
  beforeEach(() => {
    uploads = []
    discard.mockClear()
    URL.createObjectURL = vi.fn(() => 'blob:x')
    URL.revokeObjectURL = vi.fn()
  })

  it('uploads each file as it is added and reports how far it got', async () => {
    const a = new Attachments(entry)
    a.addFiles([file('app.log', 10)])
    expect(a.items[0]).toMatchObject({ name: 'app.log', glyph: 'description', id: null, progress: 0 })
    uploads[0].progress?.(0.5)
    expect(a.items[0].progress).toBe(0.5)
    uploads[0].resolve({ id: 'u1', name: 'app.log', mime: 'text/plain', size: 10 })
    expect(await a.ids()).toEqual(['u1'])
  })

  it('refuses a file over the limit before sending it', () => {
    const a = new Attachments(entry)
    a.addFiles([file('big.iso', (20 << 20) + 1)])
    expect(a.items).toHaveLength(0)
    expect(uploads).toHaveLength(0)
    expect(a.error).toContain('big.iso')
  })

  it('takes a long paste as a file and leaves a short one to the field', () => {
    const a = new Attachments(entry)
    const paste = (text: string) => ({ clipboardData: { files: [], getData: () => text } }) as unknown as ClipboardEvent
    expect(a.paste(paste('short'))).toBe(false)
    expect(a.paste(paste('1\n2\n3\n4'))).toBe(true)
    expect(a.items[0]).toMatchObject({ glyph: 'article' })
    expect(uploads[0].name).toBe('pasted.txt')
  })

  it('removing one stops its upload, or drops what already arrived', async () => {
    const a = new Attachments(entry)
    a.addFiles([file('a.txt', 1), file('b.txt', 1)])
    uploads[1].resolve({ id: 'u2', name: 'b.txt', mime: 'text/plain', size: 1 })
    await settle()
    a.remove(a.items[0])
    expect(uploads[0].signal?.aborted).toBe(true)
    await settle()
    // An abort is not an error to show.
    expect(a.error).toBeNull()
    a.remove(a.items[0])
    expect(discard).toHaveBeenCalledWith(entry, 'u2')
    expect(a.items).toHaveLength(0)
  })

  it('has no ids while one failed, and clearing drops the uploads', async () => {
    const a = new Attachments(entry)
    a.addFiles([file('a.txt', 1), file('b.txt', 1)])
    uploads[0].resolve({ id: 'u1', name: 'a.txt', mime: 'text/plain', size: 1 })
    uploads[1].reject(new Error('boom'))
    expect(await a.ids()).toBeNull()
    expect(a.items[1].failed).toBe(true)
    a.clear(true)
    expect(discard).toHaveBeenCalledWith(entry, 'u1')
    expect(a.items).toHaveLength(0)
  })
})

describe('autosize', () => {
  beforeEach(() => {
    globalThis.ResizeObserver = class {
      cb: ResizeObserverCallback
      constructor(cb: ResizeObserverCallback) {
        this.cb = cb
      }
      observe() {}
      disconnect() {}
    } as never
  })

  function area(scrollHeight: number): HTMLTextAreaElement {
    const ta = document.createElement('textarea')
    ta.style.fontSize = '20px'
    ta.style.lineHeight = '28px'
    ta.style.padding = '3px 0'
    Object.defineProperty(ta, 'scrollHeight', { get: () => scrollHeight })
    document.body.append(ta)
    return ta
  }

  it('stays one line, in the stylesheet, until the text needs more', () => {
    const ta = area(28 + 6)
    const multi = vi.fn()
    ta.value = 'one line'
    autosize(ta, { value: ta.value, onmulti: multi })
    expect(ta.style.height).toBe('')
    expect(multi).not.toHaveBeenCalled()
  })

  it('grows in em, so it follows the font size, and scrolls past the most lines', () => {
    const ta = area(3 * 28 + 6)
    const multi = vi.fn()
    ta.value = 'a\nb\nc'
    const a = autosize(ta, { value: ta.value, onmulti: multi })
    expect(ta.style.height).toBe('calc(4.2em + 6px)')
    expect(ta.style.overflowY).toBe('hidden')
    expect(multi).toHaveBeenLastCalledWith(true)
    a.update({ value: ta.value, max: 2, onmulti: multi })
    expect(ta.style.height).toBe('calc(2.8em + 6px)')
    expect(ta.style.overflowY).toBe('auto')
    ta.value = ''
    a.update({ value: '', onmulti: multi })
    expect(ta.style.height).toBe('')
    expect(multi).toHaveBeenLastCalledWith(false)
  })
})
