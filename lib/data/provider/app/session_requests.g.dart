// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_requests.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which tab the app should be showing.
///
/// Set by anything that opens something living in a tab, and cleared by the
/// home page once it has moved. A request rather than a command because the
/// home page owns its page controller and the animation that goes with it.

@ProviderFor(HomeTabRequest)
final homeTabRequestProvider = HomeTabRequestProvider._();

/// Which tab the app should be showing.
///
/// Set by anything that opens something living in a tab, and cleared by the
/// home page once it has moved. A request rather than a command because the
/// home page owns its page controller and the animation that goes with it.
final class HomeTabRequestProvider
    extends $NotifierProvider<HomeTabRequest, AppTab?> {
  /// Which tab the app should be showing.
  ///
  /// Set by anything that opens something living in a tab, and cleared by the
  /// home page once it has moved. A request rather than a command because the
  /// home page owns its page controller and the animation that goes with it.
  HomeTabRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeTabRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeTabRequestHash();

  @$internal
  @override
  HomeTabRequest create() => HomeTabRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppTab? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppTab?>(value),
    );
  }
}

String _$homeTabRequestHash() => r'15b255ea94725952546f0e153b23660ef8cb1756';

/// Which tab the app should be showing.
///
/// Set by anything that opens something living in a tab, and cleared by the
/// home page once it has moved. A request rather than a command because the
/// home page owns its page controller and the animation that goes with it.

abstract class _$HomeTabRequest extends $Notifier<AppTab?> {
  AppTab? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AppTab?, AppTab?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppTab?, AppTab?>,
              AppTab?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Servers waiting for a terminal.
///
/// A queue rather than a direct call because the tab that opens terminals may
/// not exist yet: tabs are built when first visited, so a request made from
/// the server list arrives before there is anything to receive it. The tab
/// drains this when it appears.

@ProviderFor(TerminalRequests)
final terminalRequestsProvider = TerminalRequestsProvider._();

/// Servers waiting for a terminal.
///
/// A queue rather than a direct call because the tab that opens terminals may
/// not exist yet: tabs are built when first visited, so a request made from
/// the server list arrives before there is anything to receive it. The tab
/// drains this when it appears.
final class TerminalRequestsProvider
    extends $NotifierProvider<TerminalRequests, List<TerminalRequest>> {
  /// Servers waiting for a terminal.
  ///
  /// A queue rather than a direct call because the tab that opens terminals may
  /// not exist yet: tabs are built when first visited, so a request made from
  /// the server list arrives before there is anything to receive it. The tab
  /// drains this when it appears.
  TerminalRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'terminalRequestsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$terminalRequestsHash();

  @$internal
  @override
  TerminalRequests create() => TerminalRequests();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TerminalRequest> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TerminalRequest>>(value),
    );
  }
}

String _$terminalRequestsHash() => r'6795dc525731a8b27f51ec5240fde7efa5adcc0e';

/// Servers waiting for a terminal.
///
/// A queue rather than a direct call because the tab that opens terminals may
/// not exist yet: tabs are built when first visited, so a request made from
/// the server list arrives before there is anything to receive it. The tab
/// drains this when it appears.

abstract class _$TerminalRequests extends $Notifier<List<TerminalRequest>> {
  List<TerminalRequest> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<TerminalRequest>, List<TerminalRequest>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<TerminalRequest>, List<TerminalRequest>>,
              List<TerminalRequest>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Servers waiting for a file browser. Same reasoning as [TerminalRequests].

@ProviderFor(SftpRequests)
final sftpRequestsProvider = SftpRequestsProvider._();

/// Servers waiting for a file browser. Same reasoning as [TerminalRequests].
final class SftpRequestsProvider
    extends $NotifierProvider<SftpRequests, List<Spi>> {
  /// Servers waiting for a file browser. Same reasoning as [TerminalRequests].
  SftpRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sftpRequestsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sftpRequestsHash();

  @$internal
  @override
  SftpRequests create() => SftpRequests();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Spi> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Spi>>(value),
    );
  }
}

String _$sftpRequestsHash() => r'15729dc4f93d09dbc2bd0732e4fbeace921c7b50';

/// Servers waiting for a file browser. Same reasoning as [TerminalRequests].

abstract class _$SftpRequests extends $Notifier<List<Spi>> {
  List<Spi> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<Spi>, List<Spi>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Spi>, List<Spi>>,
              List<Spi>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
