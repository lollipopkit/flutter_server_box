<script lang="ts">
  /// The maintenance schedule (`storage_watch`): pools scrubbed and arrays
  /// checked, SMART self-tests, each weekly or monthly. It runs without a
  /// password, so it says what sudo must allow when the agent is not root.

  import { Button, Card, Group, Input, Row, Select } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import { DATE_TIME, fmtDate, parseTimestamp } from '../../../lib/format'
  import type { MaintenanceKind, MaintenanceTask, StorageView } from '../../../types'

  interface Props {
    view: StorageView
    onchange: (tasks: MaintenanceTask[]) => void
  }

  const { view, onchange }: Props = $props()

  const KINDS: MaintenanceKind[] = ['scrub', 'smartShort', 'smartLong']
  let busy = $state<MaintenanceKind | null>(null)
  let error = $state('')

  const taskOf = (kind: MaintenanceKind) => view.maintenance?.find((t) => t.task === kind)
  const has = (tool: string) => view.tools.includes(tool)
  const usable = (kind: MaintenanceKind) => (kind === 'scrub' ? has('zpool') || has('mdadm') : has('smartctl'))
  // 2024-01-01 was a Monday.
  const weekdays = Array.from({ length: 7 }, (_, i) => ({ value: i, label: fmtDate(new Date(2024, 0, 1 + i), { weekday: 'long' }) }))
  const monthDays = Array.from({ length: 28 }, (_, i) => ({ value: i + 1, label: String(i + 1) }))

  function title(kind: MaintenanceKind): string {
    return kind === 'scrub' ? $LL.storageTaskScrub() : kind === 'smartShort' ? $LL.storageTaskSmartShort() : $LL.storageTaskSmartLong()
  }

  function about(kind: MaintenanceKind): string {
    return kind === 'scrub' ? $LL.storageTaskScrubBody() : kind === 'smartShort' ? $LL.storageTaskSmartShortBody() : $LL.storageTaskSmartLongBody()
  }

  function failure(e: string): string {
    return e === 'sudoNeedsPassword' ? $LL.storageNeedsSudo() : e
  }

  async function save(kind: MaintenanceKind, every: 'weekly' | 'monthly' | null, at: string, day: number) {
    busy = kind
    error = ''
    try {
      onchange((await api.setStorageMaintenance(kind, every, at, day)).maintenance)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = null
    }
  }

  function repeat(kind: MaintenanceKind, every: string) {
    const t = taskOf(kind)
    if (every === 'off') void save(kind, null, '', 0)
    else if (every === 'weekly') void save(kind, 'weekly', t?.at ?? '03:00', t?.every === 'weekly' ? t.day : 6)
    else void save(kind, 'monthly', t?.at ?? '03:00', t?.every === 'monthly' ? t.day : 1)
  }

  async function runNow(kind: MaintenanceKind) {
    busy = kind
    error = ''
    try {
      onchange((await api.runStorageMaintenance(kind)).maintenance)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = null
    }
  }

  const sudoers = $derived(`${view.account ?? 'serverbox'} ALL=(root) NOPASSWD: /usr/sbin/smartctl, /usr/sbin/zpool scrub *, /usr/sbin/mdadm --action=check *`)
</script>

<div class="space-y-[13px]">
  {#if view.account !== 'root'}
    <Card class="space-y-[7px] text-[13px] text-(--text-secondary)">
      <p>{$LL.storageMaintenanceSudo()}</p>
      <pre class="lk-mono overflow-x-auto rounded-(--radius-md) bg-(--surface-field) p-[9px] text-[11.5px] whitespace-pre">{sudoers}</pre>
    </Card>
  {/if}
  {#if error}<Card class="text-[13px] text-(--color-danger)"><p>{error}</p></Card>{/if}

  {#each KINDS as kind (kind)}
    {@const t = taskOf(kind)}
    <Group title={title(kind)}>
      <Row label={about(kind)}>
        <Select
          value={t?.every ?? 'off'}
          disabled={busy === kind || (!t && !usable(kind))}
          options={[
            { value: 'off', label: $LL.storageRepeatOff() },
            { value: 'weekly', label: $LL.storageRepeatWeekly() },
            { value: 'monthly', label: $LL.storageRepeatMonthly() },
          ]}
          onchange={(e: Event) => repeat(kind, (e.currentTarget as HTMLSelectElement).value)}
          aria-label={title(kind)}
        />
      </Row>
      {#if t}
        <Row label={$LL.storageRepeatWhen()}>
          <div class="flex shrink-0 gap-[7px]">
            <Select
              value={t.day}
              disabled={busy === kind}
              options={t.every === 'weekly' ? weekdays : monthDays}
              onchange={(e: Event) => void save(kind, t.every, t.at, Number((e.currentTarget as HTMLSelectElement).value))}
              aria-label={$LL.storageRepeatDay()}
            />
            <Input
              type="time"
              value={t.at}
              disabled={busy === kind}
              onchange={(e: Event) => {
                const at = (e.currentTarget as HTMLInputElement).value
                if (at) void save(kind, t.every, at, t.day)
              }}
              aria-label={$LL.storageRepeatTime()}
            />
          </div>
        </Row>
        <Row
          label={$LL.storageLastRun()}
          value={t.last_run ? fmtDate(parseTimestamp(t.last_run), DATE_TIME) : $LL.storageNeverRun()}
          sub={t.last_error ? failure(t.last_error) : t.last_run ? $LL.storageRanOk() : undefined}
        >
          <Button size="sm" variant="secondary" icon="play_arrow" disabled={busy === kind} onclick={() => void runNow(kind)}>{$LL.storageRunNow()}</Button>
        </Row>
      {:else if !usable(kind)}
        <Row label={kind === 'scrub' ? $LL.storageNoScrubTools() : $LL.storageNoSmartctl()} />
      {/if}
    </Group>
  {/each}
</div>
