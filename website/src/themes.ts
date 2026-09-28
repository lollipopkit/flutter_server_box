import { mount } from 'svelte'
import './app.css'
import ThemesPage from './ThemesPage.svelte'

const target = document.getElementById('app')

if (!target) {
  throw new Error('Theme store mount target #app was not found')
}

export default mount(ThemesPage, { target })
