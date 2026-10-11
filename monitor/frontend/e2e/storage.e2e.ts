/// The Storage app on a real machine, through the panel: a disk initialized,
/// formatted, mounted and unmounted; a RAID 1 built, degraded, mended, grown
/// and deleted; a ZFS mirror built, scrubbed and destroyed; SMART read; the
/// maintenance schedule set and run; a disk encrypted, locked and unlocked
/// (where cryptsetup is installed). RAID and ZFS are tried where mdadm and
/// zpool are installed.
///
/// It wipes the disks it is given. `scripts/storage-e2e.sh <node>` runs it
/// (and the rest of the storage tests) on a fresh Proxmox VE VM with spare
/// disks, made and destroyed for the run.
///
///     SBM_E2E_PANEL_URL=http://127.0.0.1:3770 SBM_E2E_PANEL_USER=admin \
///     SBM_E2E_PANEL_PASSWORD=… SBM_E2E_SUDO_PASSWORD=… \
///     SBM_E2E_STORAGE_DISKS=/dev/sdb,/dev/sdc,/dev/sdd,/dev/sde \
///     npx playwright test storage
///
/// `SBM_E2E_SUDO_PASSWORD` is left out for an agent that needs none (root,
/// `NOPASSWD`). Pass secrets from a keychain, never on a command line others
/// can read.

