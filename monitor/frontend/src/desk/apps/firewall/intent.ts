import type { Intent } from '../../sys'

const MAX_LABEL_LENGTH = 64
const PORT = /^\d{1,5}(:\d{1,5})?$/
const CONTROL = /[\u007f-\u009f]/

function hasControl(value: string): boolean {
  return [...value].some((char) => char.codePointAt(0)! < 0x20 || CONTROL.test(char))
}

export interface AllowPortsRequest {
  label: string
  ports: { port: string; protocol: 'tcp' | 'udp' }[]
}

export function parseAllowPorts(intent: Intent): AllowPortsRequest | null {
  if (intent.action !== 'allowPorts' || intent.from !== 'serverbox.sharing') return null
  if (typeof intent.data !== 'object' || intent.data === null) return null

  const data = intent.data as { label?: unknown; ports?: unknown }
  if (typeof data.label !== 'string') return null
  const label = data.label.trim()
  if (!label || [...label].length > MAX_LABEL_LENGTH || label.includes("'") || hasControl(label)) return null
  if (!Array.isArray(data.ports) || data.ports.length < 1 || data.ports.length > 8) return null

  const ports: AllowPortsRequest['ports'] = []
  for (const value of data.ports) {
    if (typeof value !== 'object' || value === null) return null
    const port = value as { port?: unknown; protocol?: unknown }
    if (
      typeof port.port !== 'string' ||
      !PORT.test(port.port) ||
      (port.protocol !== 'tcp' && port.protocol !== 'udp')
    ) {
      return null
    }
    ports.push({ port: port.port, protocol: port.protocol })
  }

  return { label, ports }
}
