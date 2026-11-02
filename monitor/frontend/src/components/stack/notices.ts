/// What a web app's compose files do on this machine, in words
/// (`stacks::manifest::Notice`).

import type { TranslationFunctions } from '../../i18n/i18n-types'
import type { StackManifest, StackNotice } from '../../types'

export function noticeText(n: StackNotice, ll: TranslationFunctions): string {
  switch (n) {
    case 'pullsImages':
      return ll.stackNoticePullsImages()
    case 'buildsImages':
      return ll.stackNoticeBuildsImages()
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

/// What Agent mode gets from the app, in words: a sidecar says whose code it
/// is, a community one that it holds the app's credential.
export function mcpNotices(manifest: StackManifest, ll: TranslationFunctions): string[] {
  return (manifest.mcp ?? []).map((m) => {
    const source = m.source ?? manifest.source
    if (m.publisher === 'community') return ll.stackNoticeMcpCommunity({ source })
    if (m.publisher === 'official') return ll.stackNoticeMcpOfficial({ source })
    return ll.stackNoticeMcpBuiltin()
  })
}
