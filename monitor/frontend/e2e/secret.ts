import type { Locator } from '@playwright/test'

/// Puts [value] into a password field without focusing it. A focused password
/// field in Chrome, headless too, turns on macOS Secure Input, which disables
/// every input method on the machine running the tests (no Chinese input)
/// for as long as the field keeps focus.
export async function fillSecret(field: Locator, value: string) {
  await field.evaluate((el, v) => {
    const input = el as HTMLInputElement
    // The prototype's setter, not the element's: React tracks a field's value
    // through its own and ignores an input event that did not change it.
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, v)
    input.dispatchEvent(new Event('input', { bubbles: true }))
  }, value)
}

/// Submits the form [field] is in, without focusing anything (Enter would
/// need the password field focused).
export async function submitForm(field: Locator) {
  await field.evaluate((el) => (el as HTMLInputElement).form?.requestSubmit())
}
