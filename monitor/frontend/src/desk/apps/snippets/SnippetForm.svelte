<script module lang="ts">
  import type { Snippet } from '../../../types'
  import { newId } from '../../../lib/newId'

  /// The form's own fields, in the shapes the form edits: the tags are one text
  /// field, because a list that is typed is a list of words separated by
  /// commas, and a chip editor would be a second thing to learn before the
  /// first snippet can be saved.
  ///
  /// The page owns this object and seeds it when the dialog opens: a form that
  /// seeded itself from a snippet prop would be holding a copy of a row the
  /// next save may replace.
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
      id: snippet?.id ?? newId(),
      name: snippet?.name ?? '',
      script: snippet?.script ?? '',
      note: snippet?.note ?? '',
      tags: snippet?.tags.join(', ') ?? '',
    }
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
  import { Button, Input, Textarea } from '@lollipopkit/desk-ui'
  import { LL } from '../../../i18n/i18n-svelte'

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

  /// The terminal macros, written as they are typed. Not the six server values
  /// (`${host}`, `${pwd}`, …): the panel has none to offer, and a script naming
  /// one is refused when it runs. Code rather than a translated sentence, since
  /// a locale that translated `${sleep 2}` would describe a script nothing
  /// expands.
  const macros = ['${sleep 2}', '${enter 2}', '${ctrl+c}', '${alt+x}']
</script>

<div class="grid gap-[13px]">
  <Input id="snippet-name" bind:value={fields.name} label={$LL.snippetName()} placeholder="Restart nginx" />

  <div class="grid gap-[9px]">
    <!-- A script spans multiple lines. Preserve whitespace in a monospace field. -->
    <Textarea id="snippet-script" bind:value={fields.script} label={$LL.snippetScript()} rows={8} spellcheck="false" mono placeholder="systemctl restart nginx" hint={$LL.snippetScriptHint()} />
    <span class="flex flex-wrap gap-[5px]">
      {#each macros as macro (macro)}<code class="rounded-[5px] bg-(--surface-control) px-[5px] py-[3px] lk-mono text-[11px] text-(--text-secondary)">{macro}</code>{/each}
    </span>
  </div>

  <Input id="snippet-note" bind:value={fields.note} label={$LL.snippetNote()} />
  <Input id="snippet-tags" bind:value={fields.tags} label={$LL.snippetTags()} hint={$LL.snippetTagsHint()} placeholder="ops, nginx" />

  <div class="flex justify-end gap-[7px]">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button variant="primary" onclick={() => onsaved(snippetDraftOf(fields))}>{editing ? $LL.save() : $LL.snippetAdd()}</Button>
  </div>
</div>
