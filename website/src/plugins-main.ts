import { mount } from 'svelte'
import './app.css'
import Plugins from './Plugins.svelte'

const target = document.getElementById('app')

if (!target) {
  throw new Error('App mount target #app was not found')
}

const app = mount(Plugins, {
  target,
})

export default app
