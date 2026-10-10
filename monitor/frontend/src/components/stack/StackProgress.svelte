<script lang="ts">
  /// A deploy, update or removal as it runs: the agent's job read every
  /// second from the last line seen, the log kept scrolled to its end.

  import { Button, Card, Icon, Spinner } from '../../desk/lk'
  import { LL } from '../../i18n/i18n-svelte'
  import { api } from '../../lib/api'
  import { servers } from '../../lib/servers.svelte'
  import type { StackJob } from '../../types'
  import { untrack } from 'svelte'

  interface Props {
    stackId: string
    job: StackJob
    title: string
    /// The job ended, however it ended.
    ondone: (job: StackJob) => void
  }

  const { stackId, job: initial, title, ondone }: Props = $props()

  // The job as first given; read again from the agent from here on.
  let job = $state<StackJob>(untrack(() => ({ ...initial })))
  let lines = $state<{ seq: number; text: string }[]>(untrack(() => [...initial.lines]))
  let log = $state<HTMLPreElement | undefined>(undefined)
  let cancelling = $state(false)

  $effect(() => {
    const serverId = servers.currentId
    let stopped = false
    let timer: ReturnType<typeof setTimeout> | undefined
    async function poll() {
      try {
        const next = await api.stackJob(stackId, job.next)
        if (stopped || serverId !== servers.currentId) return
        lines = [...lines, ...next.lines.filter((l) => l.seq >= job.next)].slice(-2000)
        job = next
        if (next.state !== 'running') {
          ondone(next)
          return
        }
      } catch {
        // A blip; the next read asks from the same line.
      }
      if (!stopped) timer = setTimeout(poll, 1000)
    }
    timer = setTimeout(poll, job.state === 'running' ? 300 : 0)
    return () => {
      stopped = true
      clearTimeout(timer)
    }
  })

  $effect(() => {
    void lines.length
    if (log) log.scrollTop = log.scrollHeight
  })

  async function cancel() {
    cancelling = true
    try {
      await api.cancelStackJob(stackId)
    } finally {
      cancelling = false
    }
  }
</script>

<div class="space-y-[13px]">
  <Card class="flex items-center gap-[11px]">
    {#if job.state === 'running'}
      <Spinner size={20} />
    {:else}
      <Icon name={job.state === 'succeeded' ? 'check_circle' : 'error'} size={20} class={job.state === 'succeeded' ? 'text-(--color-success)' : 'text-(--color-danger)'} />
    {/if}
    <div class="min-w-0 flex-1">
      <p class="text-[15px] font-semibold text-(--text-primary)">{title}</p>
      <p class="text-[12px] text-(--text-secondary)">{$LL.stackProgressHint()}</p>
    </div>
    {#if job.state === 'running'}
      <Button variant="secondary" size="sm" disabled={cancelling} onclick={() => void cancel()}>{$LL.cancel()}</Button>
    {/if}
  </Card>
  <pre
    bind:this={log}
    class="lk-mono max-h-[360px] min-h-[160px] overflow-auto rounded-(--radius-md) bg-(--surface-field) p-[11px] text-[11.5px] leading-[1.5] whitespace-pre-wrap text-(--text-secondary)"
    aria-label={$LL.stackLog()}>{lines.map((l) => l.text).join('\n')}</pre>
</div>
