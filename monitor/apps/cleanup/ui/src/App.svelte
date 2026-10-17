<script lang="ts">
  /// What can go to free space: a scan as root (system caches, logs,
  /// packages nothing needs; this account's trash and caches; folders
  /// removed web apps left; what Docker could reclaim), then the chosen
  /// items removed as a job that scans again before and after. Nothing is
  /// chosen at first; a removed web app's folder holds its data, so choosing
  /// one asks for the word typed back.

  import Button from '$lk/Button.svelte'
  import Card from '$lk/Card.svelte'
  import Checkbox from '$lk/Checkbox.svelte'
  import Group from '$lk/Group.svelte'
  import Icon from '$lk/Icon.svelte'
  import Row from '$lk/Row.svelte'
  import Spinner from '$lk/Spinner.svelte'
  import { DeskError, formatBytes, formatTime, translator } from 'serverbox-desk'
  import { SvelteSet } from 'svelte/reactivity'
  import { desk } from '$common/desk'
  import JobLog from '$common/JobLog.svelte'
  import { JobRun } from '$common/job.svelte'
  import { dictionaries } from './locales'
  import { GROUPS, chosenBytes, groupLabel, itemLabel, type Item, type Report } from './model'

  let locale = $state(desk.info.locale)
  const t = $derived(translator(dictionaries, locale))
  desk.on('locale', (l) => (locale = l))

  let report = $state<Report | null>(null)
  let loaded = $state(false)
  let error = $state('')
  const job = new JobRun()
  const running = $derived(job.running)
  const chosen = new SvelteSet<string>()

  const items = $derived(report?.items ?? [])
  const total = $derived(items.filter((i) => i.cleanable).reduce((s, i) => s + i.bytes, 0))
  const picked = $derived(chosenBytes(items, chosen))
  const losesData = $derived([...chosen].some((id) => id.startsWith('leftover:')))

  function said(e: unknown): string {
    if (!(e instanceof DeskError)) return String(e)
    const own: Record<string, string> = { notScanned: 'notScanned', unknownItem: 'unknownItem', nothingChosen: 'nothingChosen' }
    return own[e.detail ?? ''] ? t(own[e.detail!]) : e.detail || e.message
  }

  async function load() {
    try {
      report = await desk.call<Report | null>('view')
      const ids = new Set(report?.items.filter((i) => i.cleanable).map((i) => i.id) ?? [])
      for (const id of [...chosen]) if (!ids.has(id)) chosen.delete(id)
      error = ''
    } catch (e) {
      error = said(e)
    }
    loaded = true
  }

  /// [fn] as root, followed until it ends; a scan that ends well leaves only
  /// what it found, anything else stays on screen.
  async function run(fn: 'scan' | 'clean', args: Record<string, unknown>, sudo: { title: string; body: string; confirmWord?: string }) {
    const found = await job.start<Report>(fn, args, sudo, said)
    if (found) {
      report = found
      if (fn === 'scan') job.dismiss()
      else chosen.clear()
    }
    void load()
  }

  const scan = () => void run('scan', {}, { title: t('scanTitle'), body: t('scanBody') })
  const clean = () =>
    void run('clean', { ids: [...chosen] }, {
      title: t('cleanTitle', { size: formatBytes(picked) }),
      body: losesData ? t('cleanAppsBody') : t('cleanBody'),
      confirmWord: losesData ? 'clean' : undefined,
    })

  function sub(item: Item): string | undefined {
    const parts: string[] = []
    if (item.count) parts.push(t('count', { count: item.count }))
    if (item.detail) parts.push(item.detail)
    if (!item.cleanable && item.group !== 'containers') parts.push(t('holdsAgent'))
    return parts.join(' · ') || undefined
  }

  $effect(() => {
    void desk.toolbar({
      actions: [
        { id: 'scan', label: t('scan'), icon: 'search', disabled: running },
        { id: 'refresh', label: t('refresh'), icon: 'refresh' },
      ],
    })
  })
  desk.on('action', ({ id }) => (id === 'scan' ? scan() : id === 'refresh' ? void load() : undefined))

  // A job started before this window opened (or before it reopened).
  void job.resume(said).then((fn) => {
    if (fn === 'scan') job.dismiss()
    void load()
  })
  void load()
</script>

<main class="page">
  {#if error}
    <Card><p class="error"><Icon name="error" size={17} /><span>{error}</span></p></Card>
  {/if}
  {#if job.status}
    <JobLog
      {t}
      status={job.status}
      title={job.running ? (job.fn === 'scan' ? t('scanning') : t('cleaning')) : job.status === 'succeeded' ? t('done') : t('failed')}
      lines={job.lines}
      oncancel={() => job.cancel()}
    />
  {/if}

  {#if !loaded}
    <div class="center"><Spinner /></div>
  {:else if !report}
    <Card>
      <div class="intro">
        <p>{t('intro')}</p>
        <Button variant="primary" icon="search" disabled={running} onclick={scan}>{t('scan')}</Button>
      </div>
    </Card>
  {:else}
    <Group>
      <Row label={t('canGo')} value={formatBytes(total)} sub={t('scannedAt', { at: formatTime(report.at, locale) })} />
      <Row label={t('chosen')} value={formatBytes(picked)}>
        <Button size="sm" variant="primary" disabled={running || chosen.size === 0} onclick={clean}>{t('clean')}</Button>
      </Row>
    </Group>
    {#each GROUPS as g (g)}
      {@const list = items.filter((i) => i.group === g && (i.bytes > 0 || i.group === 'apps'))}
      {#if list.length}
        <Group title={groupLabel(t, g)}>
          {#each list as item (item.id)}
            <Row label={itemLabel(t, item)} mono={item.id.startsWith('cache:') || item.id.startsWith('leftover:')} sub={sub(item)} value={item.cleanable ? undefined : formatBytes(item.bytes)}>
              {#if item.cleanable}
                <span class="trail">
                  <span class="lk-num" style="font-size: 13px; color: var(--text-secondary)">{formatBytes(item.bytes)}</span>
                  <Checkbox
                    aria-label={itemLabel(t, item)}
                    checked={chosen.has(item.id)}
                    disabled={running}
                    onchange={(e: Event) => ((e.currentTarget as HTMLInputElement).checked ? chosen.add(item.id) : chosen.delete(item.id))}
                  />
                </span>
              {/if}
            </Row>
          {/each}
          {#if g === 'containers'}
            <Row label={t('containersNote')} onclick={() => void desk.open('serverbox.containers')} />
          {/if}
        </Group>
      {/if}
    {/each}
  {/if}
</main>
