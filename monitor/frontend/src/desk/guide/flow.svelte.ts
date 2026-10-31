/// The desk's first-run guide: which step is showing, and marking it done.
/// Whether it is shown at all is the account's (`DeskPrefs.needsGuide`).
///
/// Skipping, walking to the end or going off to install an app all mark it
/// done; Settings offers it again.

import type { DeskPrefs } from '../prefs.svelte'

export const GUIDE_STEPS = ['welcome', 'apps', 'webApps'] as const
export type GuideStep = (typeof GUIDE_STEPS)[number]

export class GuideFlow {
  step = $state<GuideStep>(GUIDE_STEPS[0])

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

  /// The guide is done with: marks the account on the agent, and the desk
  /// stops showing it.
  finish() {
    this.#prefs.markOnboarded()
  }
}
