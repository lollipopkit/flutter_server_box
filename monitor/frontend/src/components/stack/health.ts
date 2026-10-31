/// How the panel says a deployed app's health (`StackHealth`).

import type { TranslationFunctions } from '../../i18n/i18n-types'
import type { StackHealth } from '../../types'

export function healthBadge(state: StackHealth['state'], ll: TranslationFunctions): { tone: 'success' | 'neutral' | 'danger'; text: string } {
  switch (state) {
    case 'healthy':
      return { tone: 'success', text: ll.stackHealthy() }
    case 'starting':
      return { tone: 'neutral', text: ll.stackStarting() }
    case 'unhealthy':
      return { tone: 'danger', text: ll.stackUnhealthy() }
    case 'down':
      return { tone: 'danger', text: ll.stackDown() }
    case 'stopped':
      return { tone: 'neutral', text: ll.stackStopped() }
  }
}
