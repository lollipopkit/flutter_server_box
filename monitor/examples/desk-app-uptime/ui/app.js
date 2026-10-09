;(async function () {
  const info = await desk.call('hello')
  const setTheme = (t) => document.documentElement.classList.toggle('dark', t.dark)
  setTheme(info.theme)
  desk.on('theme', setTheme)
  const show = (id, text) => (document.getElementById(id).textContent = text)
  async function refresh() {
    try {
      const s = await desk.call('backend.call', { method: 'status' })
      show('host', s.host || 'This server')
      show('uptime', String(s.uptime ?? '—'))
      show('error', '')
    } catch (e) {
      show('error', e.message)
    }
  }
  await desk.call('toolbar', {
    actions: [
      { id: 'refresh', label: 'Refresh', icon: 'refresh' },
      { id: 'who', label: 'Who is signed in', icon: 'group' },
    ],
  })
  desk.on('action', async ({ id }) => {
    if (id === 'refresh') return refresh()
    try {
      const r = await desk.call('backend.call', { method: 'who' })
      show('who', r.who || '(nobody)')
    } catch (e) {
      show('error', e.message)
    }
  })
  await refresh()
})()
