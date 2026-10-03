<script module lang="ts">
  import type { Desktop, DesktopProtocol, DesktopProtocolView } from '../types'
  import { newId } from '../lib/newId'

  /// The form's fields, in the shapes the form edits: the port is text, so it
  /// can be emptied while it is retyped. The page owns this object and seeds
  /// it when the dialog opens.
  export interface DesktopFormState {
    id: string
    name: string
    protocol: DesktopProtocol
    host: string
    port: string
    username: string
    domain: string
    viewOnly: boolean
    shared: boolean
    /// Whether the port still follows the protocol: true for a new route
    /// until the port is typed in.
    portFollowsProtocol: boolean
  }

  export function desktopFormState(
    desktop?: Desktop,
    protocols: DesktopProtocolView[] = [],
  ): DesktopFormState {
    const protocol = desktop?.protocol ?? protocols[0]?.id ?? 'vnc'
    return {
      id: desktop?.id ?? newId(),
      name: desktop?.name ?? '',
      protocol,
      host: desktop?.host ?? '127.0.0.1',
      port: String(desktop?.port ?? defaultPort(protocols, protocol)),
      username: desktop?.username ?? '',
      domain: desktop?.domain ?? '',
      viewOnly: desktop?.view_only ?? false,
      shared: desktop?.shared ?? true,
      portFollowsProtocol: desktop === undefined,
    }
  }

  /// Sent by the agent rather than hard-coded here.
  export function defaultPort(protocols: DesktopProtocolView[], protocol: DesktopProtocol): number {
    return protocols.find((entry) => entry.id === protocol)?.default_port ?? 0
  }

  /// The route the set should hold, whole, since a `PUT` replaces the set. An
  /// empty user name or domain is `null`, which is how a value is cleared; a
  /// port that is not a number is 0, which the agent refuses as `invalidPort`.
  export function desktopDraftOf(fields: DesktopFormState): Desktop {
    const port = Number.parseInt(fields.port.trim(), 10)
    return {
      id: fields.id,
      name: fields.name.trim(),
      protocol: fields.protocol,
      host: fields.host.trim(),
      port: Number.isInteger(port) && port > 0 && port <= 65535 ? port : 0,
      username: fields.username.trim() || null,
      domain: fields.protocol === 'rdp' ? fields.domain.trim() || null : null,
      view_only: fields.viewOnly,
      shared: fields.shared,
    }
  }
</script>

<script lang="ts">
  import { Button, Input, Select } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'

  interface Props {
    /// The route being changed, or `undefined` for a new one.
    desktop?: Desktop
    protocols: DesktopProtocolView[]
    fields: DesktopFormState
    onsaved: (desktop: Desktop) => void
    oncancel: () => void
  }

  const { desktop, protocols, fields, onsaved, oncancel }: Props = $props()

  const editing = $derived(desktop !== undefined)

  function changeProtocol(next: string) {
    const protocol = next as DesktopProtocol
    if (fields.portFollowsProtocol) fields.port = String(defaultPort(protocols, protocol))
    fields.protocol = protocol
  }
</script>

<div class="space-y-4">
  <div class="space-y-1">
    <label class="text-sm text-muted-fg" for="desktop-name">{$LL.desktopName()}</label>
    <Input id="desktop-name" bind:value={fields.name} placeholder="office" />
  </div>

  <div class="grid gap-4 sm:grid-cols-3">
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="desktop-protocol">{$LL.desktopProtocol()}</label>
      <Select
        id="desktop-protocol"
        class="w-full"
        value={fields.protocol}
        onchange={(e: Event) => changeProtocol((e.currentTarget as HTMLSelectElement).value)}
      >
        {#each protocols as protocol (protocol.id)}
          <option value={protocol.id}>{protocol.id.toUpperCase()}</option>
        {/each}
      </Select>
    </div>
    <div class="space-y-1 sm:col-span-2">
      <label class="text-sm text-muted-fg" for="desktop-host">{$LL.desktopHost()}</label>
      <Input id="desktop-host" bind:value={fields.host} placeholder="127.0.0.1" />
    </div>
  </div>
  <p class="text-xs text-muted-fg">{$LL.desktopHostHint()}</p>

  <div class="grid gap-4 sm:grid-cols-2">
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="desktop-port">{$LL.desktopPort()}</label>
      <Input
        id="desktop-port"
        inputmode="numeric"
        bind:value={fields.port}
        oninput={() => (fields.portFollowsProtocol = false)}
      />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="desktop-username">{$LL.desktopUsername()}</label>
      <Input id="desktop-username" bind:value={fields.username} />
    </div>
  </div>

  <!-- A Windows account's domain; VNC has none. -->
  {#if fields.protocol === 'rdp'}
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="desktop-domain">{$LL.desktopDomain()}</label>
      <Input id="desktop-domain" bind:value={fields.domain} />
    </div>
  {/if}

  <div class="space-y-2">
    <label class="flex items-center gap-2 text-sm text-fg">
      <input type="checkbox" bind:checked={fields.viewOnly} />
      {$LL.desktopViewOnly()}
    </label>
    <label class="flex items-center gap-2 text-sm text-fg">
      <input type="checkbox" bind:checked={fields.shared} />
      {$LL.desktopShared()}
    </label>
  </div>

  <!-- No password field: a route stores none. -->
  <p class="text-xs text-muted-fg">{$LL.desktopPasswordHint()}</p>

  <div class="flex justify-end gap-2">
    <Button variant="secondary" onclick={oncancel}>{$LL.cancel()}</Button>
    <Button onclick={() => onsaved(desktopDraftOf(fields))}>
      {editing ? $LL.save() : $LL.desktopAdd()}
    </Button>
  </div>
</div>
