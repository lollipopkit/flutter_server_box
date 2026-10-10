import { describe, it, expect } from 'vitest'
import { Desk } from '../desk/deskState.svelte'
import type { DeskNotification } from '../desk/deskApi'

const notice = (source: string): DeskNotification => ({
  id: 1,
  created_at: '',
  level: 'warning',
  source,
  subject: 'Photos is down',
  body: 'Not running: web.',
  read: false,
})

describe("a web app's notification", () => {
  it("is its own window's when the panel has one, else its App Store page's", () => {
    const desk = new Desk({ id: 'local', url: '', token: 't', username: 'admin' })
    expect(desk.noticeSource(notice('stack:futo.immich'))).toMatchObject({ appId: 'serverbox.photos', appState: undefined })
    expect(desk.noticeSource(notice('stack:serverbox.testweb'))).toMatchObject({
      appId: 'serverbox.store',
      appState: { app: 'serverbox.testweb' },
    })
    expect(desk.noticeSource(notice('alert')).appId).toBe('serverbox.status')
  })
})
