import { connect } from '@lollipopkit/desk-sys'
import './style.css'

const desk = await connect()
const state = document.getElementById('state')!

document.documentElement.classList.toggle('dark', desk.info.theme.dark)
desk.on('theme', (t) => document.documentElement.classList.toggle('dark', t.dark))
desk.on('lifecycle', (s) => (state.textContent = `State: ${s}`))
state.textContent = `State: ${desk.info.lifecycle}`

await desk.toolbar({ actions: [{ id: 'hello', label: 'Say hello', icon: 'waving_hand' }] })
await desk.menus([{ label: 'Template', items: [{ id: 'hello', label: 'Say hello', shortcut: '⌥⌘H' }] }])
desk.on('action', ({ id }) => {
  if (id === 'hello') document.getElementById('title')!.textContent = 'Hello'
})
