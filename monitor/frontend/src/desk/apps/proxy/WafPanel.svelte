<script lang="ts">
  /// One server's web application firewall (`/waf`): installed or not, its
  /// mode, paranoia level and the rules left out, and what it detected and
  /// refused lately, each rule leavable out from there. Every
  /// change asks sudo's password (`SudoConfirm`).

  import { Badge, Button, Group, Input, Row, SegmentedControl, Select } from '../../lk'
  import SudoConfirm from '../../../components/SudoConfirm.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import type { ProxyServerId, ServerWaf, StackJob, WafEvent, WafSettings } from '../../../types'

  interface Props {
    server: ProxyServerId
    waf: ServerWaf
    crs: string | null
    /// An install started (shared with the proxy's jobs).
    onjob: (job: StackJob) => void
    onchanged: () => void
  }

  const { server, waf, crs, onjob, onchanged }: Props = $props()

  let draft = $state<WafSettings>({ mode: 'detect', paranoia: 1, exclusions: [] })
  let exclusionsText = $state('')
  let events = $state<WafEvent[] | null>(null)
  let pending = $state<{ title: string; body: string; run: (sudo: string) => Promise<void> } | null>(null)

  $effect(() => {
    const s = waf.settings ?? { mode: 'detect', paranoia: 1, exclusions: [] }
    draft = { ...s }
    exclusionsText = s.exclusions.join(', ')
  })

  function save(settings: WafSettings) {
    pending = {
      title: $LL.wafSaveTitle(),
      body: settings.mode === 'block' ? $LL.wafSaveBlock() : settings.mode === 'detect' ? $LL.wafSaveDetect() : $LL.wafSaveOff(),
      run: async (sudo) => {
        await api.setWaf(server, settings, sudo)
        onchanged()
      },
    }
  }

  function submit() {
    const exclusions = exclusionsText.split(/[\s,]+/).map((x) => Number(x)).filter((n) => Number.isInteger(n) && n > 0)
    save({ ...draft, exclusions })
  }

  function leaveOut(id: string) {
    const n = Number(id)
    if (!Number.isInteger(n) || draft.exclusions.includes(n)) return
    save({ ...draft, exclusions: [...(waf.settings?.exclusions ?? []), n] })
  }

  function install() {
    pending = {
      title: $LL.wafInstallTitle(),
      body: server === 'nginx' ? $LL.wafInstallNginx() : $LL.wafInstallTraefik(),
      run: async (sudo) => onjob(await api.installWaf(server, sudo)),
    }
  }

  function readEvents() {
    pending = {
      title: $LL.wafEvents(),
      body: $LL.wafEventsBody(),
      run: async (sudo) => {
        events = (await api.wafEvents(server, sudo)).events
      },
    }
  }
</script>

<Group title={$LL.wafTitle()}>
  {#if !waf.ready}
    <Row label={$LL.wafNotReady()} sub={waf.installable ? undefined : $LL.wafNotInstallable()}>
      {#if waf.installable}<Button size="sm" icon="download" onclick={install}>{$LL.wafInstall()}</Button>{/if}
    </Row>
  {:else}
    <Row label={$LL.wafRules()} value={`OWASP CRS ${crs ?? ''}`} />
    <div class="flex flex-wrap items-end gap-[11px] px-[13px] py-[11px]">
      <SegmentedControl
        label={$LL.wafMode()}
        options={[
          { value: 'off', label: $LL.wafOff() },
          { value: 'detect', label: $LL.wafDetect() },
          { value: 'block', label: $LL.wafBlock() },
        ]}
        value={draft.mode}
        onchange={(m) => (draft.mode = m)}
      />
      <Select
        class="w-[150px]"
        label={$LL.wafParanoia()}
        options={[1, 2, 3, 4].map((n) => ({ value: n, label: String(n) }))}
        bind:value={draft.paranoia}
      />
    </div>
    <div class="flex flex-wrap items-end gap-[11px] px-[13px] pb-[11px]">
      <Input class="min-w-[220px] flex-1" label={$LL.wafExclusions()} mono placeholder="942100, 920350" bind:value={exclusionsText} />
      <Button variant="primary" onclick={submit}>{$LL.wafSave()}</Button>
    </div>
    <p class="px-[13px] pb-[11px] text-[12px] text-(--text-tertiary)">{waf.settings ? $LL.wafSitesNote() : $LL.wafFirstSave()}</p>
    {#if waf.settings}
      <Row label={$LL.wafEvents()}>
        <Button size="sm" variant="secondary" onclick={readEvents}>{$LL.wafRead()}</Button>
      </Row>
      {#each events ?? [] as e, i (i)}
        <div class="space-y-[5px] border-t border-(--border-hairline) px-[13px] py-[9px] text-[12px]">
          <div class="flex flex-wrap items-center gap-[7px]">
            <Badge tone={e.status === 403 ? 'danger' : 'warning'}>{e.status === 403 ? $LL.wafRefused() : $LL.wafDetected()}</Badge>
            <span class="lk-mono break-all">{e.method} {e.host}{e.uri}</span>
            <span class="text-(--text-tertiary)">{e.client} · {e.time}</span>
          </div>
          {#each e.rules as [id, message] (id)}
            <div class="flex items-center gap-[7px] text-(--text-secondary)">
              <span class="lk-mono">{id}</span><span class="flex-1">{message}</span>
              {#if !waf.settings?.exclusions.includes(Number(id))}
                <Button size="sm" variant="ghost" onclick={() => leaveOut(id)}>{$LL.wafLeaveOut()}</Button>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        {#if events}<p class="px-[13px] py-[9px] text-[12px] text-(--text-tertiary)">{$LL.wafNoEvents()}</p>{/if}
      {/each}
    {/if}
  {/if}
</Group>

<SudoConfirm
  open={pending !== null}
  title={pending?.title ?? ''}
  body={pending?.body ?? ''}
  run={(sudo) => pending!.run(sudo)}
  onclose={() => (pending = null)}
/>
