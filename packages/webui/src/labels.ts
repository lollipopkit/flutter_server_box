import { getContext, setContext } from 'svelte'

/// Words the components say themselves, for an app to translate. Functions, so
/// a locale switch reaches components that are already open.
export interface WebuiLabels {
  close: () => string
}

const key = Symbol('webui-labels')
const fallback: WebuiLabels = { close: () => 'Close' }

/// Called once near the root; components under it read these labels.
export function setWebuiLabels(labels: WebuiLabels) {
  setContext(key, labels)
}

export function webuiLabels(): WebuiLabels {
  return getContext<WebuiLabels | undefined>(key) ?? fallback
}
