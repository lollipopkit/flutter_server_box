<script lang="ts">
  /// The machine's storage, as a NAS manages it (`/storage`): its disks with
  /// their partitions, filesystems, mounts and use; software RAID arrays;
  /// ZFS pools. Every change is asked about (`StorageConfirm`) and runs as
  /// root as a job, its log drawn here. Each disk's SMART health is read as
  /// root too: on its own where sudo needs no password, else when asked.

  import { AppToolbar, SplitView } from '../../sys'
  import { Badge, Button, Card, Checkbox, Dialog, Group, Icon, IconButton, Input, Row, Select, SidebarItem, SidebarSection, Spinner } from '../../lk'
  import StackProgress from '../../../components/stack/StackProgress.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import { fmtBytes, fmtEpochSeconds } from '../../../lib/format'
  import { servers } from '../../../lib/servers.svelte'
  import type { BlockDevice, DiskHealth, HealthReading, MdArray, StackJob, StorageAction, StorageView, ZPool } from '../../../types'
  import StorageConfirm from './StorageConfirm.svelte'
  import StorageMaintenance from './StorageMaintenance.svelte'
  import { arrayDevice, disksOf, expandable, freeDevices, growableArray, growablePartition, healthOf, isLuks, isMounted, minimum, mountable, nextMd, opened, overlaps, poolDeviceActions, shortName, verdict, volumesOf, type HealthVerdict } from './model'
  import { untrack } from 'svelte'

  type Tab = 'disks' | 'raid' | 'pools' | 'maintenance'

  let tab = $state<Tab>('disks')
  let view = $state<StorageView | null>(null)
  let error = $state('')
  let job = $state<StackJob | null>(null)
  /// The change being asked about.
  let pending = $state<{ action: StorageAction | 'readHealth'; title: string; body: string; confirmWord?: string; passphrase?: string } | null>(null)
  /// sudo wants a password to read SMART: it is read when asked, not on
  /// its own.
  let healthLocked = $state(false)
  let readingHealth = $state(false)
  /// Read on its own once per server the page is opened on.
  let healthTried = false
  /// The forms that gather a change before it is asked about.
  let formatFor = $state<BlockDevice | null>(null)
  let formatFs = $state<'ext4' | 'xfs' | 'btrfs'>('ext4')
  let formatLabel = $state('')
  let mountFor = $state<BlockDevice | null>(null)
  let mountPoint = $state('')
  let mountPersist = $state(true)
  let mountOwn = $state(true)
  /// A new array or pool, or a vdev more for pool [growPool].
  let creating = $state<'raid' | 'pool' | 'poolAdd' | null>(null)
  let growPool = $state('')
  let newName = $state('')
  let newLevel = $state<string>('1')
  let picked = $state<string[]>([])
  /// A free device being picked, and what is done with it.
  let picking = $state<{ title: string; message: string; then: (device: string) => void } | null>(null)
  let pickedDevice = $state('')
  let formatEncrypt = $state(false)
  /// A passphrase being asked for: a new container's (twice) or an unlock's.
  let passphraseFor = $state<{ title: string; twice: boolean; then: (passphrase: string) => void } | null>(null)
  let passphrase = $state('')
  let passphrase2 = $state('')
  /// The disk whose SMART details are open.
  let detailsOf = $state<{ disk: BlockDevice; health: DiskHealth } | null>(null)

  async function load(serverId = servers.currentId) {
    try {
      const next = await api.getStorage()
      if (serverId !== servers.currentId) return
      view = next
      error = ''
      if (next.job?.state === 'running') job = next.job
      if (!healthTried && next.tools.includes('smartctl') && stale(next.health)) {
        healthTried = true
        void readHealth(serverId)
      }
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => {
      healthTried = false
      healthLocked = false
      void load(serverId)
    })
  })

  /// No reading, or one older than ten minutes.
  function stale(health: HealthReading | null | undefined): boolean {
    return !health || Date.now() / 1000 - health.at > 600
  }

  /// SMART as root without a password; a refusal means sudo wants one.
  async function readHealth(serverId = servers.currentId) {
    readingHealth = true
    try {
      const reading = await api.storageHealth()
      if (serverId !== servers.currentId || !view) return
      view.health = reading
      healthLocked = false
    } catch (e) {
      if (serverId === servers.currentId && e instanceof ApiError && e.status === 403) healthLocked = true
    } finally {
      readingHealth = false
    }
  }

  function askHealth() {
    if (healthLocked) ask('readHealth', $LL.storageHealthRead(), $LL.storageHealthReadBody())
    else void readHealth()
  }

  // A self-test's progress, read again while one runs, where that needs no
  // password.
  const testing = $derived(!!view?.health?.disks.some((d) => d.testing != null))
  $effect(() => {
    if (!testing || healthLocked) return
    const timer = setInterval(() => void readHealth(), 30_000)
    return () => clearInterval(timer)
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

  function ask(action: StorageAction | 'readHealth', title: string, body: string, confirmWord?: string) {
    pending = { action, title, body, confirmWord }
  }

  function started(next: StackJob) {
    pending = null
    job = next
  }

  function healthBadge(v: HealthVerdict): { tone: 'success' | 'warning' | 'danger' | 'neutral'; text: string } {
    switch (v) {
      case 'healthy':
        return { tone: 'success', text: $LL.storageHealthy() }
      case 'wearing':
        return { tone: 'warning', text: $LL.storageHealthWearing() }
      case 'failing':
        return { tone: 'danger', text: $LL.storageHealthFailing() }
      case 'asleep':
        return { tone: 'neutral', text: $LL.storageHealthAsleep() }
      case 'unsupported':
        return { tone: 'neutral', text: $LL.storageHealthUnsupported() }
    }
  }

  function smartFacts(d: BlockDevice): string {
    const h = view && healthOf(view, d.path)
    if (!h) return ''
    return [
      h.testing != null ? $LL.storageTesting({ percent: h.testing }) : undefined,
      h.temperature != null ? $LL.storageTemperature({ value: h.temperature }) : undefined,
      h.power_on_hours != null ? $LL.storagePowerOn({ hours: h.power_on_hours }) : undefined,
      h.bad_sectors ? $LL.storageBadSectors({ count: h.bad_sectors }) : undefined,
    ]
      .filter(Boolean)
      .join(' · ')
  }

  function lastTest(d: BlockDevice): string | undefined {
    switch (view && healthOf(view, d.path)?.last_test?.outcome) {
      case 'passed':
        return $LL.storageLastTestPassed()
      case 'failed':
        return $LL.storageLastTestFailed()
      case 'aborted':
        return $LL.storageLastTestAborted()
      default:
        return undefined
    }
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
    formatEncrypt = false
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

  /// A vdev more for [p], laid out as its first one by default.
  function openPoolAdd(p: ZPool) {
    creating = 'poolAdd'
    growPool = p.name
    picked = []
    const first = p.vdevs.find((v) => v.depth === 1)?.name ?? ''
    newLevel = ['mirror', 'raidz1', 'raidz2', 'raidz3'].find((l) => first.startsWith(l)) ?? 'stripe'
  }

  function pick(title: string, message: string, then: (device: string) => void) {
    pickedDevice = free[0]?.path ?? ''
    picking = { title, message, then }
  }

  function openAdd(a: MdArray, grows: boolean) {
    pick(grows ? $LL.storageGrowRaid() : $LL.storageAddMember(), `/dev/${a.name}`, (device) => {
      if (grows) ask({ action: 'growRaid', array: a.name, device }, $LL.storageGrowRaid(), $LL.storageGrowRaidBody({ device, array: a.name }), device)
      else ask({ action: 'addToRaid', array: a.name, device }, $LL.storageAddMember(), $LL.storageAddMemberBody({ device, array: a.name }), device)
    })
  }

  function askPassphrase(title: string, twice: boolean, then: (passphrase: string) => void) {
    passphrase = ''
    passphrase2 = ''
    passphraseFor = { title, twice, then }
  }

  function unlock(v: BlockDevice) {
    askPassphrase($LL.storageUnlock(), false, (p) => {
      ask({ action: 'unlock', device: v.path }, $LL.storageUnlock(), $LL.storageUnlockBody({ device: v.path }))
      if (pending) pending.passphrase = p
    })
  }

  function replaceDevice(p: ZPool, device: string) {
    pick($LL.storageReplace(), device, (next) =>
      ask({ action: 'replaceInPool', name: p.name, old: device, new: next }, $LL.storageReplace(), $LL.storageReplaceBody({ old: device, name: p.name, new: next }), next),
    )
  }

  function attachDevice(p: ZPool, device: string) {
    pick($LL.storageAttach(), device, (next) =>
      ask({ action: 'attachToPool', name: p.name, existing: device, new: next }, $LL.storageAttach(), $LL.storageAttachBody({ existing: device, new: next }), next),
    )
  }

  function addSpare(p: ZPool) {
    pick($LL.storageAddSpare(), p.name, (device) =>
      ask({ action: 'addSpare', name: p.name, devices: [device] }, $LL.storageAddSpare(), $LL.storageAddSpareBody({ devices: device, name: p.name }), device),
    )
  }

  function testText(t: { long: boolean; outcome: string; hours: number | null }): string {
    const outcome = t.outcome === 'passed' ? $LL.storageTestPassed() : t.outcome === 'failed' ? $LL.storageTestFailed() : $LL.storageTestAborted()
    return [t.long ? $LL.storageTestLong() : $LL.storageTestShort(), outcome, t.hours != null ? $LL.storageAtHours({ hours: t.hours }) : undefined].filter(Boolean).join(' · ')
  }

  function toggle(path: string, on: boolean) {
    picked = on ? [...picked, path] : picked.filter((p) => p !== path)
  }

  function confirmCreate() {
    const devices = [...picked]
    const list = devices.join(', ')
    if (creating === 'poolAdd') {
      ask(
        { action: 'addToPool', name: growPool, layout: newLevel as 'mirror', devices },
        $LL.storageAddToPool(),
        $LL.storageAddToPoolBody({ name: growPool, layout: newLevel, devices: list }),
        growPool,
      )
    } else if (creating === 'raid') {
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

{#snippet volume(v: BlockDevice, label: string, disk?: BlockDevice)}
  {@const inside = isLuks(v) ? opened(v) : undefined}
  <Row
    {label}
    value={isLuks(v)
      ? [$LL.storageEncrypted(), inside ? undefined : $LL.storageLocked()].filter(Boolean).join(' · ')
      : [v.fstype, v.label, isMounted(v) ? v.mountpoints.join(', ') : undefined].filter(Boolean).join(' · ') || $LL.storageNoFilesystem()}
    sub={usage(v) ?? fmtBytes(v.size)}
  >
    <div class="flex shrink-0 gap-[5px]">
      {#if isLuks(v) && has('cryptsetup')}
        {#if inside}
          <Button size="sm" variant="secondary" icon="lock" disabled={job?.state === 'running'} onclick={() => ask({ action: 'lock', device: v.path }, $LL.storageLock(), $LL.storageLockBody({ device: v.path }))}>{$LL.storageLock()}</Button>
        {:else}
          <Button size="sm" variant="secondary" icon="lock_open" disabled={job?.state === 'running'} onclick={() => unlock(v)}>{$LL.storageUnlock()}</Button>
        {/if}
      {/if}
      {#if disk && growablePartition(disk, v) && has('sfdisk')}
        <Button size="sm" variant="secondary" icon="open_in_full" disabled={job?.state === 'running'} onclick={() => ask({ action: 'growPartition', device: v.path }, $LL.storageGrowPartition(), $LL.storageGrowPartitionBody({ device: v.path }))}>{$LL.storageGrowPartition()}</Button>
      {/if}
      {#if view?.busy[v.path] === 'systemPartition'}
        <Badge tone="neutral">{$LL.storageBusySystem()}</Badge>
      {:else if isMounted(v) && view?.system?.includes(v.path)}
        <Badge tone="neutral">{$LL.storageSystemDisk()}</Badge>
      {:else if isMounted(v)}
        <Button size="sm" variant="secondary" disabled={job?.state === 'running'} onclick={() => ask({ action: 'unmount', mountpoint: v.mountpoints[0] }, $LL.storageUnmount(), $LL.storageUnmountBody({ mountpoint: v.mountpoints[0] }))}>{$LL.storageUnmount()}</Button>
      {:else if mountable(v)}
        <Button size="sm" variant="secondary" disabled={job?.state === 'running'} onclick={() => openMount(v)}>{$LL.storageMount()}</Button>
      {/if}
      {#if expandable(v)}
        <Button size="sm" variant="secondary" icon="open_in_full" disabled={job?.state === 'running'} onclick={() => ask({ action: 'expandFilesystem', device: v.path }, $LL.storageExpand(), $LL.storageExpandBody({ device: v.path }))}>{$LL.storageExpand()}</Button>
      {/if}
      {#if view?.busy[v.path] === undefined}
        <Button size="sm" variant="ghost" disabled={job?.state === 'running'} onclick={() => openFormat(v)}>{$LL.storageFormat()}</Button>
      {/if}
    </div>
  </Row>
  {#if inside}{@render volume(inside, inside.path)}{/if}
{/snippet}

<AppToolbar title={tab === 'disks' ? $LL.storageDisks() : tab === 'raid' ? $LL.storageRaid() : tab === 'pools' ? $LL.storagePools() : $LL.storageMaintenance()}>
  {#snippet actions()}
    {#if tab === 'raid' && has('mdadm')}
      <Button size="sm" icon="add" disabled={job?.state === 'running'} onclick={() => openCreate('raid')}>{$LL.storageCreateRaid()}</Button>
    {:else if tab === 'pools' && has('zpool')}
      <Button size="sm" icon="add" disabled={job?.state === 'running'} onclick={() => openCreate('pool')}>{$LL.storageCreatePool()}</Button>
    {:else if tab === 'disks' && has('smartctl')}
      <Button size="sm" variant="secondary" icon="health_and_safety" disabled={readingHealth} onclick={askHealth}>{$LL.storageHealthRead()}</Button>
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
      <SidebarItem label={$LL.storageMaintenance()} icon="event_repeat" active={tab === 'maintenance'} onclick={() => (tab = 'maintenance')} />
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
        {@const health = healthOf(view, d.path)}
        {@const badge = health && healthBadge(verdict(health))}
        <Group title={`${diskTitle(d)} · ${fmtBytes(d.size)}`}>
          <Row label={d.path} value={[kindText(d), d.transport?.toUpperCase(), d.serial].filter(Boolean).join(' · ')} mono>
            <div class="flex shrink-0 gap-[5px]">
              {#if why}<Badge tone="neutral">{why}</Badge>{/if}
              {#if badge}<Badge tone={badge.tone}>{badge.text}</Badge>{/if}
            </div>
          </Row>
          {#if health?.supported}
            <Row label={$LL.storageSmart()} value={smartFacts(d)} sub={[lastTest(d), view.health ? $LL.storageHealthAt({ time: fmtEpochSeconds(view.health.at) }) : undefined].filter(Boolean).join(' · ')} />
          {/if}
          {#each volumesOf(d) as v (v.path)}
            {@render volume(v, v.path === d.path ? $LL.storageWholeDisk() : v.path, d)}
          {/each}
          <div class="flex justify-end gap-[7px] px-[13px] py-[9px]">
            {#if health?.supported}
              <Button size="sm" variant="ghost" icon="monitor_heart" onclick={() => (detailsOf = { disk: d, health })}>{$LL.storageDetails()}</Button>
              <Button size="sm" variant="ghost" icon="health_and_safety" disabled={job?.state === 'running' || health.testing != null} onclick={() => ask({ action: 'smartTest', device: d.path, long: false }, $LL.storageSmartTest(), $LL.storageSmartTestBody({ device: d.path }))}>{$LL.storageSmartTest()}</Button>
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
          {@const md = arrayDevice(view, a.name)}
          {#if md}{@render volume(md, md.path)}{/if}
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
            {#if growableArray(a.level)}
              <Button size="sm" variant="secondary" icon="open_in_full" disabled={job?.state === 'running' || free.length === 0} onclick={() => openAdd(a, true)}>{$LL.storageGrowRaid()}</Button>
            {/if}
            <Button size="sm" variant="secondary" icon="add" disabled={job?.state === 'running' || free.length === 0} onclick={() => openAdd(a, false)}>{$LL.storageAddMember()}</Button>
          </div>
        </Group>
      {:else}
        <div class="flex flex-col items-center gap-[9px] py-[55px] text-(--text-tertiary)"><Icon name="stacks" size={48} /><p>{$LL.storageNoArrays()}</p></div>
      {/each}
    {:else if tab === 'maintenance'}
      <StorageMaintenance {view} onchange={(tasks) => view && (view.maintenance = tasks)} />
    {:else}
      {#if !has('zpool')}<Card><p class="text-[13px] text-(--text-secondary)">{$LL.storageNoZfs()}</p></Card>{/if}
      {#each view.pools as p (p.name)}
        <Group title={`${p.name} · ${fmtBytes(p.size)}`}>
          <Row label={$LL.storageState()} value={$LL.storageUsage({ used: fmtBytes(p.allocated), total: fmtBytes(p.size) })}>
            <Badge tone={poolTone(p)}>{p.health}</Badge>
          </Row>
          {#if p.scan}<Row label={$LL.storageScan()} value={p.scan} />{/if}
          {#each p.vdevs as v, i (`${v.name}-${i}`)}
            {@const can = poolDeviceActions(p, i)}
            <Row label={`${'  '.repeat(v.depth + (v.section ? 1 : 0))}${v.name}`} sub={v.section ?? undefined} value={v.errors ? $LL.storageErrors({ count: v.errors }) : v.state} mono>
              <div class="flex shrink-0 gap-[5px]">
                {#if can.online}
                  <Button size="sm" variant="secondary" disabled={job?.state === 'running'} onclick={() => ask({ action: 'onlineInPool', name: p.name, device: v.name }, $LL.storageOnline(), $LL.storageOnlineBody({ device: v.name, name: p.name }))}>{$LL.storageOnline()}</Button>
                {/if}
                {#if can.replace}
                  <Button size="sm" variant="ghost" disabled={job?.state === 'running' || free.length === 0} onclick={() => replaceDevice(p, v.name)}>{$LL.storageReplace()}</Button>
                {/if}
                {#if can.attach}
                  <Button size="sm" variant="ghost" disabled={job?.state === 'running' || free.length === 0} onclick={() => attachDevice(p, v.name)}>{$LL.storageAttach()}</Button>
                {/if}
                {#if can.remove}
                  <Button size="sm" variant="ghost" disabled={job?.state === 'running'} onclick={() => ask({ action: 'removeFromPool', name: p.name, device: v.name }, $LL.storageRemoveDevice(), $LL.storageRemoveDeviceBody({ device: v.name, name: p.name }))}>{$LL.storageRemoveDevice()}</Button>
                {/if}
              </div>
            </Row>
          {/each}
          <div class="flex justify-end gap-[7px] px-[13px] py-[9px]">
            <Button size="sm" variant="ghost" disabled={job?.state === 'running'} onclick={() => ask({ action: 'destroyPool', name: p.name }, $LL.storageDestroyPool(), $LL.storageDestroyPoolBody({ name: p.name }), p.name)}>{$LL.storageDestroyPool()}</Button>
            <Button size="sm" variant="secondary" disabled={job?.state === 'running' || free.length === 0} onclick={() => addSpare(p)}>{$LL.storageAddSpare()}</Button>
            <Button size="sm" variant="secondary" icon="add" disabled={job?.state === 'running' || free.length === 0} onclick={() => openPoolAdd(p)}>{$LL.storageAddToPool()}</Button>
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
      {#if has('cryptsetup')}<Checkbox bind:checked={formatEncrypt} label={$LL.storageEncrypt()} />{/if}
    </div>
    {#snippet actions()}
      <Button variant="destructive" block onclick={() => {
        const d = formatFor!
        formatFor = null
        const action: StorageAction = { action: 'format', device: d.path, fstype: formatFs, label: formatLabel.trim() || null, ...(formatEncrypt ? { encrypt: true } : {}) }
        if (!formatEncrypt) ask(action, $LL.storageFormat(), $LL.storageFormatBody({ device: d.path }), d.path)
        else
          askPassphrase($LL.storageEncrypt(), true, (p) => {
            ask(action, $LL.storageFormat(), $LL.storageFormatBody({ device: d.path }), d.path)
            if (pending) pending.passphrase = p
          })
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
  <Dialog open wide title={creating === 'raid' ? $LL.storageCreateRaid() : creating === 'pool' ? $LL.storageCreatePool() : $LL.storageAddToPool()} message={creating === 'poolAdd' ? growPool : undefined} onclose={() => (creating = null)}>
    <div class="space-y-[9px] text-left">
      {#if creating !== 'poolAdd'}
        <Input label={$LL.storageName()} mono value={newName} oninput={(e: Event) => (newName = (e.currentTarget as HTMLInputElement).value)} />
      {/if}
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
      <Button variant="destructive" block disabled={picked.length < minimum(creating === 'raid' ? Number(newLevel) : newLevel) || (creating !== 'poolAdd' && !newName.trim())} onclick={confirmCreate}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (creating = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if picking}
  <Dialog open title={picking.title} message={picking.message} onclose={() => (picking = null)}>
    <Select
      label={$LL.storageDevice()}
      value={pickedDevice}
      options={free.map((d) => ({ value: d.path, label: `${d.path} · ${fmtBytes(d.size)}` }))}
      onchange={(e: Event) => (pickedDevice = (e.currentTarget as HTMLSelectElement).value)}
    />
    {#snippet actions()}
      <Button block disabled={!pickedDevice} onclick={() => {
        const p = picking!
        picking = null
        p.then(pickedDevice)
      }}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (picking = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if passphraseFor}
  <Dialog open title={passphraseFor.title} onclose={() => (passphraseFor = null)}>
    <div class="space-y-[9px] text-left">
      <Input label={$LL.storagePassphrase()} type="password" value={passphrase} hint={passphraseFor.twice ? $LL.storagePassphraseHint() : undefined} oninput={(e: Event) => (passphrase = (e.currentTarget as HTMLInputElement).value)} />
      {#if passphraseFor.twice}
        <Input
          label={$LL.storagePassphraseAgain()}
          type="password"
          value={passphrase2}
          error={passphrase2 && passphrase2 !== passphrase ? $LL.storagePassphrasesDiffer() : undefined}
          oninput={(e: Event) => (passphrase2 = (e.currentTarget as HTMLInputElement).value)}
        />
      {/if}
    </div>
    {#snippet actions()}
      <Button block disabled={passphrase.length < 8 || (passphraseFor!.twice && passphrase !== passphrase2)} onclick={() => {
        const p = passphraseFor!
        const value = passphrase
        passphraseFor = null
        passphrase = ''
        passphrase2 = ''
        p.then(value)
      }}>{$LL.storageContinue()}</Button>
      <Button variant="secondary" block onclick={() => (passphraseFor = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if detailsOf}
  {@const h = detailsOf.health}
  <Dialog open wide title={`${diskTitle(detailsOf.disk)} · ${$LL.storageDetails()}`} message={detailsOf.disk.path} onclose={() => (detailsOf = null)}>
    <div class="space-y-[13px] text-left">
      <Group title={$LL.storageAttributes()}>
        {#each h.attributes ?? [] as a (a.name)}
          <Row
            label={a.id != null ? `${a.id} ${a.name}` : a.name}
            sub={a.value != null ? `${$LL.storageAttrValue()} ${a.value} · ${$LL.storageAttrWorst()} ${a.worst ?? '–'} · ${$LL.storageAttrThresh()} ${a.thresh ?? '–'}` : undefined}
            value={a.raw}
            mono
          >
            {#if a.failing}<Badge tone="danger">{$LL.storageHealthFailing()}</Badge>{/if}
          </Row>
        {:else}
          <Row label={$LL.storageNothingToShow()} />
        {/each}
      </Group>
      <Group title={$LL.storageSelfTests()}>
        {#each h.tests ?? [] as t, i (i)}
          <Row label={testText(t)}>
            {#if t.outcome === 'failed'}<Badge tone="danger">{$LL.storageTestFailed()}</Badge>{/if}
          </Row>
        {:else}
          <Row label={$LL.storageNothingToShow()} />
        {/each}
      </Group>
    </div>
    {#snippet actions()}
      <Button block variant="secondary" disabled={job?.state === 'running' || h.testing != null} onclick={() => {
        const d = detailsOf!.disk
        detailsOf = null
        ask({ action: 'smartTest', device: d.path, long: true }, $LL.storageLongTest(), $LL.storageSmartLongTestBody({ device: d.path }))
      }}>{$LL.storageLongTest()}</Button>
      <Button variant="secondary" block onclick={() => (detailsOf = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

<StorageConfirm
  action={pending?.action ?? null}
  title={pending?.title ?? ''}
  body={pending?.body ?? ''}
  confirmWord={pending?.confirmWord}
  passphrase={pending?.passphrase}
  onstarted={started}
  onhealth={(reading) => {
    pending = null
    healthLocked = false
    if (view) view.health = reading
  }}
  onclose={() => (pending = null)}
/>
