import { mount } from 'svelte'
import App from './App.svelte'
import { ready } from './i18n/init'
import { loadFullIconFont } from './lib/iconFont'
import './index.css'

await ready
const app = mount(App, {
  target: document.getElementById('app')!,
})
loadFullIconFont()

export default app
