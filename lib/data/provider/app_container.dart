import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Neutral holder for the app-wide [ProviderContainer] created in `main`.
///
/// Assigned at startup before background services, store reload, or the Agent
/// initialize so non-UI code (such as `StoreReload` and Agent tools) can read
/// the same providers as the widget tree without depending on the AI module.
abstract final class AppContainer {
  static ProviderContainer? _container;

  static ProviderContainer get container => _container!;

  static set container(ProviderContainer c) {
    assert(_container == null, 'set once');
    _container = c;
  }

  /// [container], or null where the app's providers are not up — such as an
  /// isolated widget test that pumps a single page.
  static ProviderContainer? get maybeContainer => _container;
}
