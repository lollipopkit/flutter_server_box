import { mount } from 'svelte'
import './app.css'
import OsPage from './OsPage.svelte'

const target = document.getElementById('app')

if (!target) {
  throw new Error('ServerBox OS mount target #app was not found')
}

export default mount(OsPage, { target })
