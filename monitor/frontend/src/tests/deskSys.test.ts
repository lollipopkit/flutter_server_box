import { describe, expect, it } from 'vitest'
import '../desk/apps'
import { app, availableApps, defaultDock, registry } from '../desk/registry.svelte'
import { menuItemFor, parseShortcut } from '../desk/shortcuts'
import { defineApp, registerApp } from '../desk/sys'
import { WindowChrome } from '../desk/window/chrome.svelte'
import type { Capabilities } from '../types'

const load = () => Promise.resolve({ default: (() => {}) as never })

function key(key: string, mods: Partial<Record<'metaKey' | 'ctrlKey' | 'altKey' | 'shiftKey', boolean>> = {}, code = '') {
  return new KeyboardEvent('keydown', { key, code, ...mods })
}

describe('app manifests', () => {
  it('fills in what a manifest leaves out', () => {
    const spec = defineApp({ id: 'notes', title: 'Notes', glyph: 'note', tone: 'amber', load })
    expect(spec.title({} as never)).toBe('Notes')
    expect(spec.instances).toBe(1)
    expect(spec.pinned).toBe(false)
    expect(spec.available(undefined)).toBe(true)
  })

  it('refuses an id the desk could not store', () => {
    for (const id of ['', 'Notes', '1notes', 'a-b', 'a/b', 'x'.repeat(33)]) {
      expect(() => defineApp({ id, title: 'x', glyph: 'note', tone: 'amber', load })).toThrow()
    }
    expect(() => defineApp({ id: 'ok', title: 'x', glyph: 'note', tone: 'amber', instances: 0, load })).toThrow()
  })

  it('finds every built-in app by its directory, in order', () => {
    const ids = registry.all.map((a) => a.id)
    expect(ids[0]).toBe('status')
    expect(ids.at(-1)).toBe('settings')
    expect(ids).toHaveLength(16)
    expect(defaultDock()).toEqual(['status', 'files', 'terminal', 'containers', 'virt', 'settings'])
  })

  it('registers an app at run time and takes it away again', () => {
    const off = registerApp({ id: 'acme_notes', title: 'Notes', glyph: 'note', tone: 'amber', order: 5, load })
    expect(app('acme_notes')?.title({} as never)).toBe('Notes')
    expect(registry.all[1].id).toBe('acme_notes')
    expect(availableApps({} as Capabilities).some((a) => a.id === 'acme_notes')).toBe(true)
    expect(() => registerApp({ id: 'acme_notes', title: 'Again', glyph: 'note', tone: 'amber', load })).toThrow()
    off()
    expect(app('acme_notes')).toBeUndefined()
  })
})

describe('menu shortcuts', () => {
  it('reads what a menu shows', () => {
    expect(parseShortcut('⌘⇧N')).toEqual({ cmd: true, ctrl: false, alt: false, shift: true, key: 'n' })
    expect(parseShortcut('⌥⌘K')).toMatchObject({ cmd: true, alt: true, key: 'k' })
    expect(parseShortcut('⌘,')).toMatchObject({ cmd: true, key: ',' })
    expect(parseShortcut('F5')).toMatchObject({ cmd: false, key: 'f5' })
    // A bare letter is typing, not a shortcut.
    expect(parseShortcut('N')).toBeNull()
    expect(parseShortcut('⌘')).toBeNull()
  })

  it('runs the enabled row a press names, with Command or Control', () => {
    const ran: string[] = []
    const menus = [
      {
        label: 'File',
        items: [
          { label: 'Off', shortcut: '⌘S', disabled: true, action: () => ran.push('off') },
          { separator: true as const },
          { label: 'Save', shortcut: '⌘S', action: () => ran.push('save') },
          { label: 'New', shortcut: '⌘⇧N', action: () => ran.push('new') },
        ],
      },
    ]
    menuItemFor(key('s', { metaKey: true }), menus)?.action()
    menuItemFor(key('s', { ctrlKey: true }), menus)?.action()
    menuItemFor(key('N', { metaKey: true, shiftKey: true }, 'KeyN'), menus)?.action()
    expect(ran).toEqual(['save', 'save', 'new'])
    expect(menuItemFor(key('s'), menus)).toBeUndefined()
    expect(menuItemFor(key('n', { metaKey: true }), menus)).toBeUndefined()
    expect(menuItemFor(key('s', { metaKey: true, altKey: true }), menus)).toBeUndefined()
  })

  it('tells Control from Command when a shortcut names ⌃', () => {
    const menus = [{ label: 'View', items: [{ label: 'Tab', shortcut: '⌃⇥', action: () => {} }] }]
    expect(menuItemFor(key('Tab', { ctrlKey: true }), menus)).toBeDefined()
    expect(menuItemFor(key('Tab', { metaKey: true }), menus)).toBeUndefined()
  })
})

describe('window chrome', () => {
  it('keeps the newest menus and gives back the earlier ones', () => {
    const chrome = new WindowChrome()
    const a = { menus: [{ label: 'A', items: [] }] }
    const b = { menus: [{ label: 'B', items: [] }] }
    chrome.pushMenus(a)
    const popB = chrome.pushMenus(b)
    expect(chrome.menus[0].label).toBe('B')
    popB()
    expect(chrome.menus[0].label).toBe('A')
  })

  it('holds keep-alive until each holder lets go, once', () => {
    const chrome = new WindowChrome()
    const one = chrome.holdKeepAlive('upload')
    const two = chrome.holdKeepAlive('upload')
    one()
    one()
    expect(chrome.keepAlive).toEqual(['upload'])
    two()
    expect(chrome.keepAlive).toEqual([])
  })

  it('forgets what the app set when its content goes', () => {
    const chrome = new WindowChrome()
    chrome.appName = 'Renamed'
    chrome.badge = '3'
    chrome.pushMenus({ menus: [{ label: 'A', items: [] }] })
    chrome.reset()
    expect([chrome.appName, chrome.badge, chrome.menus]).toEqual([null, null, []])
  })
})

