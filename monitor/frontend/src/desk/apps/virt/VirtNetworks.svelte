<script lang="ts">
  import { Badge, Button, Card, Checkbox, Dialog, Icon, IconButton, Input, Select, Spinner, Switch } from '@lollipopkit/desk-ui'
  import { api } from '../../../lib/api'
  import { refText, virtErrorText, virtRequestText } from '../../../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { VirtChange, VirtHostView, VirtNetHost, VirtNetwork, VirtNetworkChanges } from '../../../types'

  /// The host's networks: libvirt's virtual networks, or every PVE node's
  /// interfaces with the configuration waiting to be applied on each. What a
  /// change may be is the agent's answer — it refuses one to an interface
  /// carrying the host's management traffic, and an apply that touches one.
  interface Props {
    view: VirtHostView
    sudoPassword: string | null
  }

  const { view, sudoPassword }: Props = $props()

  const caps = $derived(view.capabilities)
  const pve = $derived(view.host.kind === 'pve')
  const modes = $derived((caps.network_modes as string[] | undefined) ?? [])

  let networks = $state<VirtNetwork[] | null>(null)
  let changes = $state<VirtNetworkChanges[]>([])
  let error = $state('')
  let busy = $state(false)
  let loading = $state(false)

  let creating = $state(false)
  let createForm = $state({ name: '', mode: '', node: '', bridge: '', cidr: '', dhcpStart: '', dhcpEnd: '', vlanAware: false, autostart: true })
  /// libvirt's edit.
  let editing = $state<VirtNetwork | null>(null)
  let editForm = $state({ mode: '', bridge: '', address: '', prefix: '', dhcpStart: '', dhcpEnd: '', restart: false, hosts: [] as VirtNetHost[] })
  /// PVE's bridge edit.
  let editingBridge = $state<VirtNetwork | null>(null)
  let bridgeForm = $state({ ports: '', cidr: '', gateway: '', vlanAware: false, autostart: true })
  let confirm = $state<{ text: string; label: string; change: VirtChange } | null>(null)

  $effect(() => {
    void sudoPassword
    untrack(() => void load())
  })

  async function load() {
    loading = true
    try {
      const answer = await api.virtNetworks(sudoPassword ?? undefined)
      if (answer.error) {
        error = virtErrorText(answer.error)
        return
      }
      networks = answer.networks ?? []
      changes = answer.changes ?? []
    } catch (e) {
      error = virtRequestText(e)
    } finally {
      loading = false
    }
  }

  async function run(change: VirtChange): Promise<boolean> {
    busy = true
    error = ''
    try {
      const { error: e } = await api.virtManage(change, sudoPassword ?? undefined)
      if (e) {
        error = virtErrorText(e)
        return false
      }
      await load()
      return true
    } catch (e) {
      error = virtRequestText(e)
      return false
    } finally {
      busy = false
    }
  }

  const blank = (s: string) => (s.trim() === '' ? null : s.trim())

  function openCreate() {
    createForm = {
      name: '',
      mode: pve ? 'bridge' : (modes[0] ?? 'nat'),
      node: view.host.nodes[0]?.name ?? '',
      bridge: '',
      cidr: '',
      dhcpStart: '',
      dhcpEnd: '',
      vlanAware: false,
      autostart: true,
    }
    creating = true
  }

  async function create(e: SubmitEvent) {
    e.preventDefault()
    const f = createForm
    const ok = await run({
      op: 'network_create',
      name: f.name.trim(),
      mode: f.mode,
      node: pve ? f.node : null,
      bridge: blank(f.bridge),
      cidr: blank(f.cidr),
      dhcp_start: pve ? null : blank(f.dhcpStart),
      dhcp_end: pve ? null : blank(f.dhcpEnd),
      vlan_aware: f.vlanAware,
      autostart: f.autostart,
    })
    if (ok) creating = false
  }

  function openEdit(n: VirtNetwork) {
    const cidr = n.cidrs.find((c) => !c.includes(':') && c.includes('/')) ?? ''
    const [address, prefix] = cidr ? cidr.split('/') : ['', '']
    const [dhcpStart, dhcpEnd] = n.dhcp_ranges[0]?.split('-') ?? ['', '']
    editForm = {
      mode: n.mode,
      bridge: n.mode === 'bridge' ? (n.bridge ?? '') : '',
      address,
      prefix,
      dhcpStart: dhcpStart ?? '',
      dhcpEnd: dhcpEnd ?? '',
      restart: false,
      hosts: n.hosts.map((h) => ({ ...h })),
    }
    editing = n
  }

  async function saveEdit(e: SubmitEvent) {
    e.preventDefault()
    const n = editing
    if (!n) return
    const f = editForm
    const ok = await run({
      op: 'network_edit',
      network: n.id,
      mode: f.mode,
      bridge: blank(f.bridge),
      address: blank(f.address),
      prefix: f.prefix.trim() === '' ? null : Number(f.prefix),
      dhcp_start: blank(f.dhcpStart),
      dhcp_end: blank(f.dhcpEnd),
      hosts: f.hosts.filter((h) => h.mac.trim() || h.ip.trim()).map((h) => ({ mac: h.mac.trim(), ip: h.ip.trim(), name: blank(h.name ?? '') })),
      restart: f.restart,
      base_xml: n.xml || null,
    })
    if (ok) editing = null
  }

  function openBridge(n: VirtNetwork) {
    bridgeForm = {
      ports: n.ports.join(' '),
      cidr: n.cidrs.find((c) => !c.includes(':')) ?? '',
      gateway: n.gateway ?? '',
      vlanAware: n.vlan_aware === true,
      autostart: n.autostart !== false,
    }
    editingBridge = n
  }

  async function saveBridge(e: SubmitEvent) {
    e.preventDefault()
    const n = editingBridge
    if (!n) return
    const f = bridgeForm
    const ok = await run({
      op: 'network_edit_bridge',
      network: n.id,
      ports: f.ports.trim(),
      cidr: f.cidr.trim(),
      gateway: blank(f.gateway),
      vlan_aware: f.vlanAware,
      autostart: f.autostart,
    })
    if (ok) editingBridge = null
  }
