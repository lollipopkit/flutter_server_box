<script lang="ts">
  import snarkdown from 'snarkdown'

  interface Props {
    text: string
    class?: string
  }

  const { text, class: className = '' }: Props = $props()

  /// snarkdown escapes inside code spans but passes raw HTML through
  /// everywhere else, so `<img onerror=...>` in the input would reach the DOM.
  /// Escaping first means only snarkdown's own generated tags survive, which
  /// costs nothing: markdown syntax uses none of these three characters.
  ///
  /// Today every caller passes a compiled-in i18n string, so this is defence
  /// in depth rather than a fix — but "only ever called with trusted input"
  /// is a property a comment cannot enforce, and the panel can talk to
  /// several agents at once, where one compromised agent should not be able
  /// to reach another's session.
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
