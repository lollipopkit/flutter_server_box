/// The sidebar's server search: which rows a query keeps.
///
/// Case-insensitive, matching the label the sidebar shows (the agent's live
/// name, else a fallback) and the server's URL — the same two the app filters
/// on (`lib/view/page/server/tab/utils.dart`, `_filterByQuery`). A plain
/// function rather than something inside the component, so the rule is
/// testable apart from a render.

/// Whether [query] keeps a row labelled [label] at [url]. An empty or
/// whitespace-only query keeps everything.
export function serverMatches(query: string, label: string, url: string): boolean {
  const needle = query.trim().toLowerCase()
  if (needle === '') return true
  return label.toLowerCase().includes(needle) || url.toLowerCase().includes(needle)
}
