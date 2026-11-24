/// The icon tones: berry-palette tones for the system's own apps, soft hues
/// for the rest.
export const ICON_TONES = [
  'berry',
  'soft',
  'bright',
  'pale',
  'mist',
  'ink',
  'sky',
  'violet',
  'teal',
  'leaf',
  'amber',
] as const

export type IconTone = (typeof ICON_TONES)[number]

export function parseIconTone(tone: string | undefined, fallback: IconTone = 'mist'): IconTone {
  return ICON_TONES.includes(tone as IconTone) ? (tone as IconTone) : fallback
}
