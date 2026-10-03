/// An identity for a record this client is about to add to a set the agent
/// stores whole (snippets, desktop routes).
///
/// `randomUUID` is absent outside a secure context, which a panel served over
/// plain HTTP from a LAN address is (`allow_insecure`). The fallback costs
/// nothing: the id is an identity within one set, not a secret.
export function newId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }
  return `s-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`
}
