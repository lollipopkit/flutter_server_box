import { connect } from '@lollipopkit/desk-sys'
import './style.css'

// Once connected, the page is in the desk's design system (its `lk-*`
// classes and tokens, served by the desk) and follows the desk's mode and
// theme. Nothing of it is in this package.
const desk = await connect()
const state = document.getElementById('state')!
const title = document.getElementById('title')!

desk.on('lifecycle', (s) => (state.textContent = `State: ${s}`))
state.textContent = `State: ${desk.info.lifecycle}`

const hello = () => (title.textContent = 'Hello')
document.getElementById('hello')!.addEventListener('click', hello)
await desk.toolbar({ actions: [{ id: 'hello', label: 'Say hello', icon: 'waving_hand' }] })
await desk.menus([{ label: 'Template', items: [{ id: 'hello', label: 'Say hello', shortcut: '⌥⌘H' }] }])
desk.on('action', ({ id }) => {
  if (id === 'hello') hello()
})
