<script lang="ts">
  import Spinner from '../../lk/Spinner.svelte'
  import { AppToolbar } from '../../sys'
  import { Badge, Button, Card, Checkbox, Dialog, IconButton, Input, SegmentedControl, Select } from '../../lk'
  import { ApiError, api } from '../../../lib/api'
  import {
    accessName,
    emptyDraft,
    endpointText,
    reachText,
    reachTone,
    refusalText,
    ruleText,
    warningText,
  } from '../../../lib/firewall'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type {
    FirewallChange,
    FirewallKind,
    FirewallPlan,
    FirewallView,
    FirewalldItem,
    FirewalldTarget,
    FirewalldZone,
    UfwChain,
    UfwLogLevel,
    UfwPolicy,
    UfwRuleDraft,
  } from '../../../types'

  let view = $state<FirewallView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  let notice = $state('')
  let actionError = $state('')
  /// The firewall on screen, where the machine has both; the agent's choice
  /// until the user picks.
  let kind = $state<FirewallKind | undefined>(undefined)
  /// The `sudo` password, held by this page for the reads and changes it
  /// makes, and never stored. Sent only once the agent asked for one.
  let password = $state('')
  let passwordDraft = $state('')
  let needsPassword = $state(false)
  /// A change the agent planned and the user is asked about, with the id the
  /// agent gave that plan: confirming sends it back, and it runs only if it
  /// is still the plan.
  let pending = $state<{ change: FirewallChange; plan: FirewallPlan; planId: string; message?: string } | null>(
    null,
  )
  let keepOpen = $state(false)
  let countdown = $state(0)
  /// Bumped to draw the selects again from the state, after a change that was
  /// not made left one showing the value picked.
  let rev = $state(0)
  let zoneName = $state<string | null>(null)
  let drafting = $state(false)
  let draft = $state<UfwRuleDraft>(emptyDraft())
  let draftError = $state('')
  let moreOptions = $state(false)
  /// firewalld: the list a value is being typed for, and that value.
  let adding = $state<{ item: FirewalldItem | 'interface' } | null>(null)
  let addValue = $state('')

  /// A reply that arrives after the desk has switched servers belongs to
  /// neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getFirewall(kind, password || undefined)
      if (stale(serverId)) return
      if (next.sudo_required) {
        // A password that was sent and refused is asked for again, and said so.
        if (password) error = $LL.powerRejected()
        password = ''
        needsPassword = true
      } else {
        needsPassword = false
      }
      view = next
      kind = next.kind ?? kind
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => {
      password = ''
      kind = undefined
      zoneName = null
      void load(serverId)
    })
  })

  function submitPassword() {
    password = passwordDraft
    passwordDraft = ''
    void load()
  }

  function switchTo(next: FirewallKind) {
    if (next === kind) return
    kind = next
    zoneName = null
    void load()
  }

  /// Asks the agent what `change` does, then makes it — at once where nothing
  /// gets worse, after the user agrees otherwise.
  async function propose(change: FirewallChange, message?: string) {
    // Every request reads the server selected at the moment it is sent: a plan
    // answered for one server must not lead to a change sent to another.
    const serverId = servers.currentId
    busy = true
    notice = ''
    actionError = ''
    try {
      const result = await api.planFirewall(change, password || undefined)
      if (stale(serverId)) return
      if (result.sudo_required || !result.plan) {
        needsPassword = true
        return
      }
      if (result.plan.confirm) {
        ask(change, result.plan, result.plan_id ?? '', message)
        return
      }
      await make(change, false, serverId)
    } catch (e) {
      const text = refused(e)
      if (text !== null) {
        if (drafting) draftError = text
        else actionError = text
      }
    } finally {
      busy = false
      rev++
    }
  }

  /// What a refusal says; null for one that is no news (a change to what
  /// already is).
  function refused(e: unknown): string | null {
    if (e instanceof ApiError) {
      if (e.message === 'unchanged') return null
      return refusalText(e.message, e.body)
    }
    return e instanceof Error ? e.message : String(e)
  }

  function ask(change: FirewallChange, plan: FirewallPlan, planId: string, message?: string) {
    pending = { change, plan, planId, message }
    keepOpen = plan.keep_open_default
    countdown = plan.countdown ? 3 : 0
  }

  async function make(change: FirewallChange, keep: boolean, serverId: string | null, planId?: string) {
    if (stale(serverId)) return
    const result = await api.actFirewall(change, keep, password || undefined, planId)
    if (stale(serverId)) return
    if (result.confirm_required && result.plan) {
      // The firewall changed since the plan was made: nothing ran, and this is
      // what the change would do now.
      ask(change, result.plan, result.plan_id ?? '')
      return
    }
    if (result.sudo_rejected) {
      password = ''
      needsPassword = true
      actionError = $LL.powerRejected()
      return
    }
    if (!result.succeeded) {
      actionError = result.stderr.trim() || $LL.fwFailed()
    } else {
      notice = $LL.fwApplied()
      drafting = false
      adding = null
    }
    // Read again after a failure too: a script stopped part way through has
    // still changed what it got to.
    await load()
  }

  async function confirmPending() {
    const p = pending
    if (!p) return
    const serverId = servers.currentId
    pending = null
    busy = true
    try {
      await make(p.change, keepOpen, serverId, p.planId)
    } catch (e) {
      actionError = refused(e) ?? ''
    } finally {
      busy = false
    }
  }

  $effect(() => {
    if (countdown <= 0) return
    const timer = setTimeout(() => countdown--, 1000)
    return () => clearTimeout(timer)
  })

  const ufw = (change: Extract<FirewallChange, { kind: 'ufw' }>['change'], message?: string) =>
    propose({ kind: 'ufw', change }, message)
  const fwd = (change: Extract<FirewallChange, { kind: 'firewalld' }>['change'], message?: string) =>
    propose({ kind: 'firewalld', change }, message)

  function submitDraft() {
    draftError = ''
    const d = $state.snapshot(draft)
    void ufw({ type: 'add_rule', draft: d })
  }

  function openDraft() {
    draft = emptyDraft()
    draftError = ''
    moreOptions = false
    drafting = true
  }

  // --- firewalld ---

  const fw = $derived(view?.firewalld)
  const zones = $derived(fw ? (fw.runtime ?? fw.permanent) : [])
  /// The zone this panel's connection or SSH surely lands in, else the default.
  const firstZone = $derived(
    view?.firewalld?.access_zones.find((z) => z !== null) ?? fw?.default_zone ?? zones[0]?.name ?? null,
  )
  const zone = $derived(zones.find((z) => z.name === (zoneName ?? firstZone)) ?? null)
  const saved = $derived(fw?.permanent.find((z) => z.name === zone?.name) ?? null)

  type Held = { value: string; runtime: boolean; permanent: boolean }

  /// The runtime's items, then those only the saved configuration has. Stopped,
  /// there is only the saved one.
  function held(runtime: string[] | undefined, permanent: string[]): Held[] {
    if (!fw?.runtime || runtime === undefined) {
      return permanent.map((value) => ({ value, runtime: false, permanent: true }))
    }
    return [
      ...runtime.map((value) => ({ value, runtime: true, permanent: permanent.includes(value) })),
      ...permanent.filter((v) => !runtime.includes(v)).map((value) => ({ value, runtime: false, permanent: true })),
    ]
  }

  const port = (p: { port: string; protocol: string }) => `${p.port}/${p.protocol}`
  const runtimeZone = $derived(fw?.runtime ? zone : null)

  function sections(z: FirewalldZone, rz: FirewalldZone | null, sz: FirewalldZone | null) {
    const pick = (f: (z: FirewalldZone) => string[]) => ({
      items: held(rz ? f(rz) : undefined, sz ? f(sz) : f(z)),
    })
    return [
      { item: 'interface' as const, title: $LL.fwInterfaces(), hint: 'eth0', ...pick((z) => z.interfaces) },
      { item: 'source' as const, title: $LL.fwSources(), hint: '192.168.1.0/24', ...pick((z) => z.sources) },
      { item: 'service' as const, title: $LL.fwServices(), hint: '', ...pick((z) => z.services) },
      { item: 'port' as const, title: $LL.fwPorts(), hint: '8080/tcp', ...pick((z) => z.ports.map(port)) },
      {
        item: 'rich_rule' as const,
        title: $LL.fwRichRules(),
        hint: 'rule family="ipv4" source address="192.0.2.0/24" service name="ssh" accept',
        ...pick((z) => z.rich_rules.map((r) => r.raw)),
      },
      {
        item: 'forward_port' as const,
        title: $LL.fwForwardPorts(),
        hint: 'port=80:proto=tcp:toport=8080',
        ...pick((z) => z.forward_ports),
      },
    ]
  }

  function removeItem(item: FirewalldItem | 'interface', value: string) {
    const z = zone?.name
    if (!z) return
    const message = $LL.fwRemoveFrom({ value, zone: z })
    if (item === 'interface') void fwd({ type: 'remove_interface', zone: z, iface: value }, message)
    else void fwd({ type: 'remove', zone: z, item, value }, message)
  }

  function addItem() {
    const z = zone?.name
    const what = adding
    if (!z || !what || !addValue.trim()) return
    if (what.item === 'interface') void fwd({ type: 'change_interface', zone: z, iface: addValue })
    else void fwd({ type: 'add', zone: z, item: what.item, value: addValue })
  }

  function startAdding(item: FirewalldItem | 'interface') {
    adding = { item }
    // A service is picked from a list, which starts on its first entry.
    addValue = item === 'service' ? (services[0] ?? '') : ''
    actionError = ''
  }

  const services = $derived(
    zone && fw ? fw.service_names.filter((name) => !zone.services.includes(name)) : [],
  )
  const shutByReload = $derived(view?.accesses.filter((a) => a.shut_by_reload) ?? [])

  function zoneTags(z: FirewalldZone): string[] {
    return [
      ...(z.name === fw?.default_zone ? [$LL.fwDefaultTag()] : []),
      ...(z.active ? [$LL.active()] : []),
      ...(view?.firewalld?.access_zones.includes(z.name) ? [$LL.fwThisConnection()] : []),
    ]
  }

  const CHAINS: { chain: UfwChain; label: () => string }[] = [
    { chain: 'incoming', label: () => $LL.fwIncoming() },
    { chain: 'outgoing', label: () => $LL.fwOutgoing() },
    { chain: 'routed', label: () => $LL.fwRouted() },
  ]
  const POLICIES: UfwPolicy[] = ['allow', 'deny', 'reject']
  const LOG_LEVELS: UfwLogLevel[] = ['off', 'low', 'medium', 'high', 'full']
  const TARGETS: FirewalldTarget[] = ['default_target', 'accept', 'drop', 'reject']
  const targetText = (t: FirewalldTarget) => (t === 'default_target' ? 'default' : t.toUpperCase())

  function reasonText(v: FirewallView): string {
    switch (v.reason_kind) {
      case 'unsupported_platform':
        return $LL.fwLinuxOnly()
      case 'none_installed':
        return $LL.fwNoneInstalled()
      default:
        return $LL.fwUnreadable()
    }
  }

  const both = $derived(view?.ufw_installed != null && view?.firewalld_installed != null)
  const conflict = $derived(view?.ufw_installed === true && view?.firewalld_installed === true)
