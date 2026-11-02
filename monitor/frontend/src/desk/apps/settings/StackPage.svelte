<script lang="ts">
  /// An installed web app under Settings → Apps: its state, version, update
  /// and uninstall (`StackDetail`, without the App Store's header).

  import SettingsPage from './SettingsPage.svelte'
  import StackDetail from '../../../components/stack/StackDetail.svelte'
  import { LL } from '../../../i18n/i18n-svelte'

  interface Props {
    stackId: string
    onback: () => void
  }

  const { stackId, onback }: Props = $props()
</script>

<SettingsPage title={$LL.stackManage()} back={onback}>
  <StackDetail {stackId} header={false} />
</SettingsPage>
