// Writes `<file>.br` and `<file>.gz` next to every compressible file in
// dist/assets and dist/desk-app, for the agent to serve as they are
// (`api::assets`):
// compressed once at the highest levels here rather than per request there.
// `.gz` is for plain HTTP, where browsers do not offer brotli. A copy that
// saves under a tenth is not written (woff2, wasm and images are compressed
// already and are not even tried).
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { brotliCompressSync, constants, gzipSync } from 'node:zlib'

const dirs = ['assets', 'desk-app'].map((d) => new URL(`../dist/${d}/`, import.meta.url).pathname).filter(existsSync)
const compressible = /\.(js|mjs|css|svg|json|txt|html)$/

let before = 0
let after = 0
for (const dir of dirs) for (const name of readdirSync(dir)) {
  if (!compressible.test(name)) continue
  const path = join(dir, name)
  const raw = readFileSync(path)
  const br = brotliCompressSync(raw, {
    params: { [constants.BROTLI_PARAM_QUALITY]: 11, [constants.BROTLI_PARAM_SIZE_HINT]: raw.length },
  })
  const gz = gzipSync(raw, { level: 9 })
  before += raw.length
  if (br.length < raw.length * 0.9) writeFileSync(`${path}.br`, br)
  if (gz.length < raw.length * 0.9) writeFileSync(`${path}.gz`, gz)
  after += Math.min(br.length, raw.length)
}
console.log(`compress: ${(before / 1e6).toFixed(1)} MB of scripts and styles, ${(after / 1e6).toFixed(1)} MB as brotli`)
