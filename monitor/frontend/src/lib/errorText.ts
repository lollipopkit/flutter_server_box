/// What to show for a failure: its message, or the thrown value as text.
export function errorText(e: unknown): string {
  return e instanceof Error ? e.message : String(e)
}
