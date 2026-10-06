/// The panel's file editor: what the Files page refuses before it opens the
/// editor, and what the editor itself does on save.
///
/// The agent's side of the guard — `if_version` on `PUT /fs/write` — is
/// tested in Rust (`monitor/tests/fs_write.rs`); here the question is only
/// whether the panel sends it and what it does with a 409.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'

const mocks = vi.hoisted(() => ({
  fsRoots: vi.fn(),
  fsList: vi.fn(),
  fsRead: vi.fn(),
  fsWrite: vi.fn(),
  fsStat: vi.fn(),
  fsMkdir: vi.fn(),
  fsRename: vi.fn(),
  fsChmod: vi.fn(),
  fsRemove: vi.fn(),
  saveBlob: vi.fn(),
}))

vi.mock('../lib/api', () => {
  class ApiError extends Error {
    status?: number
    code?: string
    constructor(message: string, status?: number, code?: string) {
      super(message)
      this.status = status
      this.code = code
    }
  }
  return {
    ApiError,
    api: {
      fsRoots: mocks.fsRoots,
      fsList: mocks.fsList,
      fsRead: mocks.fsRead,
      fsWrite: mocks.fsWrite,
      fsStat: mocks.fsStat,
      fsMkdir: mocks.fsMkdir,
      fsRename: mocks.fsRename,
      fsChmod: mocks.fsChmod,
      fsRemove: mocks.fsRemove,
    },
  }
})

vi.mock('../lib/saveBlob', () => ({ saveBlob: mocks.saveBlob }))
vi.mock('../lib/layout.svelte', () => ({ layout: { back: vi.fn() } }))
vi.mock('../lib/servers.svelte', () => ({
  servers: {
    currentId: 'local',
    list: [{ id: 'local', url: '', token: 't', username: 'admin' }],
  },
  displayName: (e: { url: string; id: string }) => e.url || e.id,
}))
vi.mock('../lib/capabilities.svelte', () => ({
  capabilitiesStore: { byServer: {} as Record<string, unknown> },
}))

import Files from '../pages/Files.svelte'
import FileEditor from '../components/FileEditor.svelte'
import { ApiError } from '../lib/api'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import { servers } from '../lib/servers.svelte'
import type { FsEntry } from '../types'

const ROOT = '/srv'

function entry(over: Partial<FsEntry> = {}): FsEntry {
  return {
    name: 'note.txt',
    kind: 'file',
    size: 3,
    modified: 111,
    mode: null,
    link_target: null,
    version: '111-3',
    ...over,
  }
}

/// What the page can do, from the caller's grants. `read` hides the write
/// actions and makes the editor read-only.
function setFiles(mode: 'write' | 'read') {
  ;(capabilitiesStore as unknown as { byServer: Record<string, unknown> }).byServer['local'] = {
    platform: 'linux',
    grants: {
      shell: { ok: true },
      ssh_terminal: { ok: true },
      files: { ok: true, mode },
      connect: { ok: true },
      listen: { ok: true },
    },
  }
}

const textbox = () => screen.getByRole('textbox') as HTMLTextAreaElement

beforeEach(() => {
  for (const fn of Object.values(mocks)) fn.mockReset()
  setFiles('write')
  ;(servers as unknown as { currentId: string }).currentId = 'local'
  mocks.fsRoots.mockResolvedValue({ roots: [ROOT] })
  mocks.fsList.mockResolvedValue([])
  mocks.fsWrite.mockResolvedValue(undefined)
  mocks.fsStat.mockResolvedValue(entry({ modified: 222, version: '222-4' }))
})

afterEach(cleanup)

describe('the Files page opening the editor', () => {
  it('refuses a file over the limit without reading it', async () => {
    mocks.fsList.mockResolvedValue([entry({ name: 'big.txt', size: 2 * 1024 * 1024 })])
    render(Files)
    await screen.findByText('big.txt')

    await fireEvent.click(screen.getByRole('button', { name: 'Edit' }))

    expect(mocks.fsRead).not.toHaveBeenCalled()
    expect(await screen.findByText(/too large/)).toBeInTheDocument()
    expect(screen.queryByRole('textbox')).toBeNull()
  })

  it('refuses a file that is not UTF-8 text', async () => {
    mocks.fsList.mockResolvedValue([entry()])
    // A byte sequence UTF-8 cannot decode, as a binary file's would be.
    mocks.fsRead.mockResolvedValue(new Blob([new Uint8Array([0xff, 0xfe, 0xff])]))
    render(Files)
    await screen.findByText('note.txt')

    await fireEvent.click(screen.getByRole('button', { name: 'Edit' }))

    expect(await screen.findByText(/not UTF-8 text/)).toBeInTheDocument()
    expect(screen.queryByRole('textbox')).toBeNull()
  })

  it('refuses an over-limit file the listing did not size', async () => {
    // `size` is null where the platform did not say, so the listing cannot
    // decide; the bytes that were actually read do.
    mocks.fsList.mockResolvedValue([entry({ size: null })])
    mocks.fsRead.mockResolvedValue(new Blob([new Uint8Array(2 * 1024 * 1024)]))
    render(Files)
    await screen.findByText('note.txt')

    await fireEvent.click(screen.getByRole('button', { name: 'Edit' }))

    expect(await screen.findByText(/too large/)).toBeInTheDocument()
    expect(screen.queryByRole('textbox')).toBeNull()
  })

  it('opens a text file in the editor', async () => {
    mocks.fsList.mockResolvedValue([entry()])
    mocks.fsRead.mockResolvedValue(new Blob(['one']))
    render(Files)
    await screen.findByText('note.txt')

    await fireEvent.click(screen.getByRole('button', { name: 'Edit' }))

    expect(await screen.findByRole('textbox')).toHaveValue('one')
  })
})

