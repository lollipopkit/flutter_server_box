import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import DetailPanel from '../desk/apps/status/DetailPanel.svelte'
import type { GpuMetrics, SystemMetrics } from '../types'

const gpu = (processes: GpuMetrics['processes']): GpuMetrics => ({
  id: 'nvidia:0',
  vendor: 'nvidia',
  name: 'Tesla T10',
  usage_percent: 100,
  temperature: 80,
  power: null,
  memory_used: 8579,
  memory_total: 16384,
  memory_unit: 'MiB',
  processes,
})
const metrics = (g: GpuMetrics) => ({ gpus: [g] }) as unknown as SystemMetrics

describe('the GPU detail', () => {
  it('lists what holds the card, a name the driver withheld said so', () => {
    render(DetailPanel, {
      kind: 'gpu',
      history: [],
      metrics: metrics(gpu([{ pid: 4242, name: 'python3', memory: 6144 }, { pid: 4, name: '', memory: 0 }])),
    })
    expect(screen.getByText('python3')).toBeInTheDocument()
    expect(screen.getByText('6144 MiB')).toBeInTheDocument()
    expect(screen.getByText('Unnamed process')).toBeInTheDocument()
  })

  it('says why none are listed while memory is in use', () => {
    render(DetailPanel, { kind: 'gpu', history: [], metrics: metrics(gpu([])) })
    expect(screen.getByText(/The driver lists no process/)).toBeInTheDocument()
  })
})