</script>

<AppToolbar subtitle={view?.kind ?? undefined}>
  {#snippet actions()}
    {#if view?.kind === 'ufw' && view.ufw?.active}
      <Button size="sm" variant="tinted" icon="add" onclick={openDraft} disabled={busy}>{$LL.fwAddRule()}</Button>
    {/if}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} disabled={loading} />
  {/snippet}
</AppToolbar>

<main class="space-y-[9px] px-[17px] pb-[17px] pt-[4px]">
  {#if error}<Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card>{/if}
  {#if notice}<Card><p class="text-[13px] text-(--text-secondary)">{notice}</p></Card>{/if}
  {#if actionError}<Card><pre class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{actionError}</pre></Card>{/if}

  {#if needsPassword}
    <!-- The password travels as a field of each request, never in a command
         line or audit row. -->
    <Card>
      <p class="mb-[9px] text-[13px]">{$LL.fwNeedsRoot()}</p>
      <form class="flex flex-wrap items-end gap-[9px]" onsubmit={(e) => (e.preventDefault(), submitPassword())}>
        <Input class="min-w-0 flex-1" type="password" label={$LL.powerPassword()} bind:value={passwordDraft} />
        <Button type="submit" variant="primary" disabled={loading}>{$LL.confirm()}</Button>
      </form>
    </Card>
  {/if}

  {#if loading && !view}
    <Card class="grid place-items-center" padding="21px"><Spinner class="h-5 w-5" /></Card>
  {:else if view && !view.available && !needsPassword}
    <Card>
      <p class="text-[13px] text-(--text-secondary)">{reasonText(view)}</p>
      {#if view.reason}<pre class="lk-mono mt-[9px] whitespace-pre-wrap break-all text-[12px] text-(--text-tertiary)">{view.reason}</pre>{/if}
    </Card>
  {:else if view?.available}
    {#if both}
      <!-- The machine has one of the two firewalls; all changes below target
           the selected one. -->
      <SegmentedControl size="sm" label={$LL.fwFirewallType()} value={view.kind === 'firewalld' ? 'firewalld' : 'ufw'} options={[{ value: 'ufw', label: 'ufw' }, { value: 'firewalld', label: 'firewalld' }]} onchange={(value) => switchTo(value)} />
    {/if}
    {#if conflict}<Card><p class="text-[13px] text-(--color-warning)">{$LL.fwConflict()}</p></Card>{/if}

    <!-- What every change is checked against. -->
    <Card title={$LL.fwAccesses()}>
      {#each view.accesses as access (access.via)}
        <div class="flex items-center justify-between gap-[9px] border-t border-(--border-hairline) py-[7px]">
          <span class="text-[13px]">{accessName(access)}</span>
          <Badge tone={reachTone(access.reach)}>{reachText(access.reach)}</Badge>
        </div>
      {/each}
      {#if view.proxied}<p class="mt-[7px] text-[12px] text-(--text-secondary)">{$LL.fwProxied()}</p>{/if}
    </Card>

    {#key rev}
      {#if view.kind === 'ufw' && view.ufw}
        {@const s = view.ufw}
        <Card>
          <div class="flex flex-wrap items-center gap-[7px]">
            <Badge tone={s.active ? 'success' : 'neutral'} dot>{s.active ? $LL.active() : $LL.fwInactive()}</Badge>
            {#if s.version}<span class="lk-mono text-[12px] text-(--text-tertiary)">{s.version}</span>{/if}
            <span class="flex-1"></span>
            {#if s.active}<Button size="sm" variant="secondary" disabled={busy} onclick={() => void ufw({ type: 'reload' })}>{$LL.fwReload()}</Button>{/if}
            <Button size="sm" variant={s.active ? 'destructive' : 'primary'} disabled={busy} onclick={() => void ufw({ type: s.active ? 'disable' : 'enable' })}>{s.active ? $LL.fwTurnOff() : $LL.fwTurnOn()}</Button>
          </div>
          <div class="mt-[13px] grid grid-cols-1 gap-[13px] @2xl:grid-cols-4">
            {#each CHAINS as { chain, label } (chain)}
              <label class="grid gap-[5px] text-[12px] text-(--text-secondary)">
                <span>{$LL.fwDefaultPolicy()} · {label()}</span>
                <Select value={s.policies[chain] ?? ''} options={POLICIES.map((value) => ({ value, label: value }))} disabled={busy} onchange={(e) => void ufw({ type: 'policy', chain, policy: e.currentTarget.value as UfwPolicy })} />
              </label>
            {/each}
            <label class="grid gap-[5px] text-[12px] text-(--text-secondary)">
              <span>{$LL.fwLogging()}</span>
              <Select value={s.log_level ?? ''} options={LOG_LEVELS.map((value) => ({ value, label: value }))} disabled={busy} onchange={(e) => void ufw({ type: 'logging', level: e.currentTarget.value as UfwLogLevel })} />
            </label>
          </div>
        </Card>

        <Card padding="0">
          <h2 class="px-[15px] py-[11px] text-[15px] font-semibold">{$LL.fwRules()}</h2>
          {#each s.rules as rule, index (rule.tuples.join('\n'))}
            <div class="flex min-h-7 items-center gap-[13px] px-[13px] py-[5px] {index % 2 === 1 ? 'bg-(--fill-hover)' : ''}">
              <span class="min-w-0 flex-1 text-[13px]">
                <span class="flex flex-wrap items-baseline gap-[7px]">
                  <Badge tone={rule.action === 'allow' ? 'success' : rule.action === 'limit' ? 'warning' : 'danger'}>{rule.action}</Badge>
                  <span class="lk-mono">{endpointText(rule.to, rule.protocol)}</span>
                  <span class="text-[12px] text-(--text-tertiary)">{rule.direction === 'incoming' ? $LL.fwIncoming() : $LL.fwOutgoing()} · {$LL.fwFrom()}{endpointText(rule.from, rule.protocol)}{rule.ip_version === 'v6' ? ' (v6)' : ''}</span>
                </span>
                {#if rule.comment}<span class="block text-[12px] text-(--text-tertiary)">{rule.comment}</span>{/if}
              </span>
              <IconButton icon="delete" label={$LL.fwDeleteRule({ rule: ruleText(rule) })} disabled={busy} onclick={() => void ufw({ type: 'delete_rule', tuples: rule.tuples }, $LL.fwDeleteRule({ rule: ruleText(rule) }))} />
            </div>
          {:else}
            <p class="px-[15px] py-[11px] text-[13px] text-(--text-secondary)">{$LL.fwNoRules()}</p>
          {/each}
        </Card>
      {:else if view.kind === 'firewalld' && fw}
        {#if fw.panic}
          <Card class="flex flex-wrap items-center gap-[9px]">
            <p class="flex-1 text-[13px] text-(--color-danger)">{$LL.fwPanic()}</p>
            <Button size="sm" variant="destructive" disabled={busy} onclick={() => void fwd({ type: 'panic_off' })}>
              {$LL.fwPanicOff()}
            </Button>
          </Card>
        {/if}
        {#if !fw.running}
          <Card><p class="text-[13px] text-(--text-secondary)">{$LL.fwStoppedNote()}</p></Card>
        {/if}
        {#if fw.drifted}
          <Card>
            <p class="text-[13px]">{$LL.fwDrift()}</p>
            {#each shutByReload as access (access.via)}
              <p class="mt-[7px] text-[13px] text-(--color-danger)">{$LL.fwDriftLockout({ access: accessName(access) })}</p>
            {/each}
            <div class="flex flex-wrap gap-2">
              <Button size="sm" variant="secondary" disabled={busy} onclick={() => void fwd({ type: 'runtime_to_permanent' })}>
                {$LL.fwSaveRuntime()}
              </Button>
              <Button size="sm" variant="secondary" disabled={busy} onclick={() => void fwd({ type: 'reload' })}>
                {$LL.fwReload()}
              </Button>
            </div>
          </Card>
        {/if}

        <Card>
          <div class="flex flex-wrap items-center gap-[7px]">
            <Badge tone={fw.running ? 'success' : 'neutral'} dot>{fw.running ? $LL.fwRunning() : $LL.fwStopped()}</Badge>
            {#if fw.version}<span class="lk-mono text-[12px] text-(--text-tertiary)">{fw.version}</span>{/if}
            <span class="flex-1"></span>
            {#if fw.running && !fw.drifted}<Button size="sm" variant="secondary" disabled={busy} onclick={() => void fwd({ type: 'reload' })}>{$LL.fwReload()}</Button>{/if}
            <Button size="sm" variant={fw.running ? 'destructive' : 'primary'} disabled={busy} onclick={() => void fwd({ type: fw.running ? 'stop' : 'start' })}>{fw.running ? $LL.fwTurnOff() : $LL.fwTurnOn()}</Button>
          </div>
          <div class="mt-[13px] grid grid-cols-1 gap-[13px] @2xl:grid-cols-2">
            <label class="grid gap-[5px] text-[12px] text-(--text-secondary)">
              <span>{$LL.fwDefaultZone()}</span>
              <Select value={fw.default_zone ?? ''} options={zones.map((z) => ({ value: z.name, label: z.name }))} disabled={busy} onchange={(e) => void fwd({ type: 'default_zone', zone: e.currentTarget.value })} />
            </label>
            <label class="grid gap-[5px] text-[12px] text-(--text-secondary)">
              <span>{$LL.fwZone()}</span>
              <Select value={zone?.name ?? ''} options={zones.map((z) => { const tags = zoneTags(z); return { value: z.name, label: `${z.name}${tags.length ? ` (${tags.join(', ')})` : ''}` } })} onchange={(e) => { zoneName = e.currentTarget.value; adding = null }} />
            </label>
          </div>
        </Card>

        {#if zone}
          <Card>
            <div class="grid grid-cols-1 gap-[13px] @2xl:grid-cols-2">
              <label class="grid gap-[5px] text-[12px] text-(--text-secondary)">
                <span>{$LL.fwTarget()}</span>
                <Select value={(saved ?? zone).target} options={TARGETS.map((value) => ({ value, label: targetText(value) }))} disabled={busy} onchange={(e) => void fwd({ type: 'target', zone: zone.name, target: e.currentTarget.value as FirewalldTarget })} />
              </label>
              <label class="flex items-center gap-[7px] self-end text-[13px]">
                <input class="accent-(--color-accent)" type="checkbox" checked={zone.masquerade} disabled={busy} onchange={(e) => void fwd({ type: 'masquerade', zone: zone.name, enabled: e.currentTarget.checked })} />
                {$LL.fwMasquerade()}
              </label>
            </div>
          </Card>

          {#each sections(zone, runtimeZone, saved) as section (section.item)}
            <Card>
              <div class="mb-[9px] flex items-center gap-[9px]">
                <h2 class="min-w-0 flex-1 text-[15px] font-semibold">{section.title}</h2>
                <IconButton icon="add" label={$LL.add()} disabled={busy} onclick={() => startAdding(section.item)} />
              </div>
              {#each section.items as it (it.value)}
                <div class="flex min-h-7 items-center gap-[7px] border-t border-(--border-hairline) py-[5px]">
                  <span class="lk-mono min-w-0 flex-1 break-all text-[13px]">{it.value}</span>
                  {#if !it.permanent}<Badge tone="warning">{$LL.fwRuntimeOnly()}</Badge>{/if}
                  {#if !it.runtime && fw.running}<Badge tone="neutral">{$LL.fwPermanentOnly()}</Badge>{/if}
                  <IconButton icon="delete" label={$LL.fwRemoveFrom({ value: it.value, zone: zone.name })} disabled={busy} onclick={() => removeItem(section.item, it.value)} />
                </div>
              {:else}
                <p class="border-t border-(--border-hairline) py-[7px] text-[13px] text-(--text-secondary)">{$LL.fwNone()}</p>
              {/each}
              {#if adding?.item === section.item}
                <form class="mt-[9px] flex flex-wrap items-end gap-[7px]" onsubmit={(e) => (e.preventDefault(), addItem())}>
                  {#if section.item === 'service'}
                    <Select class="min-w-0 flex-1" bind:value={addValue} options={services.map((value) => ({ value, label: value }))} label={section.title} />
                  {:else}
                    <Input class="min-w-0 flex-1" mono label={section.title} placeholder={section.hint} bind:value={addValue} />
                  {/if}
                  <Button type="submit" size="sm" variant="primary" disabled={busy || !addValue.trim()}>{$LL.add()}</Button>
                  <Button size="sm" variant="secondary" onclick={() => (adding = null)}>{$LL.cancel()}</Button>
                </form>
              {/if}
            </Card>
          {/each}
        {/if}
      {/if}
    {/key}

    {#if busy}
      <div class="flex items-center gap-2 text-xs text-(--text-secondary)"><Spinner size="sm" /></div>
    {/if}
  {/if}
</main>

<!-- The agent's plan for a change that makes something worse, or that is asked
     about anyway. It is planned again when confirmed, from a fresh read. -->
{#if pending}
  {@const plan = pending.plan}
  <Dialog open wide title={$LL.confirm()} message={pending.message} onclose={() => (pending = null)}>
    {#snippet actions()}
      <Button variant={plan.countdown || plan.destructive ? 'destructive' : 'primary'} disabled={busy || countdown > 0} onclick={() => void confirmPending()}>
        {countdown > 0 ? `${$LL.confirm()} (${countdown})` : $LL.confirm()}
      </Button>
      <Button variant="secondary" onclick={() => (pending = null)}>{$LL.cancel()}</Button>
    {/snippet}
    {#if !pending.message}
      <p class="text-[12px] text-(--text-secondary)">{$LL.fwCommands()}</p>
      <pre class="mt-[7px] overflow-x-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] lk-mono text-[13px]">{plan.commands.join('\\n')}</pre>
    {/if}
    {#each plan.notes as note (note)}
      {#if note === 'reload_loses'}<p class="mt-[9px] text-[12px] text-(--text-secondary)">{$LL.fwReloadLoses()}</p>{/if}
    {/each}
    {#each plan.effects.filter((e) => e.worse) as e, i (i)}
      <p class="mt-[9px] text-[13px] {e.after === 'blocked' ? 'text-(--color-danger)' : 'text-(--color-warning)'}">{warningText(e.access, e.after, e.later)}</p>
    {/each}
    {#if plan.keep_open.length}
      <Checkbox class="mt-[9px]" bind:checked={keepOpen} label={$LL.fwKeepOpen()} />
      <pre class="mt-[5px] whitespace-pre-wrap break-all lk-mono text-[12px] text-(--text-secondary)">{plan.keep_open.join('\\n')}</pre>
    {/if}
  </Dialog>
{/if}

{#if drafting && !pending}
  <Dialog open wide title={$LL.fwAddRule()} onclose={() => (drafting = false)}>
    {#snippet actions()}
      <Button variant="primary" type="submit" form="firewall-rule-form" disabled={busy}>{$LL.fwAddRule()}</Button>
      <Button variant="secondary" onclick={() => (drafting = false)}>{$LL.cancel()}</Button>
    {/snippet}
    <form id="firewall-rule-form" class="grid gap-[13px]" onsubmit={(e) => (e.preventDefault(), submitDraft())}>
      <div class="grid grid-cols-1 gap-[13px] @2xl:grid-cols-3">
        <label class="grid gap-[5px] text-[12px] text-(--text-secondary)">
          <span>{$LL.fwAction()}</span>
          <Select class="w-full" bind:value={draft.action} options={['allow', 'deny', 'reject', 'limit'].map((value) => ({ value, label: value }))} />
        </label>
        <label class="grid gap-[5px] text-[12px] text-(--text-secondary)">
          <span>{$LL.fwDirection()}</span>
          <Select class="w-full" bind:value={draft.direction} options={[{ value: 'incoming', label: $LL.fwIncoming() }, { value: 'outgoing', label: $LL.fwOutgoing() }]} />
        </label>
        <label class="grid gap-[5px] text-[12px] text-(--text-secondary)">
          <span>{$LL.fwProtocol()}</span>
          <Select class="w-full" value={draft.protocol ?? ''} options={[{ value: '', label: 'any' }, { value: 'tcp', label: 'tcp' }, { value: 'udp', label: 'udp' }]} onchange={(e) => (draft.protocol = e.currentTarget.value || null)} />
        </label>
      </div>
      <div class="grid grid-cols-1 gap-[13px] @2xl:grid-cols-2">
        <Input mono label={$LL.fwPort()} placeholder="22, 80,443, 6000:6010" bind:value={draft.port} />
        {#if view?.ufw?.apps.length}
          <Select class="w-full" label={$LL.fwAppProfile()} value={draft.app ?? ''} options={[{ value: '', label: '—' }, ...view.ufw.apps.map((app) => ({ value: app.name, label: app.name }))]} onchange={(e) => (draft.app = e.currentTarget.value || null)} />
        {/if}
        <Input mono label={$LL.fwFrom()} placeholder={$LL.fwAnywhere()} bind:value={draft.from} />
        <Input mono label={$LL.fwTo()} placeholder={$LL.fwAnywhere()} bind:value={draft.to} />
        <Input class="@2xl:col-span-2" label={$LL.fwComment()} bind:value={draft.comment} />
      </div>
      <Checkbox bind:checked={draft.prepend} label={$LL.fwPrepend()} />
      <Button variant="ghost" class="w-fit" icon="tune" onclick={() => (moreOptions = !moreOptions)}>{$LL.fwMoreOptions()}</Button>
      {#if moreOptions}
        <div class="grid grid-cols-1 gap-[13px] @2xl:grid-cols-2">
          <Input mono label={$LL.fwSourcePort()} bind:value={draft.source_port} />
          <Select class="w-full" label={$LL.fwLog()} value={draft.log ?? ''} options={[{ value: '', label: '—' }, { value: 'log', label: 'log' }, { value: 'log_all', label: 'log-all' }]} onchange={(e) => (draft.log = (e.currentTarget.value || null) as UfwRuleDraft['log'])} />
          <Input mono label={$LL.fwInterfaceIn()} bind:value={draft.interface_in} />
          <Input mono label={$LL.fwInterfaceOut()} bind:value={draft.interface_out} />
          <Checkbox bind:checked={draft.routed} label={$LL.fwRouted()} />
        </div>
      {/if}
      {#if draftError}<p class="text-[13px] text-(--color-danger)">{draftError}</p>{/if}
    </form>
  </Dialog>
{/if}