</script>

{#if error}
  <Card>
    <p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p>
  </Card>
{/if}

{#each changes as c (c.node)}
  <Card class="space-y-[9px]">
    <div class="flex flex-wrap items-center gap-[9px]">
      <span class="text-[13px] font-semibold text-(--text-primary)">{$LL.virtNetChanges({ node: c.node })}</span>
      <span class="ml-auto flex gap-[5px]">
        <Button size="sm" disabled={busy} onclick={() => (confirm = { text: $LL.virtNetApplyConfirm({ node: c.node }), label: $LL.virtNetApply(), change: { op: 'network_apply', node: c.node } })}>
          {$LL.virtNetApply()}
        </Button>
        <Button variant="secondary" size="sm" disabled={busy} onclick={() => (confirm = { text: $LL.virtNetRevertConfirm({ node: c.node }), label: $LL.virtNetRevert(), change: { op: 'network_revert', node: c.node } })}>
          {$LL.virtNetRevert()}
        </Button>
      </span>
    </div>
    <div class="overflow-x-auto">
      <pre class="lk-mono whitespace-pre text-[12px] leading-5">{#each c.diff.split('\n') as line, i (i)}<span class={line.startsWith('+') && !line.startsWith('+++') ? 'text-(--color-success)' : line.startsWith('-') && !line.startsWith('---') ? 'text-(--color-danger)' : 'text-(--text-secondary)'}>{line}</span>
{/each}</pre>
    </div>
  </Card>
{/each}

<Card class="space-y-[9px]">
  <div class="flex items-center gap-[9px]">
    {#if caps.network_edit}
      <Button size="sm" icon="add" disabled={busy} onclick={openCreate}>{pve ? $LL.virtNetCreateBridge() : $LL.virtNetCreate()}</Button>
    {/if}
    <IconButton class="ml-auto" icon="refresh" label={$LL.refresh()} disabled={loading} onclick={() => void load()} />
  </div>
  {#if networks === null}
    <Spinner class="h-5 w-5" />
  {:else if networks.length === 0}
    <div class="flex flex-col items-center gap-[9px] py-[27px] text-(--text-tertiary)">
      <Icon name="lan" size={48} weight={300} />
      <p class="text-[13px]">{$LL.virtEmptyNetworks()}</p>
    </div>
  {:else}
    <ul>
      {#each networks as n (n.id)}
        <li class="border-t border-(--border-hairline) py-[7px]">
          <div class="flex flex-wrap items-center gap-[9px]">
            <Badge tone={n.active ? 'success' : 'neutral'} dot>{n.active ? $LL.virtStateRunning() : $LL.virtStateStopped()}</Badge>
            <span class="text-[13px] font-semibold text-(--text-primary)">{n.name}</span>
            <span class="lk-mono text-[12px] text-(--text-tertiary)">{n.mode}{n.node && view.host.nodes.length > 1 ? ` · ${n.node}` : ''}</span>
            {#if n.autostart}<Badge>{$LL.virtNetAutostart()}</Badge>{/if}
            {#if n.vlan_aware}<Badge>{$LL.virtNetVlanAware()}</Badge>{/if}
            {#if n.pending_restart}<Badge tone="warning" dot>{$LL.virtNetPending()}</Badge>{/if}
            {#if pve && n.mode === 'bridge' && !n.management_editable}
              <Icon name="lock" size={16} title={$LL.virtNetManagement()} />
            {/if}
            {#if caps.network_edit}
              <span class="ml-auto flex flex-wrap gap-[5px]">
                {#if pve}
                  {#if n.management_editable}
                    <Button variant="secondary" size="sm" icon="edit" disabled={busy} onclick={() => openBridge(n)}>{$LL.virtEdit()}</Button>
                    <IconButton icon="delete" label={$LL.virtDelete()} disabled={busy} onclick={() => (confirm = { text: $LL.virtNetDeleteConfirm({ name: n.name }), label: $LL.virtDelete(), change: { op: 'network_delete', network: n.id } })} />
                  {/if}
                {:else}
                  {#if n.pending_restart && n.active}
                    <Button variant="secondary" size="sm" icon="restart_alt" disabled={busy} onclick={() => (confirm = { text: $LL.virtNetRestartConfirm({ name: n.name }), label: $LL.virtNetRestart(), change: { op: 'network_restart', network: n.id, base_xml: n.xml || null } })}>
                      {$LL.virtNetRestart()}
                    </Button>
                  {/if}
                  <Button variant="secondary" size="sm" icon={n.active ? 'stop' : 'play_arrow'} disabled={busy} onclick={() => void run({ op: 'network_set_active', network: n.id, active: !n.active })}>
                    {n.active ? $LL.virtNetStop() : $LL.virtNetStart()}
                  </Button>
                  <Switch label={$LL.virtNetAutostart()} checked={n.autostart === true} disabled={busy} onchange={(on) => void run({ op: 'network_set_autostart', network: n.id, on })} />
                  {#if caps.network_edit_existing}
                    <Button variant="secondary" size="sm" icon="edit" disabled={busy} onclick={() => openEdit(n)}>{$LL.virtEdit()}</Button>
                  {/if}
                  <IconButton icon="delete" label={$LL.virtDelete()} disabled={busy} onclick={() => (confirm = { text: $LL.virtNetDeleteConfirm({ name: n.name }), label: $LL.virtDelete(), change: { op: 'network_delete', network: n.id } })} />
                {/if}
              </span>
            {/if}
          </div>
          <p class="pl-[27px] text-[12px] text-(--text-secondary)">
            {[n.bridge && n.bridge !== n.name ? n.bridge : null, ...n.cidrs, n.gateway ? `via ${n.gateway}` : null, n.dhcp_ranges.length ? `DHCP ${n.dhcp_ranges.join(', ')}` : null, n.ports.length ? n.ports.join(' ') : null, n.bond_mode, n.comment]
              .filter(Boolean)
              .join(' · ')}
          </p>
          {#if n.users.length > 0}
            <p class="pl-[27px] text-[12px] text-(--text-tertiary)">{$LL.virtNetUsers()}: {n.users.map((u) => refText(u, view.guests) + (u.ip ? ` ${u.ip}` : '')).join(', ')}</p>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</Card>

{#if creating}
  <Dialog open wide title={pve ? $LL.virtNetCreateBridge() : $LL.virtNetCreate()} onclose={() => (creating = false)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (creating = false)}>{$LL.cancel()}</Button>
      <Button variant="primary" type="submit" form="virt-network-create" disabled={busy || createForm.name.trim() === ''}>{$LL.virtCreate()}</Button>
    {/snippet}
    <form id="virt-network-create" class="space-y-[13px]" onsubmit={(e) => { e.preventDefault(); void create(e) }}>
      <Input label={$LL.virtNetName()} class="lk-mono" bind:value={createForm.name} placeholder={pve ? 'vmbr1' : 'lab'} />
      {#if pve}
        {#if view.host.nodes.length > 1}
          <Select label={$LL.virtNetNode()} bind:value={createForm.node} options={view.host.nodes.map((node) => ({ value: node.name, label: node.name }))} />
        {/if}
        <Input label={$LL.virtNetPorts()} class="lk-mono" bind:value={createForm.bridge} placeholder="eno2" />
      {:else}
        <Select label={$LL.virtNetMode()} bind:value={createForm.mode} options={modes.map((m) => ({ value: m, label: m }))} />
        {#if createForm.mode === 'bridge'}
          <Input label={$LL.virtNetBridge()} class="lk-mono" bind:value={createForm.bridge} placeholder="br0" />
        {/if}
      {/if}
      {#if pve || createForm.mode !== 'bridge'}
        <Input label={$LL.virtNetCidr()} class="lk-mono" bind:value={createForm.cidr} placeholder="192.168.150.1/24" />
      {/if}
      {#if !pve && createForm.mode !== 'bridge'}
        <div class="flex gap-[9px]">
          <Input class="lk-mono flex-1" label={$LL.virtNetDhcp()} bind:value={createForm.dhcpStart} placeholder="192.168.150.100" />
          <Input class="lk-mono flex-1" label="" bind:value={createForm.dhcpEnd} placeholder="192.168.150.200" />
        </div>
      {/if}
      <div class="flex flex-wrap gap-[13px]">
        {#if pve}
          <Checkbox bind:checked={createForm.vlanAware} label={$LL.virtNetVlanAware()} />
        {/if}
        <Checkbox bind:checked={createForm.autostart} label={$LL.virtNetAutostart()} />
      </div>
      {#if error}<p class="text-[12px] text-(--color-danger) whitespace-pre-wrap">{error}</p>{/if}
    </form>
  </Dialog>
{/if}

{#if editing}
  {@const n = editing}
  <Dialog open wide title={`${$LL.virtEdit()} · ${n.name}`} onclose={() => (editing = null)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (editing = null)}>{$LL.cancel()}</Button>
      <Button variant="primary" type="submit" form="virt-network-edit" disabled={busy}>{$LL.save()}</Button>
    {/snippet}
    <form id="virt-network-edit" class="space-y-[13px]" onsubmit={(e) => { e.preventDefault(); void saveEdit(e) }}>
      <Select label={$LL.virtNetMode()} bind:value={editForm.mode} options={modes.map((m) => ({ value: m, label: m }))} />
      {#if editForm.mode === 'bridge'}
        <Input label={$LL.virtNetBridge()} class="lk-mono" bind:value={editForm.bridge} placeholder="br0" />
      {:else}
        <div class="flex gap-[9px]">
          <Input class="lk-mono flex-1" label={$LL.virtNetAddress()} bind:value={editForm.address} placeholder="192.168.150.1" />
          <Input class="lk-mono w-24" label={$LL.virtNetPrefix()} inputmode="numeric" bind:value={editForm.prefix} placeholder="24" />
        </div>
        <div class="flex gap-[9px]">
          <Input class="lk-mono flex-1" label={$LL.virtNetDhcp()} bind:value={editForm.dhcpStart} />
          <Input class="lk-mono flex-1" label="" bind:value={editForm.dhcpEnd} />
        </div>
        <div class="space-y-[9px]">
          <div class="flex items-center gap-[9px]">
            <span class="text-[13px] text-(--text-secondary)">{$LL.virtNetHosts()}</span>
            <IconButton icon="add" label={$LL.add()} onclick={() => (editForm.hosts = [...editForm.hosts, { mac: '', ip: '', name: null }])} />
          </div>
          {#each editForm.hosts as h, i (i)}
            <div class="flex gap-[9px]">
              <Input class="lk-mono flex-1" bind:value={h.mac} placeholder={$LL.virtNetMac()} aria-label={$LL.virtNetMac()} />
              <Input class="lk-mono flex-1" bind:value={h.ip} placeholder={$LL.virtNetIp()} aria-label={$LL.virtNetIp()} />
              <Input class="flex-1" bind:value={() => h.name ?? '', (v) => (h.name = v)} placeholder={$LL.virtNetHostName()} aria-label={$LL.virtNetHostName()} />
              <IconButton icon="close" label={$LL.virtDelete()} onclick={() => (editForm.hosts = editForm.hosts.filter((_, j) => j !== i))} />
            </div>
          {/each}
        </div>
      {/if}
      {#if n.active}
        <Checkbox bind:checked={editForm.restart} label={$LL.virtNetRestartNow()} />
      {/if}
      {#if error}<p class="text-[12px] text-(--color-danger) whitespace-pre-wrap">{error}</p>{/if}
    </form>
  </Dialog>
{/if}

{#if editingBridge}
  {@const n = editingBridge}
  <Dialog open wide title={`${$LL.virtEdit()} · ${n.name}`} onclose={() => (editingBridge = null)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (editingBridge = null)}>{$LL.cancel()}</Button>
      <Button variant="primary" type="submit" form="virt-network-bridge-edit" disabled={busy}>{$LL.save()}</Button>
    {/snippet}
    <form id="virt-network-bridge-edit" class="space-y-[13px]" onsubmit={(e) => { e.preventDefault(); void saveBridge(e) }}>
      <Input label={$LL.virtNetPorts()} class="lk-mono" bind:value={bridgeForm.ports} placeholder="eno2" />
      <Input label={$LL.virtNetCidr()} class="lk-mono" bind:value={bridgeForm.cidr} placeholder="10.20.0.1/24" />
      <Input label={$LL.virtNetGateway()} class="lk-mono" bind:value={bridgeForm.gateway} />
      <div class="flex flex-wrap gap-[13px]">
        <Checkbox bind:checked={bridgeForm.vlanAware} label={$LL.virtNetVlanAware()} />
        <Checkbox bind:checked={bridgeForm.autostart} label={$LL.virtNetAutostart()} />
      </div>
      {#if error}<p class="text-[12px] text-(--color-danger) whitespace-pre-wrap">{error}</p>{/if}
    </form>
  </Dialog>
{/if}

{#if confirm}
  {@const c = confirm}
  <Dialog open title={$LL.virtSectionNetworks()} message={c.text} onclose={() => (confirm = null)}>
    {#snippet icon()}<Icon name="warning" size={52} weight={300} />{/snippet}
    {#snippet actions()}
      <Button block variant="destructive" disabled={busy} onclick={async () => { const change = c.change; confirm = null; await run(change) }}>{c.label}</Button>
      <Button block variant="secondary" onclick={() => (confirm = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}
