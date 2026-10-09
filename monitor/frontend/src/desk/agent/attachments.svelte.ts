/// Files given with what the account types into Agent mode (a new task or a
/// reply): picked, pasted or dropped, each uploaded as it is added
/// (`POST /agent/files`), so sending only names them.

import { get } from 'svelte/store'
import { LL } from '../../i18n/i18n-svelte'
import { agentApi, type Upload } from '../../lib/agentApi'
import { fmtBytes } from '../../lib/format'
import type { ServerEntry } from '../../lib/servers.svelte'
import { fileGlyph } from './agentView'

/// The agent's limits (`agent_mode/files.rs`).
const MAX_BYTES = 20 << 20
const MAX_FILES = 10

export interface Att {
  key: number
  name: string
  meta: string
  glyph: string
  /// An object URL of an image, or empty.
  thumb: string
  upload: Promise<Upload | null>
  id: string | null
  failed: boolean
}

export class Attachments {
  items = $state<Att[]>([])
  error = $state<string | null>(null)
  #seq = 0
  readonly #entry: ServerEntry

  constructor(entry: ServerEntry) {
    this.#entry = entry
  }

  get length(): number {
    return this.items.length
  }

  #add(blob: Blob, uploadName: string, display: Pick<Att, 'name' | 'meta' | 'glyph' | 'thumb'>) {
    const t = get(LL)
    if (this.items.length >= MAX_FILES) {
      this.error = t.deskAgentUploadFailed({ name: display.name, reason: `≤ ${MAX_FILES}` })
      return
    }
    if (blob.size > MAX_BYTES) {
      this.error = t.deskAgentFileTooBig({ name: display.name })
      return
    }
    const key = ++this.#seq
    const upload = agentApi
      .upload(this.#entry, blob, uploadName)
      .then((u) => {
        const a = this.items.find((x) => x.key === key)
        if (a) a.id = u.id
        // Removed while it was on its way.
        else void agentApi.discard(this.#entry, u.id).catch(() => {})
        return u
      })
      .catch((e) => {
        const a = this.items.find((x) => x.key === key)
        if (a) a.failed = true
        this.error = t.deskAgentUploadFailed({ name: display.name, reason: e instanceof Error ? e.message : String(e) })
        return null
      })
    this.items.push({ ...display, key, upload, id: null, failed: false })
  }

  addFiles(list: FileList | File[] | null | undefined) {
    for (const f of Array.from(list ?? [])) {
      const name = f.name || 'file'
      this.#add(f, name, { name, meta: fmtBytes(f.size), glyph: fileGlyph(name, f.type), thumb: f.type.startsWith('image/') ? URL.createObjectURL(f) : '' })
    }
  }

  addPaste(text: string) {
    const t = get(LL)
    const blob = new Blob([text], { type: 'text/plain' })
    this.#add(blob, 'pasted.txt', {
      name: t.deskAgentPasted(),
      meta: t.deskAgentPastedMeta({ lines: text.split('\n').length.toLocaleString(), size: fmtBytes(blob.size) }),
      glyph: 'article',
      thumb: '',
    })
  }

  /// Takes the files from a paste, and a long paste (a log) as a file;
  /// whether it took it.
  paste(e: ClipboardEvent): boolean {
    const cd = e.clipboardData
    if (!cd) return false
    const files = Array.from(cd.files ?? [])
    if (files.length) {
      this.addFiles(files)
      return true
    }
    const text = cd.getData('text')
    if (text && (text.length > 240 || text.split('\n').length > 3)) {
      this.addPaste(text)
      return true
    }
    return false
  }

  remove(a: Att) {
    if (a.thumb) URL.revokeObjectURL(a.thumb)
    this.items = this.items.filter((x) => x.key !== a.key)
    if (a.id) void agentApi.discard(this.#entry, a.id).catch(() => {})
  }

  /// Empties it; [discard] also drops the uploads, which nothing took.
  clear(discard: boolean) {
    for (const a of this.items) {
      if (a.thumb) URL.revokeObjectURL(a.thumb)
      if (discard && a.id) void agentApi.discard(this.#entry, a.id).catch(() => {})
    }
    this.items = []
    this.error = null
  }

  /// The uploads' ids once all have arrived; `null` when one failed.
  async ids(): Promise<string[] | null> {
    const uploads = await Promise.all(this.items.map((a) => a.upload))
    return uploads.every((u) => u) ? uploads.map((u) => u!.id) : null
  }
}
