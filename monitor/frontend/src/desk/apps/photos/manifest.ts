import { defineApp } from '../../sys'
import { stackDeployed } from '../../../components/stack/apps'

export default defineApp({
  publisher: 'serverbox',
  name: 'photos',
  title: (ll) => ll.photos(),
  keywords: (ll) => [ll.photosKeywords()],
  glyph: 'photo_library',
  tone: 'sky',
  // Built in, but offered only once an admin installed it (Settings → Apps),
  // and gone again when it is uninstalled.
  available: (caps) => stackDeployed(caps, 'futo.immich'),
  size: { width: 1180, height: 780 },
  minSize: { width: 480, height: 360 },
  order: 135,
  load: () => import('./PhotosApp.svelte'),
})
