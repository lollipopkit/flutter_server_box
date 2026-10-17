/// Catalog web apps set up, used and removed through the panel on a real
/// agent with Docker: each found in the App Store, set up with the settings
/// offered (the third-party notice and its licence accepted, the agent's
/// password asked), its sign-in read in its page, its window opened and
/// signed in to there, then uninstalled with its data.
///
///     SBM_E2E_CATALOG=1 SBM_E2E_PANEL_URL=https://… SBM_E2E_PANEL_PASSWORD=… npx playwright test catalog_apps
///
/// It deploys and removes apps: run it against an agent of its own (a
/// throwaway VM, `scripts/desk-vm-e2e.sh <node> catalog_apps`), never one
/// with these apps deployed. `SBM_E2E_CATALOG_APPS=Gitea,…` picks the apps by
/// title.

import { expect, test, type FrameLocator, type Locator, type Page } from '@playwright/test'
import { fillSecret, submitForm } from './secret'
import { signIn } from './signin'

const env = process.env

test.skip(!env.SBM_E2E_CATALOG || !env.SBM_E2E_PANEL_URL || !env.SBM_E2E_PANEL_PASSWORD, 'SBM_E2E_CATALOG, SBM_E2E_PANEL_URL and SBM_E2E_PANEL_PASSWORD are not set')

/// The password of the accounts this test makes in an app.
const PASSWORD = 'e2e-Passw0rd-not-kept'

interface Login {
  user: string | null
  password: string | null
}

/// Each app by its title: its id, and how it is signed in to inside its
/// window and what says it worked.
const APPS: Record<string, { id: string; use: (frame: FrameLocator, login: Login) => Promise<void> }> = {
  'IT-Tools': {
    id: 'corentinth.it_tools',
    use: async (frame) => {
      const tool = frame.getByText('UUIDs generator', { exact: true }).first()
      await expect(tool).toBeVisible({ timeout: 60_000 })
      // One of its own routes, which the server answers with the page.
      await tool.click()
      await expect(frame.getByRole('button', { name: /refresh/i }).first()).toBeVisible({ timeout: 30_000 })
    },
  },
  linkding: {
    id: 'sissbruecker.linkding',
    use: async (frame, login) => {
      await signInForm(frame, frame.locator('input[name=username]'), login)
      await expect(frame.locator('a[href*="/bookmarks/new"]').first()).toBeAttached({ timeout: 60_000 })
    },
  },
  ntfy: {
    id: 'binwiederhier.ntfy',
    use: async (frame, login) => {
      await signInForm(frame, frame.locator('input#username'), login)
      await expect(frame.getByRole('button', { name: /subscribe to topic/i }).first()).toBeVisible({ timeout: 60_000 })
    },
  },
  Audiobookshelf: {
    id: 'advplyr.audiobookshelf',
    use: async (frame, login) => {
      await signInForm(frame, frame.locator('input:not([type=password]):not([type=hidden])').first(), login)
      await expect(frame.getByText(/add.*librar|no libraries/i).first()).toBeVisible({ timeout: 60_000 })
    },
  },
  Mealie: {
    id: 'mealie.mealie',
    use: async (frame, login) => {
      await signInForm(frame, frame.locator('input[type=text], input[type=email]').first(), login)
      // Signed in, a new Mealie starts its setup.
      await expect(frame.getByText(/Welcome to Mealie/).first()).toBeVisible({ timeout: 60_000 })
    },
  },
  Gitea: {
    id: 'gitea.gitea',
    use: async (frame) => {
      // Its installation page, as the sign-in note says: the administrator made
      // there, everything else as offered.
      await expect(frame.locator('input[name=db_type]')).toHaveValue('sqlite3', { timeout: 60_000 })
      await frame.getByText(/administrator account settings/i).click()
      await frame.locator('input[name=admin_name]').fill('e2e-admin')
      await frame.locator('input[name=admin_email]').fill('admin@e2e.invalid')
      await fillSecret(frame.locator('input[name=admin_passwd]'), PASSWORD)
      await fillSecret(frame.locator('input[name=admin_confirm_passwd]'), PASSWORD)
      await frame.getByRole('button', { name: /install gitea/i }).click()
      // It restarts into its installed self, the administrator signed in.
      await expect(frame.locator('.user-menu, #navbar .avatar, img.avatar').first()).toBeAttached({ timeout: 180_000 })
    },
  },
  'Paperless-ngx': {
    id: 'paperless.paperless_ngx',
    use: async (frame, login) => {
      await signInForm(frame, frame.locator('input[name=login]'), login)
      await expect(frame.locator('pngx-dashboard, app-dashboard, pngx-app-frame').first()).toBeAttached({ timeout: 120_000 })
    },
  },
  'Open WebUI': {
    id: 'openwebui.open_webui',
    use: async (frame, login) => {
      await signInForm(frame, frame.locator('input[type=email], input[name=email]').first(), login)
      await expect(frame.locator('#chat-input, textarea').first()).toBeVisible({ timeout: 120_000 })
    },
  },
}

