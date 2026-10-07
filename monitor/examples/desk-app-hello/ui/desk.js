// A minimal client of the desk's app bridge (docs/dev/desk-sys.md), enough
// for this example; `monitor/sdk/desk-sys` is the full one. The desk hands
// this page a MessagePort once it has loaded; everything goes over it.
;(function () {
  let next = 1
  const waiting = new Map()
  const listeners = new Map()
  const port = new Promise((resolve) => {
    window.addEventListener('message', (e) => {
      const m = e.data
      if (e.source === window.parent && m && m.sbm === 1 && m.event === 'connect' && e.ports[0]) resolve(e.ports[0])
    })
  })
  port.then((p) => {
    p.onmessage = (e) => {
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
    }
  })
  async function call(name, args) {
    const p = await port
    const id = next++
    return new Promise((resolve, reject) => {
      waiting.set(id, { resolve, reject })
      p.postMessage({ sbm: 1, id, call: name, args })
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
