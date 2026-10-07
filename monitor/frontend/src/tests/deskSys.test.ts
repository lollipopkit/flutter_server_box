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
    for (const id of ['', 'Notes', '1notes', 'a-b', 'a/b', 'x'.repeat(65)]) {
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
