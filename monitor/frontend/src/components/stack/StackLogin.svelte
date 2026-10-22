<script lang="ts">
  /// How the admin signs in to a deployed app the first time (the manifest's
  /// `[login]`): the account and what else to know at once, the password
  /// only when asked for, after the admin's own password.

  import { Group, IconButton, Row } from '../../desk/lk'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { api } from '../../lib/api'
  import type { StackLogin } from '../../types'
  import ReauthDialog from '../ReauthDialog.svelte'
  import { pick } from './text'

  interface Props {
    stackId: string
    login: StackLogin
    /// What the panel calls the app.
    name: string
  }

  const { stackId, login, name }: Props = $props()

  let asking = $state(false)
  let password = $state<string | null>(null)
  let copied = $state<'user' | 'password' | null>(null)

  async function reveal(own: string) {
    password = (await api.stackLogin(stackId, own)).password ?? null
    asking = false
  }

  async function copy(what: 'user' | 'password', text: string) {
    await navigator.clipboard.writeText(text)
    copied = what
    setTimeout(() => {
      if (copied === what) copied = null
    }, 1500)
  }
</script>

<Group title={$LL.stackLogin()}>
  {#if login.user}
    <Row label={$LL.stackLoginUser()}>
      <span class="flex items-center gap-[9px]">
        <span class="font-mono text-[13px]">{login.user}</span>
        <IconButton
          size="sm"
          icon={copied === 'user' ? 'check' : 'content_copy'}
          label={$LL.stackLoginCopy()}
          onclick={() => void copy('user', login.user ?? '')}
        />
      </span>
    </Row>
  {/if}
  {#if login.password}
    <Row label={$LL.stackLoginPassword()}>
      <span class="flex items-center gap-[9px]">
        {#if password}
          <span class="font-mono text-[13px] select-all">{password}</span>
          <IconButton
            size="sm"
            icon={copied === 'password' ? 'check' : 'content_copy'}
            label={$LL.stackLoginCopy()}
            onclick={() => void copy('password', password ?? '')}
          />
          <IconButton size="sm" icon="visibility_off" label={$LL.stackLoginHide()} onclick={() => (password = null)} />
        {:else}
          <span class="font-mono text-[13px] text-(--text-tertiary)">••••••••</span>
          <IconButton size="sm" icon="visibility" label={$LL.stackLoginShow()} onclick={() => (asking = true)} />
        {/if}
      </span>
    </Row>
  {/if}
  {#if login.note}
    <p class="px-[13px] py-[9px] text-[13px] text-(--text-secondary)">{pick(login.note, $locale)}</p>
  {/if}
</Group>

<ReauthDialog open={asking} message={$LL.stackLoginReauth({ name })} onconfirm={reveal} onclose={() => (asking = false)} />
