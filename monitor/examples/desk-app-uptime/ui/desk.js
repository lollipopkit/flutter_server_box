// A minimal client of the desk's message bridge (docs/dev/desk-sys.md),
// enough for this example; the SDK package carries the full one.
;(function () {
  let next = 1
  const waiting = new Map()
  const listeners = new Map()
  window.addEventListener('message', (e) => {
    if (e.source !== window.parent) return
    const m = e.data
    if (!m || m.sbm !== 1) return
    if (typeof m.re === 'number') {
      const w = waiting.get(m.re)
      if (!w) return
      waiting.delete(m.re)
      m.ok ? w.resolve(m.value) : w.reject(new Error(m.error))
    } else if (typeof m.event === 'string') {
      for (const f of listeners.get(m.event) || []) f(m.data)
    }
  })
  function call(name, args) {
    const id = next++
    return new Promise((resolve, reject) => {
      waiting.set(id, { resolve, reject })
      window.parent.postMessage({ sbm: 1, id, call: name, args }, '*')
    })
  }
  window.desk = {
    call,
    on(event, f) {
      if (!listeners.has(event)) listeners.set(event, [])
      listeners.get(event).push(f)
    },
  }
})()
