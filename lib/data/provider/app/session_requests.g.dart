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
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppTab?, AppTab?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppTab?, AppTab?>,
              AppTab?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Which tab is on screen right now.
///
/// [HomeTabRequest] is where something asks to be taken; this is where the
/// home page says where it ended up. The floating Agent needs it to stay out
/// of the way of the Agent tab, which is the better view of the same thing
/// whenever it is the one being looked at.

@ProviderFor(CurrentHomeTab)
final currentHomeTabProvider = CurrentHomeTabProvider._();

/// Which tab is on screen right now.
///
/// [HomeTabRequest] is where something asks to be taken; this is where the
/// home page says where it ended up. The floating Agent needs it to stay out
/// of the way of the Agent tab, which is the better view of the same thing
/// whenever it is the one being looked at.
final class CurrentHomeTabProvider
    extends $NotifierProvider<CurrentHomeTab, AppTab?> {
  /// Which tab is on screen right now.
  ///
  /// [HomeTabRequest] is where something asks to be taken; this is where the
  /// home page says where it ended up. The floating Agent needs it to stay out
  /// of the way of the Agent tab, which is the better view of the same thing
  /// whenever it is the one being looked at.
  CurrentHomeTabProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentHomeTabProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentHomeTabHash();

  @$internal
  @override
  CurrentHomeTab create() => CurrentHomeTab();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppTab? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppTab?>(value),
    );
  }
}

String _$currentHomeTabHash() => r'af235edea49c8cf180a96ad5f182d2c18aaf6fe2';

/// Which tab is on screen right now.
///
/// [HomeTabRequest] is where something asks to be taken; this is where the
/// home page says where it ended up. The floating Agent needs it to stay out
/// of the way of the Agent tab, which is the better view of the same thing
/// whenever it is the one being looked at.

abstract class _$CurrentHomeTab extends $Notifier<AppTab?> {
  AppTab? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppTab?, AppTab?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppTab?, AppTab?>,
              AppTab?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The tab that is drawing something the window's chrome is in the way of.
///
/// One thing sets it: the globe. A sphere fills the column it is given, and the
/// bar over it and the navigation under it are two rows of controls around a
/// picture that *is* the page — so while it is up the tab takes the window and
/// carries its own way out.
///
/// Which tab rather than a bare flag, because a tab is kept alive behind the
/// others: the server tab goes on drawing a globe while somebody reads a
/// terminal, and the chrome has to be back for that one.

@ProviderFor(ImmersiveTab)
final immersiveTabProvider = ImmersiveTabProvider._();

/// The tab that is drawing something the window's chrome is in the way of.
///
/// One thing sets it: the globe. A sphere fills the column it is given, and the
/// bar over it and the navigation under it are two rows of controls around a
/// picture that *is* the page — so while it is up the tab takes the window and
/// carries its own way out.
///
/// Which tab rather than a bare flag, because a tab is kept alive behind the
/// others: the server tab goes on drawing a globe while somebody reads a
/// terminal, and the chrome has to be back for that one.
final class ImmersiveTabProvider
    extends $NotifierProvider<ImmersiveTab, AppTab?> {
  /// The tab that is drawing something the window's chrome is in the way of.
  ///
  /// One thing sets it: the globe. A sphere fills the column it is given, and the
  /// bar over it and the navigation under it are two rows of controls around a
  /// picture that *is* the page — so while it is up the tab takes the window and
  /// carries its own way out.
  ///
  /// Which tab rather than a bare flag, because a tab is kept alive behind the
  /// others: the server tab goes on drawing a globe while somebody reads a
  /// terminal, and the chrome has to be back for that one.
  ImmersiveTabProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'immersiveTabProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$immersiveTabHash();

  @$internal
  @override
  ImmersiveTab create() => ImmersiveTab();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppTab? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppTab?>(value),
    );
  }
}

String _$immersiveTabHash() => r'ab35284389168023d991281a62a018147269ca3d';

/// The tab that is drawing something the window's chrome is in the way of.
///
/// One thing sets it: the globe. A sphere fills the column it is given, and the
/// bar over it and the navigation under it are two rows of controls around a
/// picture that *is* the page — so while it is up the tab takes the window and
/// carries its own way out.
///
/// Which tab rather than a bare flag, because a tab is kept alive behind the
/// others: the server tab goes on drawing a globe while somebody reads a
/// terminal, and the chrome has to be back for that one.