describe('app storage', () => {
  it('keeps each app its own values, as plain JSON', async () => {
    const { AppData } = await import('../desk/appData')
    const { BrowserStorage } = await import('../desk/storage')
    const data = new AppData(new BrowserStorage(`test-${crypto.randomUUID()}`))
    const notes = data.for('notes')
    await notes.set('draft', { text: 'hi', at: new Date(0) })
    expect(await notes.get('draft')).toEqual({ text: 'hi', at: '1970-01-01T00:00:00.000Z' })
    expect(await data.for('files').keys()).toEqual([])
    await notes.remove('draft')
    expect(await notes.keys()).toEqual([])
  })

  it('refuses bad keys, undefined and too much', async () => {
    const { AppData } = await import('../desk/appData')
    const { BrowserStorage } = await import('../desk/storage')
    const notes = new AppData(new BrowserStorage(`test-${crypto.randomUUID()}`)).for('notes')
    await expect(notes.set('', 1)).rejects.toThrow('invalidKey')
    await expect(notes.set('a\nb', 1)).rejects.toThrow('invalidKey')
    await expect(notes.set('x'.repeat(129), 1)).rejects.toThrow('invalidKey')
    await expect(notes.set('a', undefined)).rejects.toThrow('invalidValue')
    await expect(notes.set('big', 'x'.repeat(300 * 1024))).rejects.toThrow('tooLarge')
    expect(await notes.keys()).toEqual([])
  })
})

describe('app notifications', () => {
  it('sit with the server’s, newest first, and count as unread until read', async () => {
    const { DeskNotifications } = await import('../desk/notifications.svelte')
    const { BrowserStorage } = await import('../desk/storage')
    const list = new DeskNotifications(new BrowserStorage(`test-${crypto.randomUUID()}`))
    list.setDnd(true)
    const n = list.posted('notes', { title: 'Saved', body: 'x'.repeat(5000), level: 'nonsense' as never })
    expect(n.id).toBeLessThan(0)
    expect(n.source).toBe('app:notes')
    expect(n.level).toBe('info')
    expect(n.body).toHaveLength(2000)
    expect(list.unread).toBe(1)
    await list.markRead(n.id)
    expect(list.unread).toBe(0)
    expect(list.list[0].subject).toBe('Saved')
    list.setDnd(false)
  })
})

describe('intents', () => {
  it('matches what an app opens', async () => {
    const { opensPath } = await import('../desk/sys/manifest')
    const spec = defineApp({ id: 'viewer', title: 'V', glyph: 'note', tone: 'amber', opens: { ext: ['.LOG', 'txt'] }, load })
    expect(spec.opens.ext).toEqual(['log', 'txt'])
    expect(opensPath(spec.opens, '/var/x.log', 'file')).toBe(true)
    expect(opensPath(spec.opens, '/var/x.LOG', 'file')).toBe(true)
    expect(opensPath(spec.opens, '/var/x.log.gz', 'file')).toBe(false)
    expect(opensPath(spec.opens, '/var/log', 'dir')).toBe(false)
    expect(opensPath({ dirs: true }, '/var/log', 'dir')).toBe(true)
    expect(opensPath({ ext: ['*'] }, '/etc/hosts', 'file')).toBe(true)
  })

  it('waits for the window that opens with one, and is taken once', async () => {
    const { Desk } = await import('../desk/deskState.svelte')
    const off = registerApp({ id: 'acme_viewer', title: 'Viewer', glyph: 'note', tone: 'amber', instances: 1, load })
    const desk = new Desk({ id: 'local', url: '', token: 't', username: 'admin' })
    const id = desk.open('acme_viewer', { intent: { action: 'open', data: { path: '/a', kind: 'dir' } } })!
    expect(desk.takeIntents(id)).toEqual([{ action: 'open', data: { path: '/a', kind: 'dir' } }])
    expect(desk.takeIntents(id)).toEqual([])

    // An app of one window: a later open lands on the mounted window.
    const chrome = new WindowChrome()
    desk.chromes.set(id, chrome)
    expect(desk.open('acme_viewer', { intent: { action: 'open', data: { path: '/b', kind: 'dir' } } })).toBe(id)
    expect(chrome.pendingIntents).toBe(1)
    expect(chrome.takeIntents()).toEqual([{ action: 'open', data: { path: '/b', kind: 'dir' } }])
    expect(chrome.pendingIntents).toBe(0)
    off()
  })

  it('reads a snippet handed to the terminal, and nothing else', async () => {
    const { queuedSnippet } = await import('../lib/snippetIntent')
    expect(queuedSnippet({ name: 'Disk', steps: [] })).toEqual({ name: 'Disk', steps: [] })
    expect(queuedSnippet({ name: 'Disk' })).toBeNull()
    expect(queuedSnippet(null)).toBeNull()
  })
})
