/// [value] as the desk holds state: a reactive proxy, as a component's
/// `$state` makes it.
export function reactive<T>(value: T): T {
  const held = $state(value)
  return held
}
