import { mount } from 'svelte'
import App from './App.svelte'
import './i18n/init'
import './index.css'

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app
