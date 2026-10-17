<script lang="ts">
  /// The machine's kernels (`/kernel`): the one running, the installed ones
  /// and which GRUB boots, the series the machine follows and the archive's
  /// others, other versions of the running flavour. Every change is a job
  /// run as root after sudo's password (`SudoConfirm`); a kernel runs after
  /// a restart (`PowerModal`).

  import { AppToolbar } from '../../sys'
  import { Badge, Button, Card, Group, Icon, IconButton, Row, Select, Spinner } from '../../lk'
  import PowerModal from '../../../components/PowerModal.svelte'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import SudoConfirm from '../../../components/SudoConfirm.svelte'
  import { errorText } from '../../../lib/errorText'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { useScope } from '../../../lib/scope.svelte'
  import type { KernelAction, KernelInstalled, KernelView, StackJob } from '../../../types'

  let view = $state<KernelView | null>(null)
  let error = $state('')
  let job = $state<StackJob | null>(null)
  const running = $derived(job?.state === 'running')
  let pending = $state<{ title: string; body: string; confirmWord?: string; action: KernelAction } | null>(null)
  let version = $state('')
  let restart = $state(false)
  const { stale } = useScope()

  async function load(serverId = servers.currentId) {
    try {
      const v = await api.getKernel()
      if (stale(serverId)) return
      view = v
      if (v.job?.state === 'running') job = v.job
      if (!v.versions.some((o) => o.package === version)) version = v.versions[0]?.package ?? ''
      error = ''
    } catch (e) {
      if (!stale(serverId)) error = errorText(e)
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
  })

  const booted = $derived(view?.installed.find((k) => k.default))
  const next = $derived(view?.installed.find((k) => k.next))
  /// What a restart would change: another kernel booted than the one running.
  const restartBoots = $derived(next ?? booted)
  const restartNeeded = $derived(!!view && (view.rebootRequired || (!!restartBoots && !restartBoots.running)))

  function refusal(body: Record<string, unknown> & { error?: string }): string | undefined {
    const map: Record<string, () => string> = {
      unsupported: $LL.kernelUnsupported,
      notOffered: $LL.kernelNotOffered,
      installed: $LL.kernelAlreadyInstalled,
      unknownKernel: $LL.kernelUnknown,
      running: $LL.kernelRemoveRunning,
      booted: $LL.kernelRemoveBooted,
      lastKernel: $LL.kernelRemoveLast,
      neededBySeries: $LL.kernelRemoveNeeded,
    }
    return body.error ? map[body.error]?.() : undefined
  }

  function removable(k: KernelInstalled): boolean {
    return !k.running && !k.default && !k.next && !k.neededBy && (view?.installed.length ?? 0) > 1
  }

  function ask(action: KernelAction) {
    switch (action.action) {
      case 'install':
        pending = { title: $LL.kernelInstallTitle({ package: action.package }), body: $LL.kernelInstallBody(), action }
        break
      case 'remove':
        pending = { title: $LL.kernelRemoveTitle({ release: action.release }), body: $LL.kernelRemoveBody(), confirmWord: action.release, action }
        break
      case 'boot':
        pending = {
          title: action.once ? $LL.kernelBootOnceTitle({ release: action.release }) : $LL.kernelBootTitle({ release: action.release }),
          body: action.once ? $LL.kernelBootOnceBody() : $LL.kernelBootBody(),
          action,
        }
        break
      case 'bootNewest':
        pending = { title: $LL.kernelBootNewestTitle(), body: $LL.kernelBootNewestBody(), action }
    }
  }
</script>

