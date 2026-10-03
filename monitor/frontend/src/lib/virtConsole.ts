/// Opening a guest's console: the agent resolves it and mints the ticket
/// (`POST /virt/console`), and `/virt/console/ws` carries it with
/// `/stream/ws`'s framing, so [RelayChannel] serves VNC here as it serves a
/// remote desktop.
import { agentWsUrl, wsTicketProtocol } from './agentUrl'
import { parseControl } from './desktop.svelte'
import { servers } from './servers.svelte'

/// The socket once the agent said `ready`; rejected with the agent's reason
/// otherwise.
export function openConsoleSocket(ticket: string): Promise<WebSocket> {
  const entry = servers.current
  if (!entry) return Promise.reject(new Error('No server is selected'))
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(agentWsUrl(entry.url, '/api/v1/virt/console/ws'), [wsTicketProtocol(ticket)])
    socket.binaryType = 'arraybuffer'
    let settled = false
    socket.onmessage = (event) => {
      if (settled) return
      const control = parseControl(event.data)
      if (control?.type === 'ready') {
        settled = true
        socket.onmessage = null
        socket.onclose = null
        resolve(socket)
      } else if (control?.type === 'error') {
        settled = true
        reject(new Error(control.message || control.code))
        socket.close()
      }
    }
    socket.onclose = () => {
      if (!settled) {
        settled = true
        reject(new Error('The console ended'))
      }
    }
  })
}

/// A terminal size, as the agent forwards it to the console.
export function resizeMessage(cols: number, rows: number): string {
  return JSON.stringify({ type: 'resize', cols, rows })
}
