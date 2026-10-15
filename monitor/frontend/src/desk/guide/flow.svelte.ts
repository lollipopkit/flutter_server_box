/// The desk's first-run guide: which step is showing, which web apps the
/// account ticked, and marking it done. Whether the guide is shown at all is
/// the account's own preferences (`DeskPrefs.needsGuide`); this is only what
/// happens while it is.
///
/// Nobody is greeted twice: skipping any step, walking to the end, or going
/// off to install something all mark it done, and Settings offers it again.

import type { DeskPrefs } from '../prefs.svelte'

export const GUIDE_STEPS = ['welcome', 'apps', 'webApps'] as const
export type GuideStep = (typeof GUIDE_STEPS)[number]

export class GuideFlow {
  step = $state<GuideStep>(GUIDE_STEPS[0])
  /// The recommended web apps the account ticked, by catalog id.
  chosen = $state<string[]>([])

  #prefs: DeskPrefs

  constructor(prefs: DeskPrefs) {
    this.#prefs = prefs
  }

  get first(): boolean {
    return this.step === GUIDE_STEPS[0]
  }

  get last(): boolean {
    return this.step === GUIDE_STEPS[GUIDE_STEPS.length - 1]
  }

  /// The next step; from the last one, done with.
  next() {
    if (this.last) {
      this.finish()
      return
    }
    this.step = GUIDE_STEPS[GUIDE_STEPS.indexOf(this.step) + 1]
  }

  previous() {
    if (this.first) return
    this.step = GUIDE_STEPS[GUIDE_STEPS.indexOf(this.step) - 1]
  }

  toggle(appId: string) {
    this.chosen = this.chosen.includes(appId) ? this.chosen.filter((id) => id !== appId) : [...this.chosen, appId]
  }

  /// The guide is done with: marks the account on the agent, and the desk
  /// stops showing it.
  finish() {
    this.#prefs.markOnboarded()
  }
}
