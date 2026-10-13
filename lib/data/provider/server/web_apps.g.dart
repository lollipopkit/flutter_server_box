// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_apps.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The web apps a server's `monitor` agent deployed (its `stacks` feature),
/// read while something shows them.
///
/// Its own [MonitorHttpClient], as the agent's settings page has: the one
/// `ServerNotifier` polls with is that notifier's.

@ProviderFor(WebAppsNotifier)
final webAppsProvider = WebAppsNotifierFamily._();

/// The web apps a server's `monitor` agent deployed (its `stacks` feature),
/// read while something shows them.
///
/// Its own [MonitorHttpClient], as the agent's settings page has: the one
/// `ServerNotifier` polls with is that notifier's.
final class WebAppsNotifierProvider
    extends $NotifierProvider<WebAppsNotifier, WebAppsState> {
  /// The web apps a server's `monitor` agent deployed (its `stacks` feature),
  /// read while something shows them.
  ///
  /// Its own [MonitorHttpClient], as the agent's settings page has: the one
  /// `ServerNotifier` polls with is that notifier's.
  WebAppsNotifierProvider._({
    required WebAppsNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'webAppsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$webAppsNotifierHash();

  @override
  String toString() {
    return r'webAppsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WebAppsNotifier create() => WebAppsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebAppsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebAppsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WebAppsNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$webAppsNotifierHash() => r'65fa4df0d2f760480169244c1c37efd3f028e4a9';

/// The web apps a server's `monitor` agent deployed (its `stacks` feature),
/// read while something shows them.
///
/// Its own [MonitorHttpClient], as the agent's settings page has: the one
/// `ServerNotifier` polls with is that notifier's.

final class WebAppsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          WebAppsNotifier,
          WebAppsState,
          WebAppsState,
          WebAppsState,
          String
        > {
  WebAppsNotifierFamily._()
    : super(
        retry: null,
        name: r'webAppsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The web apps a server's `monitor` agent deployed (its `stacks` feature),
  /// read while something shows them.
  ///
  /// Its own [MonitorHttpClient], as the agent's settings page has: the one
  /// `ServerNotifier` polls with is that notifier's.

  WebAppsNotifierProvider call(String serverId) =>
      WebAppsNotifierProvider._(argument: serverId, from: this);

  @override
  String toString() => r'webAppsProvider';
}

/// The web apps a server's `monitor` agent deployed (its `stacks` feature),
/// read while something shows them.
///
/// Its own [MonitorHttpClient], as the agent's settings page has: the one
/// `ServerNotifier` polls with is that notifier's.

abstract class _$WebAppsNotifier extends $Notifier<WebAppsState> {
  late final _$args = ref.$arg as String;
  String get serverId => _$args;

  WebAppsState build(String serverId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WebAppsState, WebAppsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WebAppsState, WebAppsState>,
              WebAppsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
