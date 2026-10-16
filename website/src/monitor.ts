import { mount } from 'svelte'
import './app.css'
import MonitorPage from './MonitorPage.svelte'

const target = document.getElementById('app')

if (!target) {
  throw new Error('Monitor page mount target #app was not found')
}

export default mount(MonitorPage, { target })
