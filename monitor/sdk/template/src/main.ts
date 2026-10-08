import { connect } from '@lollipopkit/desk-sys'
import { applyTheme } from '@lollipopkit/desk-ui/theme'
// No icons in this UI (the desk draws the toolbar's): the 3 MB icon font
// stays out. Import '@lollipopkit/desk-ui/lk.css' for everything.
import '@lollipopkit/desk-ui/core.css'
import '@lollipopkit/desk-ui/fonts.css'
import './style.css'

const desk = await connect()
const state = document.getElementById('state')!
const title = document.getElementById('title')!

// Drawn as the desk is: its mode and the installed theme's tokens.
applyTheme(desk.info.theme)
desk.on('theme', (theme) => applyTheme(theme))
desk.on('lifecycle', (s) => (state.textContent = `State: ${s}`))
state.textContent = `State: ${desk.info.lifecycle}`

const hello = () => (title.textContent = 'Hello')
document.getElementById('hello')!.addEventListener('click', hello)
await desk.toolbar({ actions: [{ id: 'hello', label: 'Say hello', icon: 'waving_hand' }] })
await desk.menus([{ label: 'Template', items: [{ id: 'hello', label: 'Say hello', shortcut: '⌥⌘H' }] }])
desk.on('action', ({ id }) => {
  if (id === 'hello') hello()
})
