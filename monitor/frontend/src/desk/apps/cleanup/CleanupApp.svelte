<script lang="ts">
  /// What can go to free space (`/cleanup`): a scan as root (system caches,
  /// logs, packages nothing needs; this account's trash and caches;
  /// folders removed web apps left; what Docker could reclaim), then the
  /// chosen items removed as a job that scans again before and after.
  /// Nothing is chosen at first; a removed web app's folder holds its data,
  /// so choosing one asks for the word typed back.

  import { AppToolbar, useWindow } from '../../sys'
  import { Button, Card, Checkbox, Group, Icon, IconButton, Row, Spinner } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import SudoConfirm from '../../../components/SudoConfirm.svelte'
  import { errorText } from '../../../lib/errorText'
  import { fmtBytes, fmtDate } from '../../../lib/format'
  import { LL, locale } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import { SvelteSet } from 'svelte/reactivity'
  import type { CleanupItem, CleanupView, StackJob } from '../../../types'
  import { GROUPS, chosenBytes, groupLabel, itemLabel } from './model'

  const win = useWindow()
  let view = $state<CleanupView | null>(null)
  let error = $state('')
  let job = $state<StackJob | null>(null)
  const running = $derived(job?.state === 'running')
  const chosen = new SvelteSet<string>()
  let pending = $state<'scan' | 'clean' | null>(null)
  const { stale } = useScope()

  async function load(serverId = servers.currentId) {
    try {
      const v = await api.getCleanup()
      if (stale(serverId)) return
      view = v
      if (v.job?.state === 'running') job = v.job
      const ids = new Set(v.scan?.items.filter((i) => i.cleanable).map((i) => i.id) ?? [])
      for (const id of [...chosen]) if (!ids.has(id)) chosen.delete(id)
      error = ''
    } catch (e) {
      if (!stale(serverId)) error = errorText(e)
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
  })

  const items = $derived(view?.scan?.items ?? [])
  const total = $derived(items.filter((i) => i.cleanable).reduce((s, i) => s + i.bytes, 0))
  const picked = $derived(chosenBytes(items, chosen))
  const losesData = $derived([...chosen].some((id) => id.startsWith('leftover:')))

  function toggle(item: CleanupItem, on: boolean) {
    if (on) chosen.add(item.id)
    else chosen.delete(item.id)
  }

  function sub(item: CleanupItem): string | undefined {
    const parts: string[] = []
    if (item.count) parts.push($LL.cleanupCount({ count: item.count }))
    if (item.detail) parts.push(item.detail)
    if (!item.cleanable && item.group !== 'containers') parts.push($LL.cleanupHoldsAgent())
    return parts.join(' · ') || undefined
  }

  function refusal(body: Record<string, unknown> & { error?: string }): string | undefined {
    const map: Record<string, () => string> = {
      notScanned: $LL.cleanupNotScanned,
      unknownItem: $LL.cleanupUnknownItem,
      nothingChosen: $LL.cleanupNothingChosen,
    }
    return body.error ? map[body.error]?.() : undefined
  }
</script>

<AppToolbar>
  {#snippet actions()}
    <Button size="sm" icon="search" disabled={running} onclick={() => (pending = 'scan')}>{$LL.cleanupScan()}</Button>
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} />
  {/snippet}
</AppToolbar>

<main class="pane-form space-y-[13px] pb-[21px] pt-[5px]">
  {#if error}
    <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} /><p class="break-all">{error}</p></Card>
  {/if}
  {#if job}
    {#key job.id}
      <StackProgress
        {job}
        title={job.state === 'running' ? (job.kind === 'scan' ? $LL.cleanupScanning() : $LL.cleanupCleaning()) : job.state === 'succeeded' ? $LL.cleanupDone() : $LL.cleanupFailed()}
        read={(since) => api.cleanupJob(since)}
        stop={null}
        ondone={(done) => {
          // A scan's outcome is what it found; anything else stays on
          // screen, a failure saying why.
          job = done.kind === 'scan' && done.state === 'succeeded' ? null : done
          void load()
        }}
      />
    {/key}
  {/if}

  {#if !view}
    {#if !error}<div class="grid place-items-center py-[55px]"><Spinner /></div>{/if}
  {:else if !view.scan}
    <Card class="space-y-[11px] text-[13px]">
      <p class="text-(--text-secondary)">{$LL.cleanupIntro()}</p>
      <Button variant="primary" icon="search" disabled={running} onclick={() => (pending = 'scan')}>{$LL.cleanupScan()}</Button>
    </Card>
  {:else}
    <Group>
      <Row label={$LL.cleanupCanGo()} value={fmtBytes(total)} sub={$LL.cleanupScannedAt({ at: fmtDate(view.scan.at, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }, $locale) })} />
      <Row label={$LL.cleanupChosen()} value={fmtBytes(picked)}>
        <Button size="sm" variant="primary" disabled={running || chosen.size === 0} onclick={() => (pending = 'clean')}>{$LL.cleanupClean()}</Button>
      </Row>
    </Group>
    {#each GROUPS as g (g)}
      {@const list = items.filter((i) => i.group === g && (i.bytes > 0 || i.group === 'apps'))}
      {#if list.length}
        <Group title={groupLabel($LL, g)}>
          {#each list as item (item.id)}
            <Row label={itemLabel($LL, item)} mono={item.id.startsWith('cache:') || item.id.startsWith('leftover:')} sub={sub(item)} value={item.cleanable ? undefined : fmtBytes(item.bytes)}>
              {#if item.cleanable}
                <span class="lk-num text-[13px] text-(--text-secondary)">{fmtBytes(item.bytes)}</span>
                <Checkbox aria-label={itemLabel($LL, item)} checked={chosen.has(item.id)} disabled={running} onchange={(e: Event) => toggle(item, (e.currentTarget as HTMLInputElement).checked)} />
              {/if}
            </Row>
          {/each}
          {#if g === 'containers'}
            <Row label={$LL.cleanupContainersNote()} onclick={() => win.open('serverbox.containers')} />
          {/if}
        </Group>
      {/if}
    {/each}
  {/if}
</main>

<SudoConfirm
  open={pending !== null}
  title={pending === 'scan' ? $LL.cleanupScanTitle() : $LL.cleanupCleanTitle({ size: fmtBytes(picked) })}
  body={pending === 'scan' ? $LL.cleanupScanBody() : losesData ? $LL.cleanupCleanAppsBody() : $LL.cleanupCleanBody()}
  confirmWord={pending === 'clean' && losesData ? 'clean' : undefined}
  run={async (sudo) => {
    if (pending === 'scan') job = await api.cleanupScan(sudo)
    else {
      job = await api.cleanupClean([...chosen], sudo)
      chosen.clear()
    }
  }}
  {refusal}
  onclose={() => {
    pending = null
    void load()
  }}
/>
