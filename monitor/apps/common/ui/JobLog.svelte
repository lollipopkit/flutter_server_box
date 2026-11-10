<script lang="ts">
  /// A job as it runs and once it ended: its state, its title, its log kept
  /// scrolled to its end, and Cancel while it runs.

  import Button from '$lk/Button.svelte'
  import Card from '$lk/Card.svelte'
  import Icon from '$lk/Icon.svelte'
  import Spinner from '$lk/Spinner.svelte'
  import type { Translate } from 'serverbox-desk'

  interface Props {
    t: Translate
    status: 'running' | 'succeeded' | 'failed' | 'cancelled'
    title: string
    lines: string[]
    oncancel?: () => void
  }

  const { t, status, title, lines, oncancel }: Props = $props()
  let log = $state<HTMLPreElement | undefined>(undefined)

  $effect(() => {
    void lines.length
    if (log) log.scrollTop = log.scrollHeight
  })
</script>

<div class="job">
  <Card>
    <div class="head">
      {#if status === 'running'}
        <Spinner size={20} />
      {:else}
        <Icon name={status === 'succeeded' ? 'check_circle' : 'error'} size={20} color={status === 'succeeded' ? 'var(--color-success)' : 'var(--color-danger)'} />
      {/if}
      <div class="text">
        <p class="title">{title}</p>
        {#if status === 'running'}<p class="hint">{t('progressHint')}</p>{/if}
      </div>
      {#if status === 'running' && oncancel}
        <Button variant="secondary" size="sm" onclick={oncancel}>{t('cancel')}</Button>
      {/if}
    </div>
  </Card>
  <pre bind:this={log} class="lk-mono log" aria-label={t('log')}>{lines.join('\n')}</pre>
</div>

<style>
  .job {
    display: flex;
    flex-direction: column;
    gap: 13px;
  }
  .head {
    display: flex;
    align-items: center;
    gap: 11px;
  }
  .text {
    min-width: 0;
    flex: 1;
  }
  .title {
    margin: 0;
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
  }
  .hint {
    margin: 0;
    font-size: 12px;
    color: var(--text-secondary);
  }
  .log {
    margin: 0;
    max-height: 360px;
    min-height: 160px;
    overflow: auto;
    border-radius: var(--radius-md, 9px);
    background: var(--surface-field);
    padding: 11px;
    font-size: 11.5px;
    line-height: 1.5;
    white-space: pre-wrap;
    color: var(--text-secondary);
  }
</style>