import { expect, test, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'

const env = process.env
const disks = (env.SBM_E2E_STORAGE_DISKS ?? '').split(',').map((d) => d.trim()).filter(Boolean)
const sudo = env.SBM_E2E_SUDO_PASSWORD ?? ''
const MOUNT = '/mnt/sbm-e2e'

test.skip(!env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD || disks.length === 0, 'SBM_E2E_PANEL_URL, SBM_E2E_PANEL_PASSWORD and SBM_E2E_STORAGE_DISKS are not set')

/// `/dev/sdb` → `/dev/sdb1`, `/dev/nvme1n1` → `/dev/nvme1n1p1`.
const firstPartition = (disk: string) => (/\d$/.test(disk) ? `${disk}p1` : `${disk}1`)

class Storage {
  constructor(readonly page: Page) {}

  dialog() {
    return this.page.locator('.lk-dialog').last()
  }

  async open() {
    const { page } = this
    await page.goto('/')
    await page.getByPlaceholder('Username').fill(env.SBM_E2E_PANEL_USER ?? 'admin')
    const login = page.locator('input[type=password]')
    await fillSecret(login, env.SBM_E2E_PANEL_PASSWORD!)
    await submitForm(login)
    await page.locator('.lk-dock button[aria-label="All Apps"]').click()
    await page.getByText('Storage', { exact: true }).first().click()
    await expect(page.getByText(disks[0], { exact: true }).first()).toBeVisible({ timeout: 30_000 })
  }

  async tab(name: string) {
    await this.page.getByText(name, { exact: true }).first().click()
  }

  /// The button [name] on the row naming [path].
  async rowButton(path: string, name: string) {
    const { page } = this
    const row = page
      .locator('div')
      .filter({ has: page.getByText(path, { exact: true }) })
      .filter({ has: page.getByRole('button', { name, exact: true }) })
      .last()
    await row.getByRole('button', { name, exact: true }).click()
  }

  /// Answers the confirmation: the word typed back, sudo's password.
  async confirm(title: string, word?: string, password = sudo) {
    const d = this.dialog()
    await expect(d).toBeVisible()
    if (word) await d.getByLabel(/to confirm/).fill(word)
    await fillSecret(d.getByLabel(/sudo password/), password)
    await d.getByRole('button', { name: title, exact: true }).click()
  }

  /// Waits for the job just started, which must succeed.
  async done() {
    const { page } = this
    await expect(page.getByText('Changing the disks…')).toBeHidden({ timeout: 10 * 60_000 })
    await expect(page.getByText('Did not finish', { exact: true })).toHaveCount(0)
    await expect(page.getByText('Done', { exact: true })).toBeVisible()
  }

  async form(fields: Record<string, string>, then = 'Continue') {
    const d = this.dialog()
    for (const [label, value] of Object.entries(fields)) await d.getByLabel(label).fill(value)
    await d.getByRole('button', { name: then }).click()
  }

  async pick(...paths: string[]) {
    for (const p of paths) await this.dialog().locator('.lk-check', { hasText: `${p} · ` }).click()
  }
}

test('the Storage app manages a machine\'s disks', async ({ page }) => {
  const s = new Storage(page)
  await s.open()
  const [disk, ...rest] = disks
  const part = firstPartition(disk)

  if (sudo) {
    await test.step('a wrong sudo password is refused', async () => {
      await s.rowButton(disk, 'Initialize')
      await s.confirm('Initialize', disk, `${sudo}-wrong`)
      await expect(s.dialog().getByText('sudo did not accept this password.')).toBeVisible()
      await s.dialog().getByRole('button', { name: 'Cancel' }).click()
    })
  }

  await test.step('SMART is read', async () => {
    const read = page.getByRole('button', { name: 'Read disk health' })
    if (await read.count()) {
      await read.click()
      if (await s.dialog().isVisible()) await s.confirm('Read disk health')
      const row = page.locator('div').filter({ has: page.getByText(disk, { exact: true }) })
      await expect(row.locator('.lk-badge', { hasText: /Healthy|Wearing|Failing|Asleep|No SMART/ }).first()).toBeVisible()
    }
  })

  await test.step('a disk is initialized, formatted, mounted and unmounted', async () => {
    await s.rowButton(disk, 'Initialize')
    await s.confirm('Initialize', disk)
    await s.done()
    await s.rowButton(part, 'Format')
    await s.form({ Label: 'sbme2e' })
    await s.confirm('Format', part)
    await s.done()
    await s.rowButton(part, 'Mount')
    await s.form({ 'Mount point': MOUNT })
    await s.confirm('Mount')
    await s.done()
    await expect(page.getByText(new RegExp(`ext4 · sbme2e · ${MOUNT}`))).toBeVisible()
    await s.rowButton(part, 'Unmount')
    await s.confirm('Unmount')
    await s.done()
    await expect(page.getByText(new RegExp(`ext4 · sbme2e · ${MOUNT}`))).toHaveCount(0)
  })

  await s.tab('RAID')
  if (rest.length >= 3 && !(await page.getByText(/mdadm is not installed/).count())) {
    await test.step('a RAID 1 is built, degraded, mended and deleted', async () => {
      const [a, b, c] = rest
      await page.getByRole('button', { name: 'Create array' }).first().click()
      const md = await s.dialog().getByLabel('Name').inputValue()
      await s.pick(a, b)
      await s.dialog().getByRole('button', { name: 'Continue' }).click()
      await s.confirm('Create array', md)
      await s.done()
      await expect(page.getByText(`/dev/${md} · raid1`)).toBeVisible()
      await s.rowButton(b, 'Remove')
      await s.confirm('Remove', b.replace('/dev/', ''))
      await s.done()
      await expect(page.getByText('Degraded', { exact: true })).toBeVisible()
      await page.getByRole('button', { name: 'Add disk' }).first().click()
      await s.dialog().locator('select').selectOption(c)
      await s.dialog().getByRole('button', { name: 'Continue' }).click()
      await s.confirm('Add disk', c)
      await s.done()
      await expect(page.getByText(c, { exact: true })).toBeVisible()
      // One more mirror, from the first disk (free again).
      await page.getByRole('button', { name: 'Grow' }).first().click()
      await s.dialog().locator('select').selectOption(disk)
      await s.dialog().getByRole('button', { name: 'Continue' }).click()
      await s.confirm('Grow', disk)
      await s.done()
      await expect(page.getByText(disk, { exact: true })).toBeVisible()
      await page.getByRole('button', { name: 'Delete array' }).first().click()
      await s.confirm('Delete array', md)
      await s.done()
      await expect(page.getByText(`/dev/${md} · raid1`)).toHaveCount(0)
    })
  }

  await s.tab('ZFS pools')
  if (rest.length >= 2 && !(await page.getByText(/ZFS is not installed/).count())) {
    await test.step('a ZFS mirror is built, scrubbed and destroyed', async () => {
      await page.getByRole('button', { name: 'Create pool' }).first().click()
      await s.dialog().getByLabel('Name').fill('sbme2e')
      await s.pick(rest[0], rest[1])
      await s.dialog().getByRole('button', { name: 'Continue' }).click()
      await s.confirm('Create pool', 'sbme2e')
      await s.done()
      await expect(page.locator('.lk-badge', { hasText: 'ONLINE' })).toBeVisible()
      await page.getByRole('button', { name: 'Scrub' }).first().click()
      await s.confirm('Scrub')
      await s.done()
      await page.getByRole('button', { name: 'Destroy pool' }).first().click()
      await s.confirm('Destroy pool', 'sbme2e')
      await s.done()
      await expect(page.getByText(/^sbme2e · /)).toHaveCount(0)
    })
  }

  await test.step('the maintenance schedule is set, run and turned off', async () => {
    await s.tab('Maintenance')
    const repeat = page.getByLabel('Scrub pools and check arrays')
    await repeat.selectOption('weekly')
    await expect(page.getByRole('button', { name: 'Run now' })).toBeVisible()
    await page.getByRole('button', { name: 'Run now' }).click()
    // Without a sudoers rule an agent that is not root is told what to allow.
    await expect(page.getByText(/^(Started|sudo asked for a password.*)$/)).toBeVisible({ timeout: 60_000 })
    await repeat.selectOption('off')
    await expect(page.getByRole('button', { name: 'Run now' })).toHaveCount(0)
  })

  await test.step('a disk is encrypted, locked and unlocked', async () => {
    await s.tab('Disks')
    const phrase = 'e2e passphrase'
    await s.rowButton(disk, 'Format')
    const encrypt = s.dialog().locator('.lk-check', { hasText: 'Encrypt (LUKS)' })
    if (!(await encrypt.count())) return // no cryptsetup on this machine
    await encrypt.click()
    await s.dialog().getByRole('button', { name: 'Continue' }).click()
    await fillSecret(s.dialog().getByLabel(/^Passphrase/), phrase)
    await fillSecret(s.dialog().getByLabel('The same again'), phrase)
    await s.dialog().getByRole('button', { name: 'Continue' }).click()
    await s.confirm('Format', disk)
    await s.done()
    await expect(page.getByText(/^Encrypted$/)).toBeVisible()
    await page.getByRole('button', { name: 'Lock' }).first().click()
    await s.confirm('Lock')
    await s.done()
    await expect(page.getByText('Encrypted · Locked')).toBeVisible()
    await page.getByRole('button', { name: 'Unlock' }).first().click()
    await fillSecret(s.dialog().getByLabel('Passphrase'), phrase)
    await s.dialog().getByRole('button', { name: 'Continue' }).click()
    await s.confirm('Unlock')
    await s.done()
    await expect(page.getByText(/^Encrypted$/)).toBeVisible()
    await page.getByRole('button', { name: 'Lock' }).first().click()
    await s.confirm('Lock')
    await s.done()
  })
})
