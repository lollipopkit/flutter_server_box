<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Select, Spinner } from '@serverbox/webui'
  import { Lock, Pencil, Play, Plus, RefreshCw, RotateCcw, Square, Trash2, X } from '@lucide/svelte'
  import { api } from '../lib/api'
  import { refText, virtErrorText, virtRequestText } from '../lib/virt'
  import { untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { VirtChange, VirtHostView, VirtNetHost, VirtNetwork, VirtNetworkChanges } from '../types'

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
  <Card class="border-danger/40 bg-danger/5">
    <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
  </Card>
{/if}

{#each changes as c (c.node)}
  <Card class="space-y-2 border-warning/40 bg-warning/5">
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-sm text-fg-strong">{$LL.virtNetChanges({ node: c.node })}</span>
      <span class="ml-auto flex gap-1">
        <Button size="sm" disabled={busy} onclick={() => (confirm = { text: $LL.virtNetApplyConfirm({ node: c.node }), label: $LL.virtNetApply(), change: { op: 'network_apply', node: c.node } })}>
          {$LL.virtNetApply()}
        </Button>
        <Button variant="secondary" size="sm" disabled={busy} onclick={() => (confirm = { text: $LL.virtNetRevertConfirm({ node: c.node }), label: $LL.virtNetRevert(), change: { op: 'network_revert', node: c.node } })}>
          {$LL.virtNetRevert()}
        </Button>
      </span>
    </div>
    <div class="overflow-x-auto">
      <pre class="text-xs leading-5">{#each c.diff.split('\n') as line, i (i)}<span class={line.startsWith('+') && !line.startsWith('+++') ? 'text-success' : line.startsWith('-') && !line.startsWith('---') ? 'text-danger' : 'text-muted-fg'}>{line}</span>
{/each}</pre>
    </div>
  </Card>
{/each}

<Card class="space-y-2">
  <div class="flex items-center gap-2">
    {#if caps.network_edit}
      <Button size="sm" disabled={busy} onclick={openCreate}><Plus class="h-4 w-4" />{pve ? $LL.virtNetCreateBridge() : $LL.virtNetCreate()}</Button>
    {/if}
    <IconButton class="ml-auto" label={$LL.refresh()} disabled={loading} onclick={() => void load()}>
      <RefreshCw class="h-4 w-4" />
    </IconButton>
  </div>
  {#if networks === null}
    <Spinner class="h-5 w-5" />
  {:else if networks.length === 0}
    <p class="text-sm text-muted-fg">{$LL.virtNetNone()}</p>
  {:else}
    <ul class="divide-y divide-line">
      {#each networks as n (n.id)}
        <li class="space-y-1 py-2">
          <div class="flex flex-wrap items-center gap-2">
            <span class="h-2 w-2 shrink-0 rounded-full {n.active ? 'bg-success' : 'bg-faint-fg'}"></span>
            <span class="text-sm text-fg-strong">{n.name}</span>
            <span class="font-mono text-xs text-faint-fg">{n.mode}{n.node && view.host.nodes.length > 1 ? ` · ${n.node}` : ''}</span>
            {#if n.autostart}<Badge>{$LL.virtNetAutostart()}</Badge>{/if}
            {#if n.vlan_aware}<Badge>{$LL.virtNetVlanAware()}</Badge>{/if}
            {#if n.pending_restart}<Badge tone="warning">{$LL.virtNetPending()}</Badge>{/if}
            {#if pve && n.mode === 'bridge' && !n.management_editable}
              <span class="text-faint-fg" title={$LL.virtNetManagement()}><Lock class="h-3.5 w-3.5" /></span>
            {/if}
            {#if caps.network_edit}
              <span class="ml-auto flex flex-wrap gap-1">
                {#if pve}
                  {#if n.management_editable}
                    <Button variant="secondary" size="sm" disabled={busy} onclick={() => openBridge(n)}><Pencil class="h-4 w-4" />{$LL.virtEdit()}</Button>
                    <Button variant="secondary" size="sm" disabled={busy} onclick={() => (confirm = { text: $LL.virtNetDeleteConfirm({ name: n.name }), label: $LL.virtDelete(), change: { op: 'network_delete', network: n.id } })}>
                      <Trash2 class="h-4 w-4" />
                    </Button>
                  {/if}
                {:else}
                  {#if n.pending_restart && n.active}
                    <Button variant="secondary" size="sm" disabled={busy} onclick={() => (confirm = { text: $LL.virtNetRestartConfirm({ name: n.name }), label: $LL.virtNetRestart(), change: { op: 'network_restart', network: n.id, base_xml: n.xml || null } })}>
                      <RotateCcw class="h-4 w-4" />{$LL.virtNetRestart()}
                    </Button>
                  {/if}
                  <Button variant="secondary" size="sm" disabled={busy} onclick={() => void run({ op: 'network_set_active', network: n.id, active: !n.active })}>
                    {#if n.active}<Square class="h-4 w-4" />{$LL.virtNetStop()}{:else}<Play class="h-4 w-4" />{$LL.virtNetStart()}{/if}
                  </Button>
                  <label class="flex items-center gap-1.5 px-2 text-xs text-muted-fg">
                    <input type="checkbox" checked={n.autostart === true} disabled={busy} onchange={(e) => void run({ op: 'network_set_autostart', network: n.id, on: e.currentTarget.checked })} />
                    {$LL.virtNetAutostart()}
                  </label>
                  {#if caps.network_edit_existing}
                    <Button variant="secondary" size="sm" disabled={busy} onclick={() => openEdit(n)}><Pencil class="h-4 w-4" />{$LL.virtEdit()}</Button>
                  {/if}
                  <Button variant="secondary" size="sm" disabled={busy} onclick={() => (confirm = { text: $LL.virtNetDeleteConfirm({ name: n.name }), label: $LL.virtDelete(), change: { op: 'network_delete', network: n.id } })}>
                    <Trash2 class="h-4 w-4" />
                  </Button>
                {/if}
              </span>
            {/if}
          </div>
          <p class="pl-4 text-xs text-muted-fg">
            {[n.bridge && n.bridge !== n.name ? n.bridge : null, ...n.cidrs, n.gateway ? `via ${n.gateway}` : null, n.dhcp_ranges.length ? `DHCP ${n.dhcp_ranges.join(', ')}` : null, n.ports.length ? n.ports.join(' ') : null, n.bond_mode, n.comment]
              .filter(Boolean)
              .join(' · ')}
          </p>
          {#if n.users.length > 0}
            <p class="pl-4 text-xs text-faint-fg">{$LL.virtNetUsers()}: {n.users.map((u) => refText(u, view.guests) + (u.ip ? ` ${u.ip}` : '')).join(', ')}</p>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</Card>

{#if creating}
  <Modal open title={pve ? $LL.virtNetCreateBridge() : $LL.virtNetCreate()} onclose={() => (creating = false)}>
    <form class="space-y-3" onsubmit={create}>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtNetName()}</span>
        <Input class="font-mono" bind:value={createForm.name} placeholder={pve ? 'vmbr1' : 'lab'} />
      </label>
      {#if pve}
        {#if view.host.nodes.length > 1}
          <label class="block space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtNetNode()}</span>
            <Select bind:value={createForm.node}>
              {#each view.host.nodes as node (node.name)}
                <option value={node.name}>{node.name}</option>
              {/each}
            </Select>
          </label>
        {/if}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtNetPorts()}</span>
          <Input class="font-mono" bind:value={createForm.bridge} placeholder="eno2" />
        </label>
      {:else}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtNetMode()}</span>
          <Select bind:value={createForm.mode}>
            {#each modes as m (m)}
              <option value={m}>{m}</option>
            {/each}
          </Select>
        </label>
        {#if createForm.mode === 'bridge'}
          <label class="block space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtNetBridge()}</span>
            <Input class="font-mono" bind:value={createForm.bridge} placeholder="br0" />
          </label>
        {/if}
      {/if}
      {#if pve || createForm.mode !== 'bridge'}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtNetCidr()}</span>
          <Input class="font-mono" bind:value={createForm.cidr} placeholder="192.168.150.1/24" />
        </label>
      {/if}
      {#if !pve && createForm.mode !== 'bridge'}
        <div class="space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtNetDhcp()}</span>
          <div class="flex gap-2">
            <Input class="font-mono" bind:value={createForm.dhcpStart} placeholder="192.168.150.100" />
            <Input class="font-mono" bind:value={createForm.dhcpEnd} placeholder="192.168.150.200" />
          </div>
        </div>
      {/if}
      <div class="flex flex-wrap gap-4 text-sm text-muted-fg">
        {#if pve}
          <label class="flex items-center gap-1.5"><input type="checkbox" bind:checked={createForm.vlanAware} /> {$LL.virtNetVlanAware()}</label>
        {/if}
        <label class="flex items-center gap-1.5"><input type="checkbox" bind:checked={createForm.autostart} /> {$LL.virtNetAutostart()}</label>
      </div>
      {#if error}<p class="text-xs text-danger whitespace-pre-wrap">{error}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (creating = false)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy || createForm.name.trim() === ''}>{$LL.virtCreate()}</Button>
      </div>
    </form>
  </Modal>
{/if}

{#if editing}
  {@const n = editing}
  <Modal open title={`${$LL.virtEdit()} · ${n.name}`} onclose={() => (editing = null)}>
    <form class="space-y-3" onsubmit={saveEdit}>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtNetMode()}</span>
        <Select bind:value={editForm.mode}>
          {#each modes as m (m)}
            <option value={m}>{m}</option>
          {/each}
        </Select>
      </label>
      {#if editForm.mode === 'bridge'}
        <label class="block space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtNetBridge()}</span>
          <Input class="font-mono" bind:value={editForm.bridge} placeholder="br0" />
        </label>
      {:else}
        <div class="flex gap-2">
          <label class="block flex-1 space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtNetAddress()}</span>
            <Input class="font-mono" bind:value={editForm.address} placeholder="192.168.150.1" />
          </label>
          <label class="block w-24 space-y-1 text-sm">
            <span class="text-muted-fg">{$LL.virtNetPrefix()}</span>
            <Input class="font-mono" inputmode="numeric" bind:value={editForm.prefix} placeholder="24" />
          </label>
        </div>
        <div class="space-y-1 text-sm">
          <span class="text-muted-fg">{$LL.virtNetDhcp()}</span>
          <div class="flex gap-2">
            <Input class="font-mono" bind:value={editForm.dhcpStart} />
            <Input class="font-mono" bind:value={editForm.dhcpEnd} />
          </div>
        </div>
        <div class="space-y-1 text-sm">
          <div class="flex items-center gap-2">
            <span class="text-muted-fg">{$LL.virtNetHosts()}</span>
            <IconButton label={$LL.add()} onclick={() => (editForm.hosts = [...editForm.hosts, { mac: '', ip: '', name: null }])}>
              <Plus class="h-4 w-4" />
            </IconButton>
          </div>
          {#each editForm.hosts as h, i (i)}
            <div class="flex gap-2">
              <Input class="font-mono" bind:value={h.mac} placeholder={$LL.virtNetMac()} />
              <Input class="font-mono" bind:value={h.ip} placeholder={$LL.virtNetIp()} />
              <Input bind:value={() => h.name ?? '', (v) => (h.name = v)} placeholder={$LL.virtNetHostName()} />
              <IconButton label={$LL.virtDelete()} onclick={() => (editForm.hosts = editForm.hosts.filter((_, j) => j !== i))}>
                <X class="h-4 w-4" />
              </IconButton>
            </div>
          {/each}
        </div>
      {/if}
      {#if n.active}
        <label class="flex items-center gap-1.5 text-sm text-muted-fg"><input type="checkbox" bind:checked={editForm.restart} /> {$LL.virtNetRestartNow()}</label>
      {/if}
      {#if error}<p class="text-xs text-danger whitespace-pre-wrap">{error}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (editing = null)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy}>{$LL.save()}</Button>
      </div>
    </form>
  </Modal>
{/if}

{#if editingBridge}
  {@const n = editingBridge}
  <Modal open title={`${$LL.virtEdit()} · ${n.name}`} onclose={() => (editingBridge = null)}>
    <form class="space-y-3" onsubmit={saveBridge}>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtNetPorts()}</span>
        <Input class="font-mono" bind:value={bridgeForm.ports} placeholder="eno2" />
      </label>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtNetCidr()}</span>
        <Input class="font-mono" bind:value={bridgeForm.cidr} placeholder="10.20.0.1/24" />
      </label>
      <label class="block space-y-1 text-sm">
        <span class="text-muted-fg">{$LL.virtNetGateway()}</span>
        <Input class="font-mono" bind:value={bridgeForm.gateway} />
      </label>
      <div class="flex flex-wrap gap-4 text-sm text-muted-fg">
        <label class="flex items-center gap-1.5"><input type="checkbox" bind:checked={bridgeForm.vlanAware} /> {$LL.virtNetVlanAware()}</label>
        <label class="flex items-center gap-1.5"><input type="checkbox" bind:checked={bridgeForm.autostart} /> {$LL.virtNetAutostart()}</label>
      </div>
      {#if error}<p class="text-xs text-danger whitespace-pre-wrap">{error}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (editingBridge = null)}>{$LL.cancel()}</Button>
        <Button type="submit" disabled={busy}>{$LL.save()}</Button>
      </div>
    </form>
  </Modal>
{/if}

{#if confirm}
  {@const c = confirm}
  <Modal open title={$LL.virtSectionNetworks()} onclose={() => (confirm = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{c.text}</p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (confirm = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy} onclick={async () => { const change = c.change; confirm = null; await run(change) }}>{c.label}</Button>
      </div>
    </div>
  </Modal>
{/if}
