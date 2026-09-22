<script lang="ts">
  import snarkdown from 'snarkdown'

  interface Props {
    text: string
    class?: string
  }

  const { text, class: className = '' }: Props = $props()

  /// Snarkdown passes raw HTML outside code spans. Escape the input first so
  /// only markup generated from Markdown syntax reaches the DOM. Current
  /// callers use compiled-in i18n strings, but this keeps the component safe
  /// if it later receives agent-provided content.
  const escapeHtml = (raw: string) =>
    raw.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

  const html = $derived(snarkdown(escapeHtml(text)))
</script>

<div class="markdown-body {className}">
  <!-- Renders only the tags snarkdown itself produced: the input was escaped
       above, so nothing in it can introduce markup of its own. -->
  <!-- eslint-disable-next-line svelte/no-at-html-tags -->
  {@html html}
</div>

<style>
  .markdown-body :global(p) {
    margin: 0;
  }
  .markdown-body :global(p + p) {
    margin-top: 0.5em;
  }
  .markdown-body :global(code) {
    background: var(--color-soft);
    padding: 0.1em 0.4em;
    border-radius: 4px;
    font-family: var(--font-mono);
    font-size: 0.9em;
  }
  .markdown-body :global(strong) {
    font-weight: 600;
    color: var(--color-fg);
  }
  .markdown-body :global(ul) {
    margin: 0.35em 0 0;
    padding-left: 1.1em;
    list-style: disc;
  }
  .markdown-body :global(li) {
    margin: 0.25em 0;
  }
  .markdown-body :global(li + li) {
    margin-top: 0.25em;
  }
  .markdown-body :global(a) {
    color: var(--color-accent);
    text-decoration: underline;
  }
</style>
