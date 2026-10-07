// Packs dist/ and manifest.json as a desk app package (`<id>.sbapp`).
import { execFileSync } from 'node:child_process'
import { cpSync, mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const manifest = JSON.parse(readFileSync('manifest.json', 'utf8'))
const stage = mkdtempSync(join(tmpdir(), 'sbapp-'))
cpSync('manifest.json', join(stage, 'manifest.json'))
cpSync('dist', join(stage, 'ui'), { recursive: true })
const out = `${manifest.id}.sbapp`
// COPYFILE_DISABLE: macOS tar would add `._` files, which the agent refuses.
execFileSync('tar', ['-czf', join(process.cwd(), out), '-C', stage, 'manifest.json', 'ui'], {
  env: { ...process.env, COPYFILE_DISABLE: '1' },
})
rmSync(stage, { recursive: true })
console.log(`packed ${out}`)
