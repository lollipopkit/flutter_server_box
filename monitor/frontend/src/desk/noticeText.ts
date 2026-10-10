/// Renders structured agent notices in the reader's language; older rows keep
/// their English subject and body.

import type { TranslationFunctions } from '../i18n/i18n-types'
import type { LocalizedText } from '../types'
import type { DeskNotification } from './deskApi'
import { pick } from '../components/stack/text'

export function noticeText(
  n: DeskNotification,
  ll: TranslationFunctions,
  locale: string,
): { subject: string; body: string } {
  const params = n.params ?? {}
  const titles = params.titles as LocalizedText | undefined
  const app = pick(titles, locale) || stringParam(params, 'app')
  const services = stringList(params.services)

  switch (n.kind) {
    case 'stack.down':
      return {
        subject: ll.noticeStackDown({ app }),
        body: services.length ? ll.noticeStackDownBody({ services: services.join(', ') }) : ll.noticeStackDownBodyEmpty(),
      }
    case 'stack.unhealthy':
      return {
        subject: ll.noticeStackUnhealthy({ app }),
        body: ll.noticeStackUnhealthyBody({ services: services.join(', ') }),
      }
    case 'stack.back':
      return { subject: ll.noticeStackBack({ app }), body: ll.noticeStackBackBody() }
    case 'stack.update':
      return {
        subject: ll.noticeStackUpdate({ app }),
        body: ll.noticeStackUpdateBody({
          project: stringParam(params, 'project'),
          version: stringParam(params, 'version'),
          current: stringParam(params, 'current'),
        }),
      }
    default:
      return { subject: n.subject, body: n.body }
  }
}

function stringParam(params: Record<string, unknown>, key: string): string {
  const value = params[key]
  return typeof value === 'string' ? value : ''
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : []
}