<AppToolbar>
  {#snippet actions()}
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
          title={job.state === 'running' ? $LL.kernelWorking() : job.state === 'succeeded' ? $LL.kernelDone() : $LL.kernelFailed()}
          read={(since) => api.kernelJob(since)}
          stop={null}
          ondone={(done) => {
            // Kept on screen: a failure says why.
            job = done
            void load()
          }}
        />
      {/key}
    {/if}

    {#if !view}
      {#if !error}<div class="grid place-items-center py-[55px]"><Spinner /></div>{/if}
    {:else}
      {#if !view.supported}
        <Card class="flex items-start gap-[9px] text-[13px] text-(--text-secondary)"><Icon name="info" size={17} /><p>{$LL.kernelUnsupported()}</p></Card>
      {/if}
      <Group>
        <Row label={$LL.kernelRunning()} value={view.running} mono />
        <Row label={$LL.kernelBoots()} value={booted?.release ?? '—'} mono sub={view.pinned ? $LL.kernelPinned() : $LL.kernelNewest()}>
          {#if view.pinned && view.supported}
            <Button size="sm" variant="secondary" disabled={running} onclick={() => ask({ action: 'bootNewest' })}>{$LL.kernelBootNewest()}</Button>
          {/if}
        </Row>
        {#if next}
          <Row label={$LL.kernelNextBoot()} value={next.release} mono />
        {/if}
      </Group>
      {#if restartNeeded}
        <Card class="flex flex-wrap items-center gap-[11px] text-[13px]">
          <Icon name="restart_alt" size={17} />
          <p class="min-w-[200px] flex-1">
            {restartBoots && !restartBoots.running ? $LL.kernelRestartToBoot({ release: restartBoots.release }) : $LL.kernelRestartRequired()}
          </p>
          <Button size="sm" variant="primary" onclick={() => (restart = true)}>{$LL.powerReboot()}…</Button>
        </Card>
      {/if}

      <Group title={$LL.kernelInstalled()}>
        {#each view.installed as k (k.release)}
          <Row label={k.release} mono sub={`${k.package} ${k.version}`}>
            {#if k.running}<Badge tone="success">{$LL.kernelBadgeRunning()}</Badge>{/if}
            {#if k.default}<Badge tone="accent">{$LL.kernelBadgeDefault()}</Badge>{/if}
            {#if k.next}<Badge tone="warning">{$LL.kernelBadgeNext()}</Badge>{/if}
            {#if view.supported}
              {#if !k.default || view.pinned === null}
                <Button size="sm" variant="ghost" disabled={running} onclick={() => ask({ action: 'boot', release: k.release, once: false })}>{$LL.kernelBoot()}</Button>
              {/if}
              {#if !k.next && !k.running}
                <Button size="sm" variant="ghost" disabled={running} onclick={() => ask({ action: 'boot', release: k.release, once: true })}>{$LL.kernelBootOnce()}</Button>
              {/if}
              {#if removable(k)}
                <IconButton icon="delete" label={$LL.kernelRemove()} disabled={running} onclick={() => ask({ action: 'remove', release: k.release })} />
              {/if}
            {/if}
          </Row>
        {/each}
      </Group>

      {#if view.supported && view.series.length}
        <Group title={$LL.kernelSeries()}>
          {#each view.series as s (s.package)}
            <Row label={s.package} mono sub={s.installed ? (s.installed === s.version ? s.version : `${s.installed} → ${s.version}`) : s.version}>
              {#if s.installed}<Badge tone="success">{$LL.kernelFollowed()}</Badge>{/if}
              {#if s.installed !== s.version}
                <Button size="sm" variant="ghost" disabled={running} onclick={() => ask({ action: 'install', package: s.package })}>
                  {s.installed ? $LL.kernelUpdate() : $LL.kernelInstall()}
                </Button>
              {/if}
            </Row>
          {/each}
        </Group>
      {/if}

      {#if view.supported && view.versions.length}
        <Group title={$LL.kernelVersions()}>
          <div class="flex flex-wrap items-end gap-[11px] px-[13px] py-[11px]">
            <Select
              class="min-w-[220px] flex-1"
              label={$LL.kernelVersion()}
              options={view.versions.map((o) => ({ value: o.package, label: `${o.release} · ${o.version}` }))}
              bind:value={version}
            />
            <Button variant="primary" icon="download" disabled={running || !version} onclick={() => ask({ action: 'install', package: version })}>{$LL.kernelInstall()}</Button>
          </div>
          <p class="px-[13px] pb-[11px] text-[12px] text-(--text-tertiary)">{$LL.kernelVersionsNote()}</p>
        </Group>
      {/if}
    {/if}
</main>

<SudoConfirm
  open={pending !== null}
  title={pending?.title ?? ''}
  body={pending?.body ?? ''}
  confirmWord={pending?.confirmWord}
  run={async (sudo) => {
    job = await api.kernelAct(pending!.action, sudo)
  }}
  {refusal}
  onclose={() => {
    pending = null
    void load()
  }}
/>

<PowerModal open={restart} initial="reboot" onclose={() => (restart = false)} />
