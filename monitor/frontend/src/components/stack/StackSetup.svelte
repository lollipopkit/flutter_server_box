<script lang="ts">
  /// Setting a web app up: what the machine has against what the app needs,
  /// the settings its manifest asks (started from the agent's defaults for
  /// this machine), what its compose files do here, and its licence. Setting
  /// up checks the settings with the agent, then asks for confirmation
  /// (`StackConfirm`: the project, licence, images, folders, port; ticked),
  /// then the admin's password.
  ///
  /// With [current], the settings of a deployed app to change: started from
  /// them, saved with the password alone (what was confirmed stays), and the
  /// app deployed again.

  import { AppIcon, Badge, Button, Card, Group, Icon, Input, Row, Select, Spinner, Switch } from '../../desk/lk'
  import type { IconTone } from '../../desk/lk'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { api, ApiError } from '../../lib/api'
  import { servers } from '../../lib/servers.svelte'
  import type { StackJob, StackManifest, StackPrepare, StackPreview, StackSetting, StackValue } from '../../types'
  import ReauthDialog from '../ReauthDialog.svelte'
  import StackConfirm from './StackConfirm.svelte'
  import { noticeText } from './notices'
  import { stackRefusal } from './refusal'
  import { mib, pick } from './text'
  import { untrack } from 'svelte'

  interface Props {
    manifest: StackManifest
    /// The deployed app's settings, to change them.
    current?: Record<string, StackValue>
    onstarted: (job: StackJob) => void
  }

  const { manifest, current, onstarted }: Props = $props()
  const editing = $derived(current !== undefined)

  let prepare = $state<StackPrepare | null>(null)
  let values = $state<Record<string, StackValue>>({})
  let preview = $state<StackPreview | null>(null)
  let confirming = $state(false)
  let checking = $state(false)
  let consent = { acknowledged: false, acceptLicense: false }
  let error = $state('')
  let invalidField = $state<string | null>(null)
  let asking = $state(false)

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => {
      api
        .prepareStack(manifest.id)
        .then((p) => {
          if (serverId !== servers.currentId) return
          prepare = p
          values = { ...p.defaults, ...current }
        })
        .catch((e) => (error = e instanceof Error ? e.message : String(e)))
    })
  })

  const tr = (text: Record<string, string> | null | undefined) => pick(text, $locale)

  const req = $derived(manifest.requirements)
  const memoryOk = $derived(
    prepare?.memory_mib == null || req.memory_min_mib == null ? null : prepare.memory_mib >= req.memory_min_mib,
  )
  const coresOk = $derived(prepare?.cores == null || req.cores_min == null ? null : prepare.cores >= req.cores_min)
  const runtimeOk = $derived(prepare?.runtime.available === true)
  const canInstall = $derived(!!prepare && runtimeOk && !checking)
  /// Data folders whose path the admin changed: their data stays behind.
  const movedData = $derived(
    editing
      ? manifest.settings.filter((s) => s.type === 'path' && s.data && current?.[s.key] !== undefined && values[s.key] !== current[s.key])
      : [],
  )


  function runtimeText(p: StackPrepare): string {
    if (p.runtime.available) return `${p.runtime.runtime} · Compose ${p.runtime.compose}`
    return p.runtime.error === 'noCompose' ? $LL.stackNoCompose() : $LL.stackNoRuntime()
  }

  function setValue(s: StackSetting, raw: StackValue) {
    invalidField = null
    values = { ...values, [s.key]: s.type === 'port' ? Number(raw) : raw }
  }

  /// The settings as the agent reads them, and what they would do; then the
  /// confirmation.
  async function check() {
    error = ''
    invalidField = null
    checking = true
    try {
      preview = await api.checkStack(manifest.id, $state.snapshot(values))
      if (editing) asking = true
      else confirming = true
    } catch (e) {
      refused(e)
    } finally {
      checking = false
    }
  }

  function refused(e: unknown) {
    const r = stackRefusal(e, manifest, $state.snapshot(values), $LL, $locale)
    invalidField = r.field
    error = r.text
  }

  async function save(password: string) {
    error = ''
    try {
      // Ports the check moved go as moved.
      const settings = { ...$state.snapshot(values), ...preview?.settings }
      const job = editing
        ? await api.reconfigureStack(manifest.id, settings, password)
        : await api.installStack(manifest.id, settings, consent, password)
      onstarted(job)
    } catch (e) {
      // A wrong password stays in the dialog; anything else is the form's.
      const code = e instanceof ApiError ? (e.body as { error?: string } | undefined)?.error : undefined
      if (code && code !== 'reauth' && code !== 'throttled') {
        refused(e)
        asking = false
        return
      }
      throw e
    }
  }
</script>

