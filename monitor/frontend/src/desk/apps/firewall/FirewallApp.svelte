<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Select, Spinner } from '@serverbox/webui'
  import { Plus, RefreshCw, Trash2 } from '@lucide/svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
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
      <IconButton label={$LL.fwAddRule()} onclick={openDraft} disabled={busy}>
        <Plus class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} onclick={() => void load()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</AppToolbar>

<main class="mx-auto max-w-5xl space-y-3 px-4 py-4 @3xl:px-6">
  {#if error}
    <Card class="border-danger/40 bg-danger/5 p-3">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}
  {#if notice}
    <Card class="p-3"><p class="text-sm text-muted-fg">{notice}</p></Card>
  {/if}
  {#if actionError}
    <Card class="border-danger/40 bg-danger/5 p-3">
      <pre class="text-sm text-danger whitespace-pre-wrap break-all">{actionError}</pre>
    </Card>
  {/if}

  {#if needsPassword}
    <!-- The password travels as a field of each request, so it never lands in
         the machine's process list nor in the audit row. -->
    <Card class="space-y-2 p-4">
      <p class="text-sm text-fg">{$LL.fwNeedsRoot()}</p>
      <form class="flex flex-wrap items-center gap-2" onsubmit={(e) => (e.preventDefault(), submitPassword())}>
        <Input
          class="min-w-0 flex-1"
          type="password"
          aria-label={$LL.powerPassword()}
          placeholder={$LL.powerPassword()}
          bind:value={passwordDraft}
        />
        <Button type="submit" disabled={loading}>{$LL.confirm()}</Button>
      </form>
    </Card>
  {/if}

  {#if loading && !view}
    <Card class="grid place-items-center p-8"><Spinner class="h-5 w-5" /></Card>
  {:else if view && !view.available && !needsPassword}
    <Card class="space-y-2 p-4">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
      {#if view.reason}
        <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.reason}</pre>
      {/if}
    </Card>
  {:else if view?.available}
    {#if both}
      <!-- Which of the two is on screen, as one control rather than two
           buttons: the machine has one or the other, and the picked one is
           what every change below is about. -->
      <div class="flex w-fit gap-0.5 rounded-lg border border-line p-0.5">
        {#each ['ufw', 'firewalld'] as const as k (k)}
          <button
            class="rounded-md px-3 py-1 text-xs transition-colors {k === view.kind
              ? 'bg-soft text-fg-strong'
              : 'text-muted-fg hover:bg-soft/60 hover:text-fg'}"
            aria-pressed={k === view.kind}
            onclick={() => switchTo(k)}
          >
            {k}
          </button>
        {/each}
      </div>
    {/if}
    {#if conflict}
      <Card class="border-warning/40 bg-warning/5 p-4">
        <p class="text-sm text-warning">{$LL.fwConflict()}</p>
      </Card>
    {/if}

    <!-- What every change is checked against. -->
    <Card class="space-y-2 p-4">
      <h2 class="text-sm font-medium text-fg-strong">{$LL.fwAccesses()}</h2>
      {#each view.accesses as access (access.via)}
        <div class="flex items-center justify-between gap-2 rounded-lg px-1 py-1 text-sm">
          <span class="text-fg">{accessName(access)}</span>
          <Badge tone={reachTone(access.reach)}>{reachText(access.reach)}</Badge>
        </div>
      {/each}
      {#if view.proxied}
        <p class="text-xs text-muted-fg">{$LL.fwProxied()}</p>
      {/if}
    </Card>

    {#key rev}
      {#if view.kind === 'ufw' && view.ufw}
        {@const s = view.ufw}
        <Card class="space-y-3 p-4">
          <div class="flex flex-wrap items-center gap-2">
            <Badge tone={s.active ? 'success' : 'neutral'}>{s.active ? $LL.active() : $LL.fwInactive()}</Badge>
            {#if s.version}<span class="text-xs text-faint-fg">{s.version}</span>{/if}
            <span class="flex-1"></span>
            {#if s.active}
              <Button size="sm" variant="secondary" disabled={busy} onclick={() => void ufw({ type: 'reload' })}>
                {$LL.fwReload()}
              </Button>
            {/if}
            <Button
              size="sm"
              variant={s.active ? 'danger' : 'primary'}
              disabled={busy}
              onclick={() => void ufw({ type: s.active ? 'disable' : 'enable' })}
            >
              {s.active ? $LL.fwTurnOff() : $LL.fwTurnOn()}
            </Button>
          </div>
          <div class="grid grid-cols-1 gap-3 @2xl:grid-cols-4">
            {#each CHAINS as { chain, label } (chain)}
              <label class="space-y-1 text-xs text-muted-fg">
                <span>{$LL.fwDefaultPolicy()} · {label()}</span>
                <Select
                  class="w-full"
                  value={s.policies[chain] ?? ''}
                  disabled={busy}
                  onchange={(e) => void ufw({ type: 'policy', chain, policy: e.currentTarget.value as UfwPolicy })}
                >
                  {#each POLICIES as p (p)}<option value={p}>{p}</option>{/each}
                </Select>
              </label>
            {/each}
            <label class="space-y-1 text-xs text-muted-fg">
              <span>{$LL.fwLogging()}</span>
              <Select
                class="w-full"
                value={s.log_level ?? ''}
                disabled={busy}
                onchange={(e) => void ufw({ type: 'logging', level: e.currentTarget.value as UfwLogLevel })}
              >
                {#each LOG_LEVELS as l (l)}<option value={l}>{l}</option>{/each}
              </Select>
            </label>
          </div>
        </Card>

        <Card class="divide-y divide-line overflow-clip p-0">
          <h2 class="px-4 py-3 text-sm font-medium text-fg-strong">{$LL.fwRules()}</h2>
          {#each s.rules as rule (rule.tuples.join('\n'))}
            <div class="flex items-center gap-3 px-4 py-2 transition-colors hover:bg-soft/40">
              <span class="min-w-0 flex-1 text-sm">
                <span class="flex flex-wrap items-baseline gap-2">
                  <Badge tone={rule.action === 'allow' ? 'success' : rule.action === 'limit' ? 'warning' : 'danger'}>
                    {rule.action}
                  </Badge>
                  <span class="font-mono text-fg">{endpointText(rule.to, rule.protocol)}</span>
                  <span class="text-xs text-muted-fg">
                    {rule.direction === 'incoming' ? $LL.fwIncoming() : $LL.fwOutgoing()} · {$LL.fwFrom()}
                    {endpointText(rule.from, rule.protocol)}{rule.ip_version === 'v6' ? ' (v6)' : ''}
                  </span>
                </span>
                {#if rule.comment}<span class="block text-xs text-faint-fg">{rule.comment}</span>{/if}
              </span>
              <IconButton
                label={$LL.fwDeleteRule({ rule: ruleText(rule) })}
                disabled={busy}
                onclick={() =>
                  void ufw({ type: 'delete_rule', tuples: rule.tuples }, $LL.fwDeleteRule({ rule: ruleText(rule) }))}
              >
                <Trash2 class="w-4 h-4" />
              </IconButton>
            </div>
          {:else}
            <p class="px-4 py-3 text-sm text-muted-fg">{$LL.fwNoRules()}</p>
          {/each}
        </Card>
      {:else if view.kind === 'firewalld' && fw}
        {#if fw.panic}
          <Card class="flex flex-wrap items-center gap-2 border-danger/40 bg-danger/5 p-4">
            <p class="flex-1 text-sm text-danger">{$LL.fwPanic()}</p>
            <Button size="sm" variant="danger" disabled={busy} onclick={() => void fwd({ type: 'panic_off' })}>
              {$LL.fwPanicOff()}
            </Button>
          </Card>
        {/if}
        {#if !fw.running}
          <Card class="p-4"><p class="text-sm text-muted-fg">{$LL.fwStoppedNote()}</p></Card>
        {/if}
        {#if fw.drifted}
          <Card class="space-y-2 p-4 {shutByReload.length ? 'border-danger/40 bg-danger/5' : ''}">
            <p class="text-sm text-fg">{$LL.fwDrift()}</p>
            {#each shutByReload as access (access.via)}
              <p class="text-sm text-danger">{$LL.fwDriftLockout({ access: accessName(access) })}</p>
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

        <Card class="space-y-3 p-4">
          <div class="flex flex-wrap items-center gap-2">
            <Badge tone={fw.running ? 'success' : 'neutral'}>{fw.running ? $LL.fwRunning() : $LL.fwStopped()}</Badge>
            {#if fw.version}<span class="text-xs text-faint-fg">{fw.version}</span>{/if}
            <span class="flex-1"></span>
            {#if fw.running && !fw.drifted}
              <Button size="sm" variant="secondary" disabled={busy} onclick={() => void fwd({ type: 'reload' })}>
                {$LL.fwReload()}
              </Button>
            {/if}
            <Button
              size="sm"
              variant={fw.running ? 'danger' : 'primary'}
              disabled={busy}
              onclick={() => void fwd({ type: fw.running ? 'stop' : 'start' })}
            >
              {fw.running ? $LL.fwTurnOff() : $LL.fwTurnOn()}
            </Button>
          </div>
          <div class="grid grid-cols-1 gap-3 @2xl:grid-cols-2">
            <label class="space-y-1 text-xs text-muted-fg">
              <span>{$LL.fwDefaultZone()}</span>
              <Select
                class="w-full"
                value={fw.default_zone ?? ''}
                disabled={busy}
                onchange={(e) => void fwd({ type: 'default_zone', zone: e.currentTarget.value })}
              >
                {#each zones as z (z.name)}<option value={z.name}>{z.name}</option>{/each}
              </Select>
            </label>
            <label class="space-y-1 text-xs text-muted-fg">
              <span>{$LL.fwZone()}</span>
              <Select
                class="w-full"
                value={zone?.name ?? ''}
                onchange={(e) => {
                  zoneName = e.currentTarget.value
                  adding = null
                }}
              >
                {#each zones as z (z.name)}
                  {@const tags = zoneTags(z)}
                  <option value={z.name}>{z.name}{tags.length ? ` (${tags.join(', ')})` : ''}</option>
                {/each}
              </Select>
            </label>
          </div>
        </Card>

        {#if zone}
          <Card class="space-y-3 p-4">
            <div class="grid grid-cols-1 gap-3 @2xl:grid-cols-2">
              <label class="space-y-1 text-xs text-muted-fg">
                <span>{$LL.fwTarget()}</span>
                <Select
                  class="w-full"
                  value={(saved ?? zone).target}
                  disabled={busy}
                  onchange={(e) =>
                    void fwd({ type: 'target', zone: zone.name, target: e.currentTarget.value as FirewalldTarget })}
                >
                  {#each TARGETS as t (t)}<option value={t}>{targetText(t)}</option>{/each}
                </Select>
              </label>
              <label class="flex items-center gap-2 self-end text-sm text-fg">
                <input
                  type="checkbox"
                  checked={zone.masquerade}
                  disabled={busy}
                  onchange={(e) =>
                    void fwd({ type: 'masquerade', zone: zone.name, enabled: e.currentTarget.checked })}
                />
                {$LL.fwMasquerade()}
              </label>
            </div>
          </Card>

          {#each sections(zone, runtimeZone, saved) as section (section.item)}
            <Card class="space-y-2 p-4">
              <div class="flex items-center justify-between">
                <h2 class="text-sm font-medium text-fg-strong">{section.title}</h2>
                <IconButton label={$LL.add()} disabled={busy} onclick={() => startAdding(section.item)}>
                  <Plus class="w-4 h-4" />
                </IconButton>
              </div>
              {#each section.items as it (it.value)}
                <div class="flex items-center gap-2 rounded-lg px-1 py-1 transition-colors hover:bg-soft/40">
                  <span class="min-w-0 flex-1 break-all font-mono text-sm text-fg">{it.value}</span>
                  {#if !it.permanent}<Badge tone="warning">{$LL.fwRuntimeOnly()}</Badge>{/if}
                  {#if !it.runtime && fw.running}<Badge tone="neutral">{$LL.fwPermanentOnly()}</Badge>{/if}
                  <IconButton
                    label={$LL.fwRemoveFrom({ value: it.value, zone: zone.name })}
                    disabled={busy}
                    onclick={() => removeItem(section.item, it.value)}
                  >
                    <Trash2 class="w-4 h-4" />
                  </IconButton>
                </div>
              {:else}
                <p class="text-sm text-muted-fg">{$LL.fwNone()}</p>
              {/each}
              {#if adding?.item === section.item}
                <form class="flex flex-wrap items-center gap-2" onsubmit={(e) => (e.preventDefault(), addItem())}>
                  {#if section.item === 'service'}
                    <Select class="min-w-0 flex-1" bind:value={addValue} aria-label={section.title}>
                      {#each services as name (name)}<option value={name}>{name}</option>{/each}
                    </Select>
                  {:else}
                    <Input
                      class="min-w-0 flex-1 font-mono"
                      aria-label={section.title}
                      placeholder={section.hint}
                      bind:value={addValue}
                    />
                  {/if}
                  <Button type="submit" size="sm" disabled={busy || !addValue.trim()}>{$LL.add()}</Button>
                  <Button size="sm" variant="secondary" onclick={() => (adding = null)}>{$LL.cancel()}</Button>
                </form>
              {/if}
            </Card>
          {/each}
        {/if}
      {/if}
    {/key}

    {#if busy}
      <div class="flex items-center gap-2 text-xs text-muted-fg"><Spinner size="sm" /></div>
    {/if}
  {/if}
</main>

<!-- The agent's plan for a change that makes something worse, or that is asked
     about anyway. It is planned again when confirmed, from a fresh read. -->
{#if pending}
  {@const plan = pending.plan}
  <Modal open title={$LL.confirm()} onclose={() => (pending = null)}>
    <div class="space-y-3">
      {#if pending.message}
        <p class="text-sm text-fg">{pending.message}</p>
      {:else}
        <div class="space-y-1">
          <p class="text-xs text-muted-fg">{$LL.fwCommands()}</p>
          <pre class="overflow-x-auto rounded-lg bg-soft p-2 font-mono text-xs text-fg">{plan.commands.join('\n')}</pre>
        </div>
      {/if}
      {#each plan.notes as note (note)}
        {#if note === 'reload_loses'}<p class="text-xs text-muted-fg">{$LL.fwReloadLoses()}</p>{/if}
      {/each}
      {#each plan.effects.filter((e) => e.worse) as e, i (i)}
        <p class="text-sm {e.after === 'blocked' ? 'text-danger' : 'text-warning'}">
          {warningText(e.access, e.after, e.later)}
        </p>
      {/each}
      {#if plan.keep_open.length}
        <label class="flex items-start gap-2 text-sm text-fg">
          <input type="checkbox" class="mt-1" bind:checked={keepOpen} />
          <span>
            {$LL.fwKeepOpen()}
            <pre class="mt-1 whitespace-pre-wrap break-all font-mono text-xs text-muted-fg">{plan.keep_open.join('\n')}</pre>
          </span>
        </label>
      {/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (pending = null)}>{$LL.cancel()}</Button>
        <Button
          variant={plan.countdown || plan.destructive ? 'danger' : 'primary'}
          disabled={busy || countdown > 0}
          onclick={() => void confirmPending()}
        >
          {countdown > 0 ? `${$LL.confirm()} (${countdown})` : $LL.confirm()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if drafting && !pending}
  <Modal open title={$LL.fwAddRule()} onclose={() => (drafting = false)}>
    <form class="space-y-3" onsubmit={(e) => (e.preventDefault(), submitDraft())}>
      <div class="grid grid-cols-1 gap-3 @2xl:grid-cols-3">
        <label class="space-y-1 text-xs text-muted-fg">
          <span>{$LL.fwAction()}</span>
          <Select class="w-full" bind:value={draft.action}>
            {#each ['allow', 'deny', 'reject', 'limit'] as a (a)}<option value={a}>{a}</option>{/each}
          </Select>
        </label>
        <label class="space-y-1 text-xs text-muted-fg">
          <span>{$LL.fwDirection()}</span>
          <Select class="w-full" bind:value={draft.direction}>
            <option value="incoming">{$LL.fwIncoming()}</option>
            <option value="outgoing">{$LL.fwOutgoing()}</option>
          </Select>
        </label>
        <label class="space-y-1 text-xs text-muted-fg">
          <span>{$LL.fwProtocol()}</span>
          <Select
            class="w-full"
            value={draft.protocol ?? ''}
            onchange={(e) => (draft.protocol = e.currentTarget.value || null)}
          >
            <option value="">any</option>
            <option value="tcp">tcp</option>
            <option value="udp">udp</option>
          </Select>
        </label>
      </div>
      <div class="grid grid-cols-1 gap-3 @2xl:grid-cols-2">
        <label class="space-y-1 text-xs text-muted-fg">
          <span>{$LL.fwPort()}</span>
          <Input class="w-full font-mono" placeholder="22, 80,443, 6000:6010" bind:value={draft.port} />
        </label>
        {#if view?.ufw?.apps.length}
          <label class="space-y-1 text-xs text-muted-fg">
            <span>{$LL.fwAppProfile()}</span>
            <Select
              class="w-full"
              value={draft.app ?? ''}
              onchange={(e) => (draft.app = e.currentTarget.value || null)}
            >
              <option value="">—</option>
              {#each view.ufw.apps as app (app.name)}<option value={app.name}>{app.name}</option>{/each}
            </Select>
          </label>
        {/if}
        <label class="space-y-1 text-xs text-muted-fg">
          <span>{$LL.fwFrom()}</span>
          <Input class="w-full font-mono" placeholder={$LL.fwAnywhere()} bind:value={draft.from} />
        </label>
        <label class="space-y-1 text-xs text-muted-fg">
          <span>{$LL.fwTo()}</span>
          <Input class="w-full font-mono" placeholder={$LL.fwAnywhere()} bind:value={draft.to} />
        </label>
        <label class="space-y-1 text-xs text-muted-fg @2xl:col-span-2">
          <span>{$LL.fwComment()}</span>
          <Input class="w-full" bind:value={draft.comment} />
        </label>
      </div>
      <label class="flex items-center gap-2 text-sm text-fg">
        <input type="checkbox" bind:checked={draft.prepend} />
        {$LL.fwPrepend()}
      </label>
      <button type="button" class="text-xs text-muted-fg underline" onclick={() => (moreOptions = !moreOptions)}>
        {$LL.fwMoreOptions()}
      </button>
      {#if moreOptions}
        <div class="grid grid-cols-1 gap-3 @2xl:grid-cols-2">
          <label class="space-y-1 text-xs text-muted-fg">
            <span>{$LL.fwSourcePort()}</span>
            <Input class="w-full font-mono" bind:value={draft.source_port} />
          </label>
          <label class="space-y-1 text-xs text-muted-fg">
            <span>{$LL.fwLog()}</span>
            <Select class="w-full" value={draft.log ?? ''} onchange={(e) => (draft.log = (e.currentTarget.value || null) as UfwRuleDraft['log'])}>
              <option value="">—</option>
              <option value="log">log</option>
              <option value="log_all">log-all</option>
            </Select>
          </label>
          <label class="space-y-1 text-xs text-muted-fg">
            <span>{$LL.fwInterfaceIn()}</span>
            <Input class="w-full font-mono" bind:value={draft.interface_in} />
          </label>
          <label class="space-y-1 text-xs text-muted-fg">
            <span>{$LL.fwInterfaceOut()}</span>
            <Input class="w-full font-mono" bind:value={draft.interface_out} />
          </label>
          <label class="flex items-center gap-2 text-sm text-fg">
            <input type="checkbox" bind:checked={draft.routed} />
            {$LL.fwRouted()}
          </label>
        </div>
      {/if}
      {#if draftError}<p class="text-sm text-danger">{draftError}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (drafting = false)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy}>{$LL.fwAddRule()}</Button>
      </div>
    </form>
  </Modal>
{/if}
