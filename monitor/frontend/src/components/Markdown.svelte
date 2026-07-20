<script lang="ts">
  import snarkdown from 'snarkdown'

  interface Props {
    text: string
    class?: string
  }

  const { text, class: className = '' }: Props = $props()
</script>

<!-- Trusted, developer-authored i18n strings only — never user input -->
<div class="markdown-body {className}">
  {@html snarkdown(text)}
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
