<script lang="ts">
  /// A text file open in the panel, edited in place.
  ///
  /// The caller reads and decodes the file, and refuses anything that is not
  /// UTF-8 text before mounting this; what arrives here is text. Saving sends
  /// the bytes back through `/fs/write` with the `version` the file had when
  /// it was opened, so a file someone else wrote to since is answered 409
  /// rather than overwritten — the user is asked instead of losing the change.
  import { untrack } from 'svelte'
  import { Button, Checkbox, Dialog, Spinner, Textarea } from '@lollipopkit/desk-ui'
  import { LL } from '../../../i18n/i18n-svelte'
  import { ApiError, api } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import type { FsEntry } from '../../../types'

  interface Props {
    /// The resolved path, as the listing gave it.
    path: string
    /// The entry as listed, for its `version` — the first save's guard.
    entry: FsEntry
    /// The file's text, already decoded by the caller.
    text: string
    /// The machine the file was opened on. `api` writes to whichever server is
    /// current, so a switch under an open editor would put this text on
    /// another machine's file at the same path.
    serverId: string
    /// Whether this account may write. A read-only editor has no Save and a
    /// `readonly` field, rather than a Save that always fails.
    canWrite: boolean
    /// Called after a save lands, so the listing picks up the new size and time.
    onsaved: () => void
    onclose: () => void
  }
  const { path, entry, text, serverId, canWrite, onsaved, onclose }: Props = $props()

  /// Initial values are read once, at mount, and `untrack` says so: the editor
  /// is mounted per file, and a prop changing underneath it is not a case this
  /// component has.

  /// The file's line ending, kept so a file written with `\r\n` goes back that
  /// way. The textarea normalises its value to `\n`, so this is the only place
  /// the original is remembered.
  const crlf = untrack(() => text.includes('\r\n'))

  let value = $state(untrack(() => text.replace(/\r\n/g, '\n')))
  /// What the file holds as far as this editor knows: the value at the last
  /// successful save, or at open. The dirty marker is a difference from it.
  let saved = $state(untrack(() => value))
  /// The `version` the next save states. Re-read after each save so a long
  /// editing session does not conflict with its own earlier write.
  let version = $state<string | null>(untrack(() => entry.version))
  let wrap = $state(false)
  let saving = $state(false)
  let error = $state('')
  /// Set when the agent refused the save because the file moved on.
  let conflict = $state(false)
  /// Set when closing was asked for with unsaved changes in the field.
  let confirmDiscard = $state(false)

  const dirty = $derived(value !== saved)

  /// The text to write, with the file's own line ending restored. A `Blob` of
  /// a string is UTF-8, which is the encoding the file was read as.
  function encoded(text: string): string {
    return crlf ? text.replace(/\n/g, '\r\n') : text
  }

  /// [force] overwrites without the guard — the user's answer to a conflict.
  async function save(force = false) {
    if (!canWrite || saving) return
    // Checked at the moment of the write, not at mount: the sidebar can switch
    // servers under an open editor, and the path means a different file there.
    // The editor is kept open with the user's text.
    if (servers.currentId !== serverId) {
      error = $LL.filesEditorServerChanged()
      return
    }
    saving = true
    error = ''
    // What is sent, captured now: the field may receive keystrokes while the
    // request is in flight, and those are not what the agent stored — marking
    // them saved would make the dirty marker lie.
    const sent = value
    try {
      await api.fsWrite(path, new Blob([encoded(sent)]), undefined, force ? undefined : version)
      try {
        // The next save's guard.
        version = (await api.fsStat(path)).version
      } catch {
        // Kept as it was. Clearing it would drop the guard and let the next
        // save overwrite silently; a stale one makes that save a 409 the user
        // is asked about, which is the direction to fail in.
      }
      saved = sent
      conflict = false
      onsaved()
    } catch (e) {
      // `modified` is the agent saying the file changed under us. Everything
      // else — including a failure to reach the agent — keeps the editor open
      // with the user's text.
      if (e instanceof ApiError && e.code === 'modified') {
        conflict = true
        return
      }
      error = e instanceof Error ? e.message : String(e)
    } finally {
      saving = false
    }
  }

  function requestClose() {
    if (dirty) confirmDiscard = true
    else onclose()
  }

  /// The editor's text is the shell rather than a form field to tab through,
  /// so Tab inserts a tab and leaves focus where it is.
  function onKeydown(e: KeyboardEvent) {
    if (e.key !== 'Tab' || !canWrite) return
    e.preventDefault()
    const el = e.currentTarget as HTMLTextAreaElement
    const start = el.selectionStart
    const end = el.selectionEnd
    el.value = `${el.value.slice(0, start)}\t${el.value.slice(end)}`
    el.selectionStart = el.selectionEnd = start + 1
    // The assignment above is invisible to the binding without this.
    el.dispatchEvent(new Event('input', { bubbles: true }))
  }
</script>

<Dialog open wide title={entry.name} onclose={requestClose} class="max-w-3xl w-full">
  <div class="space-y-[13px]">
    <div class="file-editor-field" class:wrapped={wrap}>
      <Textarea
        class="file-editor-textarea"
        bind:value
        readonly={!canWrite}
        spellcheck="false"
        onkeydown={onKeydown}
        mono
        rows={16}
      />
    </div>

    <div class="flex flex-wrap items-center gap-[9px] text-[13px]">
      <Checkbox bind:checked={wrap} label={$LL.filesEditorWrap()} />
      {#if dirty}<span class="text-(--color-warning)">{$LL.filesEditorUnsaved()}</span>{/if}
    </div>

    {#if error}<p class="text-[13px] text-(--color-danger)">{error}</p>{/if}
  </div>
  {#snippet actions()}
    <Button variant="secondary" onclick={requestClose}>{$LL.cancel()}</Button>
    {#if canWrite}
      <Button onclick={() => void save()} disabled={saving || !dirty}>
        {#if saving}<Spinner size={16} />{/if}
        {$LL.save()}
      </Button>
    {/if}
  {/snippet}
</Dialog>

<style>
  .file-editor-field :global(.lk-textarea) {
    height: 20rem;
    resize: vertical;
    border-radius: 9px;
    background: var(--surface-terminal);
    padding: 11px 15px;
    font-size: 13px;
    color: var(--text-primary);
    white-space: pre;
  }

  .file-editor-field.wrapped :global(.lk-textarea) {
    white-space: pre-wrap;
  }
</style>

{#if conflict}
  <Dialog open title={$LL.filesEditorConflictTitle()} message={$LL.filesEditorConflictBody()} onclose={() => (conflict = false)}>
    {#snippet actions()}
      <Button variant="destructive" onclick={() => void save(true)} disabled={saving}>
        {#if saving}<Spinner size={16} />{/if}
        {$LL.filesEditorOverwrite()}
      </Button>
      <Button variant="secondary" onclick={() => (conflict = false)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if confirmDiscard}
  <Dialog open title={$LL.filesEditorDiscardTitle()} message={$LL.filesEditorDiscardBody()} onclose={() => (confirmDiscard = false)}>
    {#snippet actions()}
      <Button variant="destructive" onclick={() => {
        confirmDiscard = false
        onclose()
      }}>{$LL.filesEditorDiscard()}</Button>
      <Button variant="secondary" onclick={() => (confirmDiscard = false)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}