describe('FileEditor saving', () => {
  const props = { path: `${ROOT}/note.txt`, entry: entry(), serverId: 'local', canWrite: true }

  it('sends the version it opened the file with', async () => {
    const onsaved = vi.fn()
    render(FileEditor, { props: { ...props, text: 'one', onsaved, onclose: () => {} } })

    await fireEvent.input(textbox(), { target: { value: 'one!' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await vi.waitFor(() => expect(mocks.fsWrite).toHaveBeenCalledTimes(1))
    const [path, body, , ifVersion] = mocks.fsWrite.mock.calls[0]
    expect(path).toBe(`${ROOT}/note.txt`)
    expect(ifVersion).toBe('111-3')
    expect(await (body as Blob).text()).toBe('one!')
    expect(onsaved).toHaveBeenCalled()
  })

  it('keeps the guard when the re-stat after a save fails', async () => {
    // The write landed but the new version could not be read. Dropping the
    // guard would let the *next* save overwrite whatever changed meanwhile
    // without asking; keeping it makes that save a 409 the user answers.
    mocks.fsStat.mockRejectedValue(new ApiError('unreachable'))
    render(FileEditor, { props: { ...props, text: 'one', onsaved: () => {}, onclose: () => {} } })

    await fireEvent.input(textbox(), { target: { value: 'first' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))
    await vi.waitFor(() => expect(mocks.fsWrite).toHaveBeenCalledTimes(1))

    await fireEvent.input(textbox(), { target: { value: 'second' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await vi.waitFor(() => expect(mocks.fsWrite).toHaveBeenCalledTimes(2))
    expect(mocks.fsWrite.mock.calls[1][3]).toBe('111-3')
  })

  it('stays dirty for text typed while a save is in flight', async () => {
    let finish!: () => void
    mocks.fsWrite.mockImplementationOnce(
      () => new Promise<void>((resolve) => (finish = () => resolve())),
    )
    render(FileEditor, { props: { ...props, text: 'one', onsaved: () => {}, onclose: () => {} } })

    await fireEvent.input(textbox(), { target: { value: 'sent' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))
    await vi.waitFor(() => expect(mocks.fsWrite).toHaveBeenCalledTimes(1))

    // Typed while the request is in flight: not what the agent is storing.
    await fireEvent.input(textbox(), { target: { value: 'typed after' } })
    finish()
    await vi.waitFor(() => expect(mocks.fsStat).toHaveBeenCalled())

    expect(await (mocks.fsWrite.mock.calls[0][1] as Blob).text()).toBe('sent')
    expect(textbox()).toHaveValue('typed after')
    // Still a change to save: marking those keystrokes saved would make the
    // dirty marker (and the close confirmation) lie.
    expect(screen.getByRole('button', { name: 'Save' })).toBeEnabled()
  })

  it('refuses to save once the panel has switched servers', async () => {
    render(FileEditor, { props: { ...props, text: 'one', onsaved: () => {}, onclose: () => {} } })
    await fireEvent.input(textbox(), { target: { value: 'one!' } })

    // The same path means a different file on the other machine.
    ;(servers as unknown as { currentId: string }).currentId = 'other'
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    expect(mocks.fsWrite).not.toHaveBeenCalled()
    expect(await screen.findByText(/another server/i)).toBeInTheDocument()
    // The editor stays open with what the user typed.
    expect(textbox()).toHaveValue('one!')
  })

  it('offers Overwrite on a 409, which saves without the guard', async () => {
    mocks.fsWrite.mockRejectedValueOnce(new ApiError('modified', 409, 'modified'))
    render(FileEditor, { props: { ...props, text: 'one', onsaved: () => {}, onclose: () => {} } })

    await fireEvent.input(textbox(), { target: { value: 'mine' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))
    expect(await screen.findByText('This file changed on the server')).toBeInTheDocument()

    await fireEvent.click(screen.getByRole('button', { name: 'Overwrite' }))

    await vi.waitFor(() => expect(mocks.fsWrite).toHaveBeenCalledTimes(2))
    expect(mocks.fsWrite.mock.calls[1][3]).toBeUndefined()
    // The user's text was never thrown away.
    expect(textbox()).toHaveValue('mine')
  })

  it('keeps the file\'s CRLF line endings', async () => {
    render(FileEditor, {
      props: { ...props, text: 'one\r\ntwo', onsaved: () => {}, onclose: () => {} },
    })
    // The textarea holds `\n`; the original ending is what goes back.
    expect(textbox()).toHaveValue('one\ntwo')

    await fireEvent.input(textbox(), { target: { value: 'one\ntwo!' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await vi.waitFor(() => expect(mocks.fsWrite).toHaveBeenCalledTimes(1))
    expect(await (mocks.fsWrite.mock.calls[0][1] as Blob).text()).toBe('one\r\ntwo!')
  })

  it('shows no Save and a readonly field for a read-only role', () => {
    render(FileEditor, {
      props: { ...props, canWrite: false, text: 'one', onsaved: () => {}, onclose: () => {} },
    })

    expect(screen.queryByRole('button', { name: 'Save' })).toBeNull()
    expect(textbox()).toHaveAttribute('readonly')
  })

  it('asks before losing unsaved changes', async () => {
    const onclose = vi.fn()
    render(FileEditor, { props: { ...props, text: 'one', onsaved: () => {}, onclose } })

    await fireEvent.input(textbox(), { target: { value: 'one!' } })
    await fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))

    expect(screen.getByText('Discard your changes?')).toBeInTheDocument()
    expect(onclose).not.toHaveBeenCalled()

    await fireEvent.click(screen.getByRole('button', { name: 'Discard' }))
    expect(onclose).toHaveBeenCalled()
  })
})
