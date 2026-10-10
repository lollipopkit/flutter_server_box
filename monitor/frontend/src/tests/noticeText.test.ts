import { describe, it, expect } from 'vitest'
import { i18nObject } from '../i18n/i18n-util'
import type { DeskNotification } from '../desk/deskApi'
import { noticeText } from '../desk/noticeText'

const notice = (kind: string | null, params: Record<string, unknown> | null, subject = 'English subject', body = 'English body'): DeskNotification => ({
  id: 1,
  created_at: '',
  level: 'warning',
  source: 'stack:example.web',
  subject,
  body,
  kind,
  params,
  read: false,
})

describe('structured stack notification text', () => {
  it('renders a known kind in English and Simplified Chinese', () => {
    const n = notice('stack.down', {
      app: 'example.web',
      titles: { en: 'Example', 'zh-CN': '示例应用' },
      services: ['web', 'database'],
    })
    expect(noticeText(n, i18nObject('en'), 'en')).toEqual({
      subject: 'Example is down',
      body: 'Not running: web, database.',
    })
    expect(noticeText(n, i18nObject('zh-CN'), 'zh-CN')).toEqual({
      subject: '示例应用已停止运行',
      body: '未运行的服务：web, database。',
    })
  })

  it('renders an unhealthy notice and a back notice', () => {
    const unhealthy = notice('stack.unhealthy', {
      titles: { en: 'Example', 'zh-CN': '示例应用' },
      services: ['web'],
    })
    expect(noticeText(unhealthy, i18nObject('en'), 'en')).toEqual({
      subject: 'Example is unhealthy',
      body: 'Failing its health check: web.',
    })
    expect(noticeText(notice('stack.back', { titles: { en: 'Example', 'zh-CN': '示例应用' } }), i18nObject('zh-CN'), 'zh-CN')).toEqual({
      subject: '示例应用已恢复运行',
      body: '所有容器均已运行。',
    })
  })

  it('renders update details and falls back for an unknown kind', () => {
    const update = notice('stack.update', {
      titles: { en: 'Example', 'zh-CN': '示例应用' },
      project: 'Example Project',
      version: '2.0',
      current: '1.0',
    })
    expect(noticeText(update, i18nObject('en'), 'en')).toEqual({
      subject: 'Example: an update is available',
      body: 'Example Project 2.0 can be installed (now 1.0).',
    })
    const unknown = notice('stack.future', { app: 'example.web' })
    expect(noticeText(unknown, i18nObject('en'), 'en')).toEqual({ subject: 'English subject', body: 'English body' })
  })
})
