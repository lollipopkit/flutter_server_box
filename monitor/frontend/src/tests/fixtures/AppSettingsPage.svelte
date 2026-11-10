<script lang="ts">
  /// A third app's settings page: it keeps a value in its own storage.
  import { useWindow } from '../../desk/sys'

  const win = useWindow()
  let saved = $state('')
</script>

<button onclick={async () => {
  await win.storage.set('greeting', 'hi')
  saved = String(await win.storage.get('greeting'))
}}>Save greeting</button>
<p>saved: {saved}</p>
