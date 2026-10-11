<script lang="ts">
  /// The machine's storage, as a NAS manages it (`/storage`): its disks with
  /// their partitions, filesystems, mounts and use; software RAID arrays;
  /// ZFS pools. Every change is asked about (`StorageConfirm`) and runs as
  /// root as a job, its log drawn here.

  import { AppToolbar, SplitView } from '../../sys'
  import { Badge, Button, Card, Checkbox, Dialog, Group, Icon, IconButton, Input, Row, Select, SidebarItem, SidebarSection, Spinner } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { fmtBytes } from '../../../lib/format'
  import { servers } from '../../../lib/servers.svelte'
  import type { BlockDevice, MdArray, StackJob, StorageAction, StorageView, ZPool } from '../../../types'
  import StorageConfirm from './StorageConfirm.svelte'
  import { disksOf, freeDevices, isMounted, minimum, mountable, nextMd, overlaps, shortName, volumesOf } from './model'
  import { untrack } from 'svelte'

  type Tab = 'disks' | 'raid' | 'pools'

  let tab = $state<Tab>('disks')
  let view = $state<StorageView | null>(null)
  let error = $state('')
  let job = $state<StackJob | null>(null)
  /// The change being asked about.
  let pending = $state<{ action: StorageAction; title: string; body: string; confirmWord?: string } | null>(null)
  /// The forms that gather a change before it is asked about.
  let formatFor = $state<BlockDevice | null>(null)
  let formatFs = $state<'ext4' | 'xfs' | 'btrfs'>('ext4')
  let formatLabel = $state('')
  let mountFor = $state<BlockDevice | null>(null)
  let mountPoint = $state('')
  let mountPersist = $state(true)
  let mountOwn = $state(true)
  let creating = $state<'raid' | 'pool' | null>(null)
  let newName = $state('')
  let newLevel = $state<string>('1')
  let picked = $state<string[]>([])
  let addTo = $state<MdArray | null>(null)
  let addDevice = $state('')

  async function load(serverId = servers.currentId) {
    try {
      const next = await api.getStorage()
      if (serverId !== servers.currentId) return
      view = next
      error = ''
      if (next.job?.state === 'running') job = next.job
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  // An array syncing or a pool scrubbing is read again every few seconds
  // while the page is open, so its progress moves.
  const syncing = $derived(!!view && (view.arrays.some((a) => a.sync) || view.pools.some((p) => p.scan?.includes('in progress'))))
  $effect(() => {
    if (!syncing) return
    const timer = setInterval(() => void load(), 3000)
    return () => clearInterval(timer)
  })

  const has = (tool: string) => view?.tools.includes(tool) === true
  const disks = $derived(view ? disksOf(view) : [])
  const free = $derived(view ? freeDevices(view) : [])

  function ask(action: StorageAction, title: string, body: string, confirmWord?: string) {
    pending = { action, title, body, confirmWord }
  }

  function started(next: StackJob) {
    pending = null
    job = next
  }

  function diskTitle(d: BlockDevice): string {
    return d.model ?? d.name
  }

  function kindText(d: BlockDevice): string {
    if (d.transport === 'nvme') return 'NVMe'
    return d.rotational ? 'HDD' : 'SSD'
  }

  function usage(d: BlockDevice): string | undefined {
    if (d.used == null || d.available == null) return undefined
    return $LL.storageUsage({ used: fmtBytes(d.used), total: fmtBytes(d.used + d.available) })
  }

  function busyText(d: BlockDevice): string | undefined {
    const why = view?.busy[d.path]
    switch (why) {
      case 'mounted':
        return $LL.storageBusyMounted()
      case 'swap':
        return $LL.storageBusySwap()
      case 'raidMember':
        return $LL.storageBusyRaid()
      case 'poolMember':
        return $LL.storageBusyPool()
      case 'lvmMember':
      case 'holdsVolume':
        return $LL.storageBusyVolume()
      case 'readOnly':
        return $LL.storageBusyReadOnly()
      case 'systemPartition':
        return $LL.storageBusySystem()
      default:
        return undefined
    }
  }

  function openFormat(d: BlockDevice) {
    formatFor = d
    formatFs = has('mkfs.ext4') ? 'ext4' : has('mkfs.xfs') ? 'xfs' : 'btrfs'
    formatLabel = ''
  }

  function openMount(d: BlockDevice) {
    mountFor = d
    mountPoint = `/mnt/${(d.label ?? d.name).replace(/[^A-Za-z0-9_.-]/g, '-')}`
    mountPersist = true
    mountOwn = true
  }

  function openCreate(what: 'raid' | 'pool') {
    creating = what
    picked = []
    newName = what === 'raid' && view ? nextMd(view) : 'tank'
    newLevel = what === 'raid' ? '1' : 'mirror'
  }

  function toggle(path: string, on: boolean) {
    picked = on ? [...picked, path] : picked.filter((p) => p !== path)
  }

  function confirmCreate() {
    const devices = [...picked]
    const list = devices.join(', ')
    if (creating === 'raid') {
      ask(
        { action: 'createRaid', name: newName, level: Number(newLevel), devices },
        $LL.storageCreateRaid(),
        $LL.storageCreateRaidBody({ name: newName, level: newLevel, devices: list }),
        newName,
      )
    } else {
      ask(
        { action: 'createPool', name: newName, layout: newLevel as 'mirror', devices },
        $LL.storageCreatePool(),
        $LL.storageCreatePoolBody({ name: newName, layout: newLevel, devices: list }),
        newName,
      )
    }
    creating = null
  }

  function memberPath(m: { name: string }): string {
    return `/dev/${m.name}`
  }

  function poolTone(p: ZPool): 'success' | 'warning' | 'danger' {
    return p.health === 'ONLINE' ? 'success' : p.health === 'DEGRADED' ? 'warning' : 'danger'
  }
</script>

<AppToolbar title={tab === 'disks' ? $LL.storageDisks() : tab === 'raid' ? $LL.storageRaid() : $LL.storagePools()}>
  {#snippet actions()}
    {#if tab === 'raid' && has('mdadm')}
      <Button size="sm" icon="add" disabled={job?.state === 'running'} onclick={() => openCreate('raid')}>{$LL.storageCreateRaid()}</Button>
    {:else if tab === 'pools' && has('zpool')}
      <Button size="sm" icon="add" disabled={job?.state === 'running'} onclick={() => openCreate('pool')}>{$LL.storageCreatePool()}</Button>
    {/if}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} />
  {/snippet}
</AppToolbar>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection>
      <SidebarItem label={$LL.storageDisks()} icon="hard_drive" active={tab === 'disks'} trailing={disks.length || undefined} onclick={() => (tab = 'disks')} />
      <SidebarItem label={$LL.storageRaid()} icon="stacks" active={tab === 'raid'} trailing={view?.arrays.length || undefined} onclick={() => (tab = 'raid')} />
      <SidebarItem label={$LL.storagePools()} icon="database" active={tab === 'pools'} trailing={view?.pools.length || undefined} onclick={() => (tab = 'pools')} />
    </SidebarSection>
  {/snippet}

  <div class="space-y-[13px] px-(--content-pad) pb-[21px]">
    {#if error}
      <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)"><Icon name="error" size={17} /><p>{error}</p></Card>
    {/if}
    {#if job}
      {#key job.id}
        <StackProgress
          {job}
          title={job.state === 'running' ? $LL.storageWorking() : job.state === 'succeeded' ? $LL.storageDone() : $LL.storageFailed()}
          read={(since) => api.storageJob(since)}
          stop={null}
          ondone={(done) => {
            job = done
            void load()
          }}
        />
      {/key}
    {/if}

    {#if !view}
      {#if !error}<div class="flex justify-center py-12"><Spinner /></div>{/if}
    {:else if tab === 'disks'}
      {#each disks as d (d.path)}
        {@const why = busyText(d)}
        <Group title={`${diskTitle(d)} · ${fmtBytes(d.size)}`}>
          <Row label={d.path} value={[kindText(d), d.transport?.toUpperCase(), d.serial].filter(Boolean).join(' · ')} mono>
            {#if why}<Badge tone="neutral">{why}</Badge>{/if}
          </Row>
          {#each volumesOf(d) as v (v.path)}
            <Row
              label={v.path === d.path ? $LL.storageWholeDisk() : v.path}
              value={[v.fstype, v.label, isMounted(v) ? v.mountpoints.join(', ') : undefined].filter(Boolean).join(' · ') || $LL.storageNoFilesystem()}
              sub={usage(v) ?? fmtBytes(v.size)}
            >
              <div class="flex shrink-0 gap-[5px]">
                {#if view.busy[v.path] === 'systemPartition'}
                  <Badge tone="neutral">{$LL.storageBusySystem()}</Badge>
                {:else if isMounted(v) && view.system?.includes(v.path)}
                  <Badge tone="neutral">{$LL.storageSystemDisk()}</Badge>
                {:else if isMounted(v)}
                  <Button size="sm" variant="secondary" disabled={job?.state === 'running'} onclick={() => ask({ action: 'unmount', mountpoint: v.mountpoints[0] }, $LL.storageUnmount(), $LL.storageUnmountBody({ mountpoint: v.mountpoints[0] }))}>{$LL.storageUnmount()}</Button>
                {:else if mountable(v)}
                  <Button size="sm" variant="secondary" disabled={job?.state === 'running'} onclick={() => openMount(v)}>{$LL.storageMount()}</Button>
                {/if}
                {#if view.busy[v.path] === undefined}
                  <Button size="sm" variant="ghost" disabled={job?.state === 'running'} onclick={() => openFormat(v)}>{$LL.storageFormat()}</Button>
                {/if}
              </div>
            </Row>
          {/each}
          <div class="flex justify-end gap-[7px] px-[13px] py-[9px]">
            {#if has('smartctl') && d.kind === 'disk'}
              <Button size="sm" variant="ghost" icon="health_and_safety" disabled={job?.state === 'running'} onclick={() => ask({ action: 'smartTest', device: d.path, long: false }, $LL.storageSmartTest(), $LL.storageSmartTestBody({ device: d.path }))}>{$LL.storageSmartTest()}</Button>
            {/if}
            {#if !why && has('sfdisk')}
              <Button size="sm" variant="secondary" icon="layers_clear" disabled={job?.state === 'running'} onclick={() => ask({ action: 'partition', device: d.path }, $LL.storageInitialize(), $LL.storageInitializeBody({ device: d.path }), d.path)}>{$LL.storageInitialize()}</Button>
            {/if}
          </div>
        </Group>
      {:else}
        <div class="flex flex-col items-center gap-[9px] py-[55px] text-(--text-tertiary)"><Icon name="hard_drive" size={48} /><p>{$LL.storageNoDisks()}</p></div>
      {/each}
    {:else if tab === 'raid'}
      {#if !has('mdadm')}<Card><p class="text-[13px] text-(--text-secondary)">{$LL.storageNoMdadm()}</p></Card>{/if}
      {#each view.arrays as a (a.name)}
        {@const degraded = a.raid_disks != null && a.working_disks != null && a.working_disks < a.raid_disks}
        <Group title={`/dev/${a.name} · ${a.level ?? a.state}`}>
          <Row label={$LL.storageState()} value={a.state}>
            <Badge tone={a.state !== 'active' ? 'neutral' : degraded ? 'danger' : 'success'}>{a.state !== 'active' ? a.state : degraded ? $LL.storageDegraded() : $LL.storageHealthy()}</Badge>
          </Row>
          {#if a.sync}
            <Row label={$LL.storageSync({ action: a.sync.action })} value={`${(a.sync.permille / 10).toFixed(1)}%${a.sync.finish ? ` · ${a.sync.finish}` : ''}`} />
          {/if}
          {#each a.members as m (m.name)}
            <Row label={memberPath(m)} value={m.faulty ? $LL.storageFaulty() : m.spare ? $LL.storageSpare() : $LL.storageActive()} mono>
              <Button size="sm" variant="ghost" disabled={job?.state === 'running'} onclick={() => ask({ action: 'removeFromRaid', array: a.name, device: memberPath(m) }, $LL.storageRemoveMember(), $LL.storageRemoveMemberBody({ device: memberPath(m), array: a.name }), shortName(memberPath(m)))}>{$LL.storageRemoveMember()}</Button>
            </Row>
          {/each}
          <div class="flex justify-end gap-[7px] px-[13px] py-[9px]">
            <Button size="sm" variant="ghost" disabled={job?.state === 'running'} onclick={() => ask({ action: 'deleteRaid', array: a.name }, $LL.storageDeleteRaid(), $LL.storageDeleteRaidBody({ array: a.name }), a.name)}>{$LL.storageDeleteRaid()}</Button>
            <Button size="sm" variant="secondary" icon="add" disabled={job?.state === 'running' || free.length === 0} onclick={() => {
              addTo = a
              addDevice = free[0]?.path ?? ''
            }}>{$LL.storageAddMember()}</Button>
          </div>
        </Group>
      {:else}
        <div class="flex flex-col items-center gap-[9px] py-[55px] text-(--text-tertiary)"><Icon name="stacks" size={48} /><p>{$LL.storageNoArrays()}</p></div>
      {/each}
    {:else}
      {#if !has('zpool')}<Card><p class="text-[13px] text-(--text-secondary)">{$LL.storageNoZfs()}</p></Card>{/if}
      {#each view.pools as p (p.name)}
        <Group title={`${p.name} · ${fmtBytes(p.size)}`}>
          <Row label={$LL.storageState()} value={$LL.storageUsage({ used: fmtBytes(p.allocated), total: fmtBytes(p.size) })}>
            <Badge tone={poolTone(p)}>{p.health}</Badge>
          </Row>
          {#if p.scan}<Row label={$LL.storageScan()} value={p.scan} />{/if}
          {#each p.vdevs as v, i (`${v.name}-${i}`)}
            <Row label={`${'  '.repeat(v.depth)}${v.name}`} value={v.errors ? $LL.storageErrors({ count: v.errors }) : v.state} mono />
          {/each}
          <div class="flex justify-end gap-[7px] px-[13px] py-[9px]">
            <Button size="sm" variant="ghost" disabled={job?.state === 'running'} onclick={() => ask({ action: 'destroyPool', name: p.name }, $LL.storageDestroyPool(), $LL.storageDestroyPoolBody({ name: p.name }), p.name)}>{$LL.storageDestroyPool()}</Button>
            <Button size="sm" variant="secondary" icon="cleaning_services" disabled={job?.state === 'running'} onclick={() => ask({ action: 'scrubPool', name: p.name }, $LL.storageScrub(), $LL.storageScrubBody({ name: p.name }))}>{$LL.storageScrub()}</Button>
          </div>
        </Group>
      {:else}
        <div class="flex flex-col items-center gap-[9px] py-[55px] text-(--text-tertiary)"><Icon name="database" size={48} /><p>{$LL.storageNoPools()}</p></div>
      {/each}
    {/if}
  </div>
</SplitView>

{#if formatFor}
  <Dialog open title={$LL.storageFormat()} message={$LL.storageFormatBody({ device: formatFor.path })} onclose={() => (formatFor = null)}>
    <div class="space-y-[9px] text-left">
      <Select
        label={$LL.storageFilesystem()}
        value={formatFs}
        options={(['ext4', 'xfs', 'btrfs'] as const).filter((f) => has(`mkfs.${f}`)).map((f) => ({ value: f, label: f }))}
        onchange={(e: Event) => (formatFs = (e.currentTarget as HTMLSelectElement).value as 'ext4')}
      />
      <Input label={$LL.storageLabel()} value={formatLabel} oninput={(e: Event) => (formatLabel = (e.currentTarget as HTMLInputElement).value)} />
    </div>
    {#snippet actions()}
      <Button variant="destructive" block onclick={() => {
        const d = formatFor!
        formatFor = null
        ask({ action: 'format', device: d.path, fstype: formatFs, label: formatLabel.trim() || null }, $LL.storageFormat(), $LL.storageFormatBody({ device: d.path }), d.path)
      }}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (formatFor = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if mountFor}
  <Dialog open title={$LL.storageMount()} message={mountFor.path} onclose={() => (mountFor = null)}>
    <div class="space-y-[9px] text-left">
      <Input label={$LL.storageMountpoint()} mono value={mountPoint} oninput={(e: Event) => (mountPoint = (e.currentTarget as HTMLInputElement).value)} />
      <Checkbox bind:checked={mountPersist} label={$LL.storageMountPersist()} />
      <Checkbox bind:checked={mountOwn} label={$LL.storageMountOwn()} />
    </div>
    {#snippet actions()}
      <Button block onclick={() => {
        const d = mountFor!
        mountFor = null
        ask({ action: 'mount', device: d.path, mountpoint: mountPoint.trim(), persist: mountPersist, own: mountOwn }, $LL.storageMount(), $LL.storageMountBody({ device: d.path, mountpoint: mountPoint.trim() }))
      }}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (mountFor = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if creating}
  <Dialog open wide title={creating === 'raid' ? $LL.storageCreateRaid() : $LL.storageCreatePool()} onclose={() => (creating = null)}>
    <div class="space-y-[9px] text-left">
      <Input label={$LL.storageName()} mono value={newName} oninput={(e: Event) => (newName = (e.currentTarget as HTMLInputElement).value)} />
      <Select
        label={creating === 'raid' ? $LL.storageLevel() : $LL.storageLayout()}
        value={newLevel}
        options={creating === 'raid'
          ? ['0', '1', '5', '6', '10'].map((l) => ({ value: l, label: `RAID ${l}` }))
          : ['mirror', 'raidz1', 'raidz2', 'raidz3', 'stripe'].map((l) => ({ value: l, label: l }))}
        onchange={(e: Event) => (newLevel = (e.currentTarget as HTMLSelectElement).value)}
      />
      <p class="text-[12px] text-(--text-tertiary)">{$LL.storagePickDevices({ count: minimum(creating === 'raid' ? Number(newLevel) : newLevel) })}</p>
      {#each free as d (d.path)}
        <Checkbox
          checked={picked.includes(d.path)}
          disabled={!picked.includes(d.path) && picked.some((p) => overlaps(view!, p, d.path))}
          label={`${d.path} · ${fmtBytes(d.size)}${d.model ? ` · ${d.model}` : ''}`} onchange={(e: Event) => toggle(d.path, (e.currentTarget as HTMLInputElement).checked)} />
      {:else}
        <p class="text-[13px] text-(--text-secondary)">{$LL.storageNoFreeDevices()}</p>
      {/each}
    </div>
    {#snippet actions()}
      <Button variant="destructive" block disabled={picked.length < minimum(creating === 'raid' ? Number(newLevel) : newLevel) || !newName.trim()} onclick={confirmCreate}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (creating = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if addTo}
  <Dialog open title={$LL.storageAddMember()} message={`/dev/${addTo.name}`} onclose={() => (addTo = null)}>
    <Select
      label={$LL.storageDevice()}
      value={addDevice}
      options={free.map((d) => ({ value: d.path, label: `${d.path} · ${fmtBytes(d.size)}` }))}
      onchange={(e: Event) => (addDevice = (e.currentTarget as HTMLSelectElement).value)}
    />
    {#snippet actions()}
      <Button block disabled={!addDevice} onclick={() => {
        const a = addTo!
        addTo = null
        ask({ action: 'addToRaid', array: a.name, device: addDevice }, $LL.storageAddMember(), $LL.storageAddMemberBody({ device: addDevice, array: a.name }), addDevice)
      }}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (addTo = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

<StorageConfirm
  action={pending?.action ?? null}
  title={pending?.title ?? ''}
  body={pending?.body ?? ''}
  confirmWord={pending?.confirmWord}
  onstarted={started}
  onclose={() => (pending = null)}
/>
