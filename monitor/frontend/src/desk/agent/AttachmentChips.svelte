<script lang="ts">
  /// The files waiting to go with what is typed: a chip each, with its
  /// thumbnail or glyph, name, size and a remove button.

  import { LL } from '../../i18n/i18n-svelte'
  import { Icon, IconButton } from '../lk'
  import type { Attachments } from './attachments.svelte'

  const { atts }: { atts: Attachments } = $props()

  // The field keeps the focus when a chip is pressed.
  const keep = (e: Event) => e.preventDefault()
</script>

<div class="atts">
  {#each atts.items as a (a.key)}
    <div class="att" class:att--failed={a.failed}>
      {#if a.thumb}
        <img src={a.thumb} alt="" class="att__thumb" />
      {:else}
        <span class="att__glyph"><Icon name={a.glyph} size={15} fill /></span>
      {/if}
      <span class="att__name">{a.name}</span>
      <span class="att__meta">{!a.id && !a.failed ? `${Math.round(a.progress * 100)}%` : a.meta}</span>
      {#if !a.id && !a.failed}
        <span class="att__bar" style:transform="scaleX({a.progress})"></span>
      {/if}
      <span onmousedown={keep} role="presentation" class="att__x">
        <IconButton icon="close" label={$LL.deskAgentRemoveAttachment()} size="sm" onclick={() => atts.remove(a)} />
      </span>
    </div>
  {/each}
</div>

<style>
  .atts {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-7);
  }
  .att {
    position: relative;
    overflow: hidden;
    display: flex;
    align-items: center;
    gap: var(--space-7);
    height: 34px;
    max-width: 280px;
    box-sizing: border-box;
    padding: 0 3px 0 7px;
    border-radius: 9px;
    background: var(--surface-raised);
    box-shadow: var(--shadow-control);
    animation: lk-pop-in 300ms var(--ease-spring-bouncy);
    transition: opacity var(--dur-fast) var(--ease-standard);
  }
  /* Uploading: the share sent fills the chip's foot. */
  .att__bar {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 2px;
    background: var(--color-accent);
    transform-origin: left;
    transition: transform var(--dur-fast) linear;
  }
  .att--failed .att__meta {
    color: var(--color-danger);
  }
  .att__thumb {
    flex: none;
    width: 24px;
    height: 24px;
    border-radius: 5px;
    object-fit: cover;
  }
  .att__glyph {
    flex: none;
    width: 24px;
    height: 24px;
    border-radius: 5px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: var(--color-accent-soft);
    color: var(--color-accent-text);
  }
  .att__name {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: var(--text-12);
    font-weight: 600;
  }
  .att__meta {
    flex: none;
    font-size: var(--text-11);
    color: var(--text-tertiary);
    font-variant-numeric: tabular-nums;
  }
  .att__x {
    display: inline-flex;
  }
</style>