<div class="space-y-[13px]">
  <Card class="flex items-start gap-[13px]">
    <AppIcon glyph={manifest.glyph} tone={manifest.tone as IconTone} size={48} />
    <div class="min-w-0 flex-1 space-y-[3px]">
      <p class="text-[17px] font-semibold text-(--text-primary)">{tr(manifest.title)}</p>
      <p class="text-[12px] text-(--text-secondary)">{$LL.stackPoweredBy({ name: manifest.project, version: manifest.version })}</p>
      <p class="pt-[3px] text-[13px] leading-relaxed text-(--text-secondary)">{tr(manifest.description)}</p>
    </div>
  </Card>

  {#if error}
    <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
      <Icon name="error" size={17} />
      <p>{error}</p>
    </Card>
  {/if}

  {#if !prepare}
    <Card><Spinner size={20} /></Card>
  {:else}
    <Group title={$LL.stackRequirements()}>
      <Row label={$LL.stackRuntime()} value={runtimeText(prepare)}>
        <Badge tone={runtimeOk ? 'success' : 'danger'}>{runtimeOk ? $LL.stackOk() : $LL.stackMissing()}</Badge>
      </Row>
      {#if prepare.memory_mib != null && req.memory_min_mib != null}
        <Row
          label={$LL.stackMemory()}
          value={$LL.stackMemoryValue({ have: mib(prepare.memory_mib), need: mib(req.memory_recommended_mib ?? req.memory_min_mib) })}
        >
          <Badge tone={memoryOk ? 'success' : 'warning'}>{memoryOk ? $LL.stackOk() : $LL.stackLow()}</Badge>
        </Row>
      {/if}
      {#each prepare.gpus_seen.filter((g) => !prepare?.gpus.includes(g)) as vendor (vendor)}
        <Row label={$LL.stackGpu()} value={vendor === 'nvidia' ? $LL.stackGpuNoToolkit() : $LL.stackGpuNoDevice()}>
          <Badge tone="warning">{vendor}</Badge>
        </Row>
      {/each}
      {#if prepare.cores != null && req.cores_min != null}
        <Row label={$LL.stackCores()} value={$LL.stackCoresValue({ have: prepare.cores, need: req.cores_min })}>
          <Badge tone={coresOk ? 'success' : 'warning'}>{coresOk ? $LL.stackOk() : $LL.stackLow()}</Badge>
        </Row>
      {/if}
    </Group>

    <Group title={$LL.stackSettings()}>
      {#each manifest.settings as s (s.key)}
        <div class="space-y-[5px] px-[13px] py-[9px]" class:text-(--color-danger)={invalidField === s.key}>
          {#if s.type === 'bool'}
            <div class="flex items-center justify-between gap-[13px]">
              <span class="text-[13px] text-(--text-primary)">{tr(s.label)}</span>
              <Switch label={tr(s.label)} checked={values[s.key] === true} onchange={(on) => setValue(s, on)} />
            </div>
          {:else if s.type === 'choice'}
            <Select
              label={tr(s.label)}
              value={String(values[s.key] ?? s.default)}
              options={s.options.map((o) => ({ value: o.value, label: tr(o.label) }))}
              onchange={(e: Event) => setValue(s, (e.currentTarget as HTMLSelectElement).value)}
            />
          {:else}
            <Input
              label={tr(s.label)}
              mono={s.type === 'path'}
              type={s.type === 'port' ? 'number' : 'text'}
              value={values[s.key] === undefined ? '' : String(values[s.key])}
              error={invalidField === s.key ? $LL.stackInvalidValue() : undefined}
              oninput={(e: Event) => setValue(s, (e.currentTarget as HTMLInputElement).value)}
            />
          {/if}
          {#if s.type === 'port' && s.protocol && s.protocol !== 'tcp'}
            <p class="text-[12px] text-(--text-tertiary)">{s.protocol === 'udp' ? $LL.stackPortUdp() : $LL.stackPortBoth()}</p>
          {/if}
          {#if s.help}<p class="text-[12px] text-(--text-tertiary)">{tr(s.help)}</p>{/if}
          {#if s.type === 'port' && prepare.ports_partial}<p class="text-[12px] text-(--text-tertiary)">{$LL.stackPortsPartial()}</p>{/if}
          {#if movedData.some((d) => d.key === s.key)}<p class="text-[12px] text-(--color-warning)">{$LL.stackDataNotMoved()}</p>{/if}
        </div>
      {/each}
    </Group>

    {#if manifest.notices.length && !editing}
      <Group title={$LL.stackNotices()}>
        {#each manifest.notices as n (n)}
          <div class="flex items-start gap-[9px] px-[13px] py-[9px] text-[13px] text-(--text-secondary)">
            <Icon name="info" size={16} class="mt-[1px] shrink-0" />
            <span>{noticeText(n, $LL)}</span>
          </div>
        {/each}
      </Group>
    {/if}

    {#if !editing}
    <Group title={$LL.stackLicense()}>
      <div class="space-y-[9px] px-[13px] py-[11px] text-[13px] text-(--text-secondary)">
        <p>{$LL.stackLicenseBody({ name: manifest.project, spdx: manifest.license.spdx })}</p>
        <p class="flex flex-wrap gap-x-[17px] gap-y-[5px]">
          <a class="text-(--color-accent-text) hover:underline" href={manifest.license.url} target="_blank" rel="noreferrer noopener">{$LL.stackLicenseRead()}</a>
          <a class="text-(--color-accent-text) hover:underline" href={manifest.source} target="_blank" rel="noreferrer noopener">{$LL.stackSource()}</a>
          <a class="text-(--color-accent-text) hover:underline" href={manifest.homepage} target="_blank" rel="noreferrer noopener">{$LL.stackHomepage()}</a>
        </p>
      </div>
    </Group>
    {/if}

    {#if editing}<p class="px-[2px] text-[12px] text-(--text-tertiary)">{$LL.stackReconfigureNote({ name: tr(manifest.title) })}</p>{/if}
    <div class="flex justify-end">
      <Button icon={editing ? 'check' : 'download'} disabled={!canInstall} onclick={() => void check()}>
        {#if checking}<Spinner size={16} />{/if}
        {editing ? $LL.save() : $LL.stackInstall()}
      </Button>
    </div>
  {/if}
</div>

<StackConfirm
  open={confirming}
  {manifest}
  {preview}
  oncontinue={(c) => {
    consent = c
    confirming = false
    asking = true
  }}
  onclose={() => (confirming = false)}
/>

<ReauthDialog
  open={asking}
  message={editing ? $LL.stackReconfigureReauth({ name: tr(manifest.title) }) : $LL.stackInstallReauth({ name: tr(manifest.title) })}
  onconfirm={save}
  onclose={() => (asking = false)}
/>
