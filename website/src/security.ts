import { mount } from 'svelte'
import './app.css'
import SecurityPage from './SecurityPage.svelte'

const target = document.getElementById('app')

if (!target) {
  throw new Error('ServerBox security mount target #app was not found')
}

export default mount(SecurityPage, { target })
