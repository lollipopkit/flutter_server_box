<script lang="ts">
  import { Badge, Card, Spinner, type BadgeTone } from '@serverbox/webui'
  import { api } from '../lib/api'
  import { LL } from '../i18n/i18n-svelte'
  import type { UserDetail, UserPasswordState, UserView } from '../types'

  interface Props {
    /// The account's name as the catalog gave it. Never a name typed here: the
    /// agent resolves it against a catalog it reads itself.
    userName: string
  }

  const { userName }: Props = $props()

  let view = $state<UserView | null>(null)
  let loading = $state(false)
  let error = $state('')
  /// A reply that arrives after the user has opened another account belongs to
  /// neither, and the two are about different accounts.
  let requestId = 0

  async function load() {
    const id = ++requestId
    loading = true
    error = ''
    try {
      const next = await api.getUsers('detail', userName)
      if (id !== requestId) return
      view = next
    } catch (e) {
      if (id !== requestId) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (id === requestId) loading = false
    }
  }

  $effect(() => {
    // A different account remounts this in practice; the name is what the one
    // request here is about.
    void userName
    void load()
  })

  /// How each password state is drawn. A `Record` over every state rather than
  /// a chain, so a state the parser grows without a label here is a type error.
  const STATES: Record<UserPasswordState, { label: () => string; tone: BadgeTone }> = {
    set: { label: () => $LL.userPasswordSet(), tone: 'neutral' },
    locked: { label: () => $LL.userPasswordLocked(), tone: 'neutral' },
    // The one that is not safe: an empty password field lets anyone in with any
    // password, so it is the one drawn as a warning and not like the two above.
    none: { label: () => $LL.userPasswordNone(), tone: 'danger' },
  }

  /// A record this session may not read is drawn as its own word rather than as
  /// an absence: `shadow`, `authorized_keys` and `sudoers` are root-only on a
  /// normal machine, and an empty string would read as "this account has no
  /// password" — the opposite of the truth.
  function instant(millis: number | null): string {
    if (millis === null) return $LL.userUnreadableField()
    return new Date(millis).toLocaleDateString()
  }

  function expires(detail: UserDetail): string {
    if (detail.never_expires) return $LL.userNever()
    return instant(detail.expires_millis)
  }

  function keys(detail: UserDetail): string {
    if (detail.ssh_key_types === null) return $LL.userUnreadableField()
    // An empty file and one that could not be read are told apart by the agent,
    // and `userPasswordNone` is this panel's word for "none" — the same one an
    // empty password field is drawn with.
    if (detail.ssh_key_types.length === 0) return $LL.userPasswordNone()
    return detail.ssh_key_types.join(', ')
  }

  function reasonText(reason: UserView): string {
    switch (reason.reason_kind) {
      case 'no_such_user':
        return $LL.userNoSuchUser()
      case 'unsupported_platform':
        return $LL.userUnsupportedPlatform()
      default:
        return reason.reason ?? $LL.userUnreadable()
    }
  }
</script>

<div class="space-y-2">
  {#if error}
    <p class="text-sm text-danger">{error}</p>
  {:else if loading && !view}
    <Spinner class="w-4 h-4" />
  {:else if view && !view.available}
    <div class="space-y-1">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
      {#if view.reason && view.reason_kind !== 'no_such_user'}
        <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.reason}</pre>
      {/if}
    </div>
  {:else if view?.detail}
    {@const detail = view.detail}
    <Card class="space-y-2">
      <h3 class="text-sm font-semibold font-display text-fg-strong">{$LL.userDetailSecurity()}</h3>
      <dl class="grid grid-cols-2 gap-x-4 gap-y-2 text-xs sm:grid-cols-3">
        <div>
          <dt class="text-faint-fg">{$LL.password()}</dt>
          <dd>
            {#if detail.password_state === null}
              <span class="text-muted-fg">{$LL.userUnreadableField()}</span>
            {:else}
              {@const state = STATES[detail.password_state]}
              <Badge tone={state.tone}>{state.label()}</Badge>
            {/if}
          </dd>
        </div>
        <div>
          <dt class="text-faint-fg">{$LL.userPasswordChanged()}</dt>
          <dd class="text-muted-fg">{instant(detail.password_changed_millis)}</dd>
        </div>
        <div>
          <dt class="text-faint-fg">{$LL.userExpires()}</dt>
          <dd class="text-muted-fg">{expires(detail)}</dd>
        </div>
        <div>
          <dt class="text-faint-fg">{$LL.userSshKeys()}</dt>
          <dd class="text-muted-fg break-all">{keys(detail)}</dd>
        </div>
        <div class="col-span-2">
          <dt class="text-faint-fg">{$LL.userSudo()}</dt>
          <!-- The rule's own right-hand side, verbatim: `NOPASSWD: ALL` is
               sudoers' syntax and there is nothing here to translate. -->
          <dd class="text-muted-fg break-all">{detail.sudo_rule ?? $LL.userUnreadableField()}</dd>
        </div>
      </dl>
    </Card>
  {/if}
</div>