abstract class _$ImmersiveTab extends $Notifier<AppTab?> {
  AppTab? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppTab?, AppTab?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppTab?, AppTab?>,
              AppTab?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A server waiting to be opened on the server tab.
///
/// A request rather than a call for two reasons. The tab may not exist yet —
/// tabs are built when first visited — and only the tab knows whether opening
/// something means selecting it beside the list or pushing a page over it.
///
/// One slot rather than a queue, unlike [TerminalRequests]: opening two
/// servers in a row means looking at the second one, not at both.

@ProviderFor(ServerDetailRequest)
final serverDetailRequestProvider = ServerDetailRequestProvider._();

/// A server waiting to be opened on the server tab.
///
/// A request rather than a call for two reasons. The tab may not exist yet —
/// tabs are built when first visited — and only the tab knows whether opening
/// something means selecting it beside the list or pushing a page over it.
///
/// One slot rather than a queue, unlike [TerminalRequests]: opening two
/// servers in a row means looking at the second one, not at both.
final class ServerDetailRequestProvider
    extends $NotifierProvider<ServerDetailRequest, String?> {
  /// A server waiting to be opened on the server tab.
  ///
  /// A request rather than a call for two reasons. The tab may not exist yet —
  /// tabs are built when first visited — and only the tab knows whether opening
  /// something means selecting it beside the list or pushing a page over it.
  ///
  /// One slot rather than a queue, unlike [TerminalRequests]: opening two
  /// servers in a row means looking at the second one, not at both.
  ServerDetailRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverDetailRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverDetailRequestHash();

  @$internal
  @override
  ServerDetailRequest create() => ServerDetailRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$serverDetailRequestHash() =>
    r'c0434cde59f389fa9ffa2f6054adf07b2f9244e5';

/// A server waiting to be opened on the server tab.
///
/// A request rather than a call for two reasons. The tab may not exist yet —
/// tabs are built when first visited — and only the tab knows whether opening
/// something means selecting it beside the list or pushing a page over it.
///
/// One slot rather than a queue, unlike [TerminalRequests]: opening two
/// servers in a row means looking at the second one, not at both.

abstract class _$ServerDetailRequest extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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

String _$terminalRequestsHash() => r'50a3481c89293e718f336933ead05f6b85053759';

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
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<TerminalRequest>, List<TerminalRequest>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<TerminalRequest>, List<TerminalRequest>>,
              List<TerminalRequest>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A standing request to close every terminal.
///
/// The tab that owns the sessions is the only thing that can close them, and
/// it is built when first visited — so this is a flag it drains, the same
/// arrangement [TerminalRequests] has, rather than a call. A request left
/// standing because that tab has never been built closes nothing when it
/// finally is, which is right: a tab nobody has opened has no sessions.

@ProviderFor(TerminalCloseAllRequest)
final terminalCloseAllRequestProvider = TerminalCloseAllRequestProvider._();

/// A standing request to close every terminal.
///
/// The tab that owns the sessions is the only thing that can close them, and
/// it is built when first visited — so this is a flag it drains, the same
/// arrangement [TerminalRequests] has, rather than a call. A request left
/// standing because that tab has never been built closes nothing when it
/// finally is, which is right: a tab nobody has opened has no sessions.
final class TerminalCloseAllRequestProvider
    extends $NotifierProvider<TerminalCloseAllRequest, bool> {
  /// A standing request to close every terminal.
  ///
  /// The tab that owns the sessions is the only thing that can close them, and
  /// it is built when first visited — so this is a flag it drains, the same
  /// arrangement [TerminalRequests] has, rather than a call. A request left
  /// standing because that tab has never been built closes nothing when it
  /// finally is, which is right: a tab nobody has opened has no sessions.
  TerminalCloseAllRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'terminalCloseAllRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$terminalCloseAllRequestHash();

  @$internal
  @override
  TerminalCloseAllRequest create() => TerminalCloseAllRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$terminalCloseAllRequestHash() =>
    r'2cf3ab0878b0e36015786c6f2675a9a98fde5b9a';

/// A standing request to close every terminal.
///
/// The tab that owns the sessions is the only thing that can close them, and
/// it is built when first visited — so this is a flag it drains, the same
/// arrangement [TerminalRequests] has, rather than a call. A request left
/// standing because that tab has never been built closes nothing when it
/// finally is, which is right: a tab nobody has opened has no sessions.

abstract class _$TerminalCloseAllRequest extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Spi>, List<Spi>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Spi>, List<Spi>>,
              List<Spi>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
