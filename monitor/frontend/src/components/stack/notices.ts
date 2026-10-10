/// What a web app's compose files do on this machine, in words
/// (`stacks::manifest::Notice`).

import type { TranslationFunctions } from '../../i18n/i18n-types'
import type { StackNotice } from '../../types'

export function noticeText(n: StackNotice, ll: TranslationFunctions): string {
  switch (n) {
    case 'pullsImages':
      return ll.stackNoticePullsImages()
    case 'bindsPaths':
      return ll.stackNoticeBindsPaths()
    case 'mountsHostFiles':
      return ll.stackNoticeMountsHostFiles()
    case 'gpuDevices':
      return ll.stackNoticeGpuDevices()
    case 'publishesPort':
      return ll.stackNoticePublishesPort()
    case 'privileged':
      return ll.stackNoticePrivileged()
    case 'hostNetwork':
      return ll.stackNoticeHostNetwork()
    case 'dockerSocket':
      return ll.stackNoticeDockerSocket()
  }
}