/// A page's own sign-in form: [user] and the password field filled with
/// what the app's details showed, then sent.
async function signInForm(frame: FrameLocator, user: Locator, login: Login) {
  // The window may open on "The app is starting…" (Open WebUI fetches its
  // embedding model first), which reloads itself until the app answers.
  await expect(user).toBeVisible({ timeout: 10 * 60_000 })
  await user.fill(login.user ?? '')
  const pass = frame.locator('input[type=password]').first()
  await fillSecret(pass, login.password ?? '')
  await submitForm(pass)
}

async function openStore(page: Page, title: string): Promise<Locator> {
  await page.locator('.lk-dock button[aria-label="All Apps"]').click()
  await page.getByRole('dialog', { name: 'All Apps' }).getByRole('button', { name: 'App Store', exact: true }).click()
  const store = page.locator('.desk-window[data-app-id="serverbox.store"]')
  await store.getByPlaceholder('Search apps').fill(title)
  await store.getByText(title, { exact: true }).first().click()
  return store
}

/// The account's password, asked again before a change.
async function reauth(page: Page) {
  const field = page.locator('.lk-dialog').last().locator('input[type=password]')
  await fillSecret(field, env.SBM_E2E_PANEL_PASSWORD!)
  await submitForm(field)
}

/// Uninstalls the app [store] shows, its data with it.
async function uninstall(page: Page, store: Locator) {
  await store.getByRole('button', { name: 'Uninstall…', exact: true }).first().click()
  const dialog = page.locator('.lk-dialog').last()
  await dialog.getByText('Also delete its data').click()
  await dialog.getByRole('button', { name: 'Uninstall…', exact: true }).click()
  await reauth(page)
  await expect(store.getByRole('button', { name: 'Get', exact: true })).toBeVisible({ timeout: 10 * 60_000 })
}

const picked = env.SBM_E2E_CATALOG_APPS?.split(',').map((s) => s.trim()) ?? Object.keys(APPS)

for (const title of picked) {
  test(`${title}: set up, signed in to in its window, uninstalled`, async ({ page }) => {
    const app = APPS[title]
    expect(app, `no steps for ${title}`).toBeTruthy()
    await signIn(page)
    const store = await openStore(page, title)
    // Set up from here on: removed again whatever happens, so the next app
    // has the machine to itself.
    let deployed = false
    try {
      await test.step('set up with the settings offered', async () => {
        await store.getByRole('button', { name: 'Get', exact: true }).click()
        await store.getByRole('button', { name: 'Set up', exact: true }).click()
        const confirm = page.locator('.lk-dialog').last()
        await confirm.getByText(/I understand this installs/).click()
        const licence = confirm.getByText(/I accept the .* licence/)
        if (await licence.count()) await licence.click()
        await confirm.getByRole('button', { name: 'Continue', exact: true }).click()
        await reauth(page)
        deployed = true
        // Images are pulled (and built) first: minutes on a fresh machine.
        await expect(store.getByRole('button', { name: 'Open', exact: true }).first()).toBeVisible({ timeout: 30 * 60_000 })
      })

      const login: Login = { user: null, password: null }
      await test.step('its sign-in, shown after the agent password', async () => {
        const group = store.locator('.lk-group, section').filter({ has: page.getByText('Sign-in', { exact: true }) }).last()
        if (!(await group.count())) return
        const user = group.locator('.font-mono').first()
        if (await user.count()) login.user = (await user.textContent())?.trim() ?? null
        const show = group.getByRole('button', { name: 'Show password' })
        if (await show.count()) {
          await show.click()
          await reauth(page)
          const shown = group.locator('.select-all')
          await expect(shown).toBeVisible({ timeout: 30_000 })
          login.password = (await shown.textContent())?.trim() ?? null
        }
      })

      await test.step('its window shows the app, signed in to there', async () => {
        await store.getByRole('button', { name: 'Open', exact: true }).first().click()
        const win = page.locator(`.desk-window[data-app-id="${app.id}"]`)
        await app.use(win.frameLocator('iframe').first(), login)
        await win.getByRole('button', { name: 'Close', exact: true }).first().click()
      })

      await test.step('uninstalled with its data', () => uninstall(page, store))
      deployed = false
    } finally {
      if (deployed) {
        const win = page.locator(`.desk-window[data-app-id="${app.id}"]`)
        if (await win.count()) await win.getByRole('button', { name: 'Close', exact: true }).first().click().catch(() => {})
        await uninstall(page, store).catch(() => {})
      }
    }
  })
}
