// A theme's preview data, fetched once per page however many cards ask for
// it (store-data.js writes one file per theme).
const cache = new Map()

export function loadPreview(theme) {
  let pending = cache.get(theme.previewUrl)
  if (!pending) {
    pending = fetch(theme.previewUrl).then((r) => {
      if (!r.ok) throw new Error(`${theme.previewUrl}: ${r.status}`)
      return r.json()
    })
    // A failure is not kept: scrolling past again may try again.
    pending.catch(() => cache.delete(theme.previewUrl))
    cache.set(theme.previewUrl, pending)
  }
  return pending
}
