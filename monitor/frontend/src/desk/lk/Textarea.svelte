<script lang="ts">
  import type { HTMLTextareaAttributes } from 'svelte/elements'

  /// A multi-line field (an SSH key, a cloud-init script), drawn as `Input`
  /// is: the same frame, focus ring, label, hint and error.

  interface Props extends Omit<HTMLTextareaAttributes, 'class' | 'value'> {
    value?: string | null
    label?: string
    hint?: string
    error?: string
    mono?: boolean
    class?: string
  }

  let {
    value = $bindable(''),
    label,
    hint,
    error,
    mono = false,
    rows = 4,
    disabled = false,
    class: className = '',
    ...rest
  }: Props = $props()
</script>

<label class="lk-field {className}">
  {#if label}<span class="lk-field__label">{label}</span>{/if}
  <textarea
    class="lk-textarea"
    class:lk-textarea--error={!!error}
    class:lk-mono={mono}
    bind:value
    {rows}
    {disabled}
    {...rest}
  ></textarea>
  {#if error || hint}
    <span class="lk-field__hint" class:lk-field__hint--error={!!error}>{error || hint}</span>
  {/if}
</label>

<style>
  .lk-textarea {
    width: 100%;
    min-height: calc(var(--control-height) * 2);
    padding: var(--space-7) var(--space-9);
    border: 0;
    border-radius: var(--radius-control);
    background: var(--surface-field);
    box-shadow:
      inset 0 0 0 0.5px var(--border-strong),
      var(--shadow-control);
    font: var(--weight-regular) var(--text-13) / var(--leading-body) var(--font-ui);
    color: var(--text-primary);
    resize: vertical;
    outline: none;
    transition: box-shadow var(--dur-fast) var(--ease-standard);
  }
  .lk-textarea.lk-mono {
    font-family: var(--font-mono);
  }
  .lk-textarea::placeholder {
    color: var(--text-tertiary);
  }
  .lk-textarea:focus {
    box-shadow:
      inset 0 0 0 1px var(--color-accent),
      var(--focus-ring);
  }
  .lk-textarea--error {
    box-shadow: inset 0 0 0 1px var(--color-danger);
  }
  .lk-textarea:disabled {
    opacity: 0.5;
  }
</style>
