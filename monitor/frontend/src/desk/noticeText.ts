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
    case 'storage.arrayDegraded':
      return { subject: ll.noticeStorageArrayDegraded({ array: stringParam(params, 'array') }), body: ll.noticeStorageArrayDegradedBody() }
    case 'storage.arrayBack':
      return { subject: ll.noticeStorageArrayBack({ array: stringParam(params, 'array') }), body: ll.noticeStorageArrayBackBody() }
    case 'storage.poolUnhealthy':
      return {
        subject: ll.noticeStoragePoolUnhealthy({ pool: stringParam(params, 'pool'), health: stringParam(params, 'health') }),
        body: ll.noticeStoragePoolUnhealthyBody(),
      }
    case 'storage.poolBack':
      return { subject: ll.noticeStoragePoolBack({ pool: stringParam(params, 'pool') }), body: ll.noticeStoragePoolBackBody() }
    case 'storage.diskFailing':
      return { subject: ll.noticeStorageDiskFailing({ device: stringParam(params, 'device') }), body: ll.noticeStorageDiskFailingBody() }
    case 'storage.diskSectors':
      return {
        subject: ll.noticeStorageDiskSectors({ device: stringParam(params, 'device'), count: Number(params.count ?? 0) }),
        body: ll.noticeStorageDiskSectorsBody({ was: Number(params.was ?? 0) }),
      }
    case 'storage.maintenanceFailed': {
      const task = stringParam(params, 'task')
      const error = stringParam(params, 'error')
      const names: Record<string, string> = { scrub: ll.storageTaskScrub(), smartShort: ll.storageTaskSmartShort(), smartLong: ll.storageTaskSmartLong() }
      return { subject: ll.noticeStorageMaintenanceFailed({ task: names[task] ?? task }), body: error === 'sudoNeedsPassword' ? ll.storageNeedsSudo() : error }
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
