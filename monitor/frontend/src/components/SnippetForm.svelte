<script module lang="ts">
  import type { Snippet } from '../types'

  /// The form's own fields, in the shapes the form edits: the tags are one text
  /// field, because a list that is typed is a list of words separated by
  /// commas, and a chip editor would be a second thing to learn before the
  /// first snippet can be saved.
  ///
  /// The page owns this object and seeds it when the dialog opens, the way the
  /// desktops page does: a form that seeded itself from a snippet prop would be
  /// holding a copy of a row the next save may replace.
  export interface SnippetFormState {
    id: string
    name: string
    script: string
    note: string
    tags: string
  }

  /// What a form opens with, for a new snippet or for one being changed.
  ///
  /// A new snippet is given its id here rather than at the save, so the dialog
  /// is about one definite snippet from the moment it opens — an id minted at
  /// the save would make the button's meaning depend on a value nothing on
  /// screen shows.
  export function snippetFormState(snippet?: Snippet): SnippetFormState {
    return {
      id: snippet?.id ?? newSnippetId(),
      name: snippet?.name ?? '',
      script: snippet?.script ?? '',
      note: snippet?.note ?? '',
      tags: snippet?.tags.join(', ') ?? '',
    }
  }

  /// An identity for a snippet this client is about to add.
  ///
  /// `randomUUID` is absent outside a secure context, which a panel served over
  /// plain HTTP from a LAN address is — a setup the terminal supports
  /// (`allow_insecure`). It costs nothing here: no endpoint takes a snippet id,
  /// a `PUT` sends the whole set, and the id is an identity within one library
  /// rather than a secret.
  export function newSnippetId(): string {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID()
    }
    return `s-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`
  }

  /// The tags the set should hold, read out of the one text field they are
  /// typed into.
  ///
  /// An empty entry is dropped — a trailing comma is how a list is spelled, not
  /// a tag with no name — while a repeated one is kept as typed, because the
  /// agent refuses that as `duplicateTag` and the same word twice is a thing
  /// the operator can see and act on. Normalising one away would leave the save
  /// succeeding with a list that differs from the field above it.
  export function tagListOf(tags: string): string[] {
    return tags
      .split(',')
      .map((tag) => tag.trim())
      .filter((tag) => tag.length > 0)
  }

  /// The snippet the set should hold: the whole of it, not only what changed,
  /// because a `PUT` replaces the library.
  export function snippetDraftOf(fields: SnippetFormState): Snippet {
    return {
      id: fields.id,
      name: fields.name.trim(),
      script: fields.script,
      note: fields.note.trim(),
      tags: tagListOf(fields.tags),
    }
  }
</script>

<script lang="ts">
  import { Button, Input } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'

  interface Props {
    /// The snippet being changed, or `undefined` for a new one.
    snippet?: Snippet
    /// The fields, seeded by the page and edited here in place.
    fields: SnippetFormState
    /// Called with the snippet once the page's request is accepted. The page
    /// owns the list, the request and the notice; this owns the fields.
    onsaved: (snippet: Snippet) => void
    oncancel: () => void
  }

  const { snippet, fields, onsaved, oncancel }: Props = $props()

  /// Derived rather than read once: the dialog is remounted per open, but a
  /// plain `const` still reads as a snapshot to the compiler.
  const editing = $derived(snippet !== undefined)

  /// The macro spellings the shared language defines, written as they are
  /// typed. A code sample rather than a translated sentence: `${host}` is
  /// syntax the agent reads, and a locale that translated it would describe a
  /// script nothing expands. The sentence beside them is the translation.
  const macros = ['${host}', '${user}', '${port}', '${pwd}', '${sleep 2}', '${enter 2}', '${ctrl+c}']
</script>

<div class="space-y-4">
  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="snippet-name">{$LL.snippetName()}</label>
    <Input id="snippet-name" bind:value={fields.name} placeholder="Restart nginx" />
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="snippet-script">{$LL.snippetScript()}</label>
    <!-- A raw textarea rather than an `Input`: a script is several lines, and
         the terminal's own private-key field is the same control for the same
         reason. Monospace, because the whitespace in a script is part of it. -->
    <textarea
      id="snippet-script"
      bind:value={fields.script}
      rows="8"
      spellcheck="false"
      placeholder="systemctl restart nginx"
      class="w-full rounded-md border border-line bg-bg px-3 py-2 font-mono text-xs"
    ></textarea>
    <p class="text-xs text-muted-fg">{$LL.snippetScriptHint()}</p>
    <div class="flex flex-wrap gap-1.5">
      {#each macros as macro (macro)}
        <code class="rounded bg-soft px-1.5 py-0.5 font-mono text-[11px] text-muted-fg">{macro}</code>
      {/each}
    </div>
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="snippet-note">{$LL.snippetNote()}</label>
    <Input id="snippet-note" bind:value={fields.note} />
  </div>

  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="snippet-tags">{$LL.snippetTags()}</label>
    <Input id="snippet-tags" bind:value={fields.tags} placeholder="ops, nginx" />
    <p class="text-xs text-muted-fg">{$LL.snippetTagsHint()}</p>
  </div>

  <div class="flex justify-end gap-2">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button onclick={() => onsaved(snippetDraftOf(fields))}>
      {editing ? $LL.save() : $LL.snippetAdd()}
    </Button>
  </div>
</div>
