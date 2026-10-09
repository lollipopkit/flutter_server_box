;(async function () {
  const info = await desk.call('hello')
  const setTheme = (t) => document.documentElement.classList.toggle('dark', t.dark)
  setTheme(info.theme)
  desk.on('theme', setTheme)
  desk.on('lifecycle', (s) => (document.getElementById('state').textContent = 'State: ' + s))
  document.getElementById('state').textContent = 'State: ' + info.lifecycle

  const count = ((await desk.call('storage.get', { key: 'count' })) || 0) + 1
  await desk.call('storage.set', { key: 'count', value: count })
  document.getElementById('count').textContent = count

  await desk.call('toolbar', { actions: [{ id: 'wave', label: 'Wave', icon: 'waving_hand' }] })
  await desk.call('menus', {
    menus: [{ label: 'Greeting', items: [{ id: 'wave', label: 'Wave', shortcut: '⌥⌘H' }, { id: 'reset', label: 'Reset count' }] }],
  })
  await desk.call('setBadge', { badge: count })
  desk.on('action', async ({ id }) => {
    if (id === 'wave') {
      document.getElementById('greeting').textContent = 'Hello again'
      await desk.call('notify', { title: 'Hello', body: 'Waved from the example app' })
    } else if (id === 'reset') {
      await desk.call('storage.remove', { key: 'count' })
      document.getElementById('count').textContent = '0'
      await desk.call('setBadge', { badge: null })
    }
  })
})()
