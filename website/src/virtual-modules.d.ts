/**
 * The plugins page's data, built by `pluginCatalog` in `vite.config.js` out of
 * `packages/plugins/*/manifest.json`.
 *
 * Declared here because a virtual module has no file for an editor to look at.
 * The shape is the one that plugin builds — keep the two together.
 */
declare module 'virtual:plugin-catalog' {
  export interface PluginCatalogEntry {
    /** The directory under `packages/plugins`, for the source link. */
    dir: string
    id: string
    name: string
    description: string
    version: string
    abi: number
    license?: string
    /** Locales the package ships translations for. */
    locales: string[]
    /** Permission names, as the app's install dialog shows them. */
    permissions: string[]
    /** Which of the app's surfaces it contributes to. */
    surfaces: string[]
  }

  const catalog: PluginCatalogEntry[]
  export default catalog
}
