/// Tells whoever reads the stores a restore or a sync just rewrote to read
/// them again.
typedef StoreReloader =
    void Function({bool servers, bool snippets, bool keys, bool bmcCredentials, bool containers});

/// Said by the layer that wrote the stores; done by the providers, which
/// install [after] at start (`installStoreReload`), so a store never imports
/// them. Until then, as in a test without the app, nothing reloads.
abstract final class StoreReload {
  static StoreReloader after = _none;

  static void _none({
    bool servers = false,
    bool snippets = false,
    bool keys = false,
    bool bmcCredentials = false,
    bool containers = false,
  }) {}
}
