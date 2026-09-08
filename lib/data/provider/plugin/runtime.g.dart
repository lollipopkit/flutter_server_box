// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's one runtime, wired to the app's own way of doing things.
///
/// `keepAlive`, because it owns native threads and two request streams: a
/// runtime that came and went with a widget would leave an instance running
/// with nothing reading what it asks for.

@ProviderFor(pluginRuntime)
final pluginRuntimeProvider = PluginRuntimeProvider._();

/// The app's one runtime, wired to the app's own way of doing things.
///
/// `keepAlive`, because it owns native threads and two request streams: a
/// runtime that came and went with a widget would leave an instance running
/// with nothing reading what it asks for.

final class PluginRuntimeProvider
    extends
        $FunctionalProvider<
          PluginRuntimeService,
          PluginRuntimeService,
          PluginRuntimeService
        >
    with $Provider<PluginRuntimeService> {
  /// The app's one runtime, wired to the app's own way of doing things.
  ///
  /// `keepAlive`, because it owns native threads and two request streams: a
  /// runtime that came and went with a widget would leave an instance running
  /// with nothing reading what it asks for.
  PluginRuntimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pluginRuntimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pluginRuntimeHash();

  @$internal
  @override
  $ProviderElement<PluginRuntimeService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PluginRuntimeService create(Ref ref) {
    return pluginRuntime(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PluginRuntimeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PluginRuntimeService>(value),
    );
  }
}

String _$pluginRuntimeHash() => r'b487cfd0ecfb0999f4f653fed2eda9ad9af18703';
