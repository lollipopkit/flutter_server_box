/// Hands the browser bytes the panel fetched itself, as a download named
/// `name`. The token cannot ride an `<a download>`, so the bytes come back
/// through the API client and are handed over from memory; the URL is revoked
/// on the next tick, once the click has been dispatched.
export function saveBlob(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 0)
}
