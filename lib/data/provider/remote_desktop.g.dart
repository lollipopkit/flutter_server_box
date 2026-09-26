// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_desktop.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RemoteDesktopProfiles)
final remoteDesktopProfilesProvider = RemoteDesktopProfilesFamily._();

final class RemoteDesktopProfilesProvider
    extends
        $NotifierProvider<RemoteDesktopProfiles, List<RemoteDesktopProfile>> {
  RemoteDesktopProfilesProvider._({
    required RemoteDesktopProfilesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'remoteDesktopProfilesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$remoteDesktopProfilesHash();

  @override
  String toString() {
    return r'remoteDesktopProfilesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RemoteDesktopProfiles create() => RemoteDesktopProfiles();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<RemoteDesktopProfile> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<RemoteDesktopProfile>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RemoteDesktopProfilesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$remoteDesktopProfilesHash() =>
    r'60252e694b7cbf5ac6bfcf9cf6b94601eed88599';

final class RemoteDesktopProfilesFamily extends $Family
    with
        $ClassFamilyOverride<
          RemoteDesktopProfiles,
          List<RemoteDesktopProfile>,
          List<RemoteDesktopProfile>,
          List<RemoteDesktopProfile>,
          String
        > {
  RemoteDesktopProfilesFamily._()
    : super(
        retry: null,
        name: r'remoteDesktopProfilesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  RemoteDesktopProfilesProvider call(String serverId) =>
      RemoteDesktopProfilesProvider._(argument: serverId, from: this);

  @override
  String toString() => r'remoteDesktopProfilesProvider';
}

abstract class _$RemoteDesktopProfiles
    extends $Notifier<List<RemoteDesktopProfile>> {
  late final _$args = ref.$arg as String;
  String get serverId => _$args;

  List<RemoteDesktopProfile> build(String serverId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<List<RemoteDesktopProfile>, List<RemoteDesktopProfile>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                List<RemoteDesktopProfile>,
                List<RemoteDesktopProfile>
              >,
              List<RemoteDesktopProfile>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Every remote desktop session there is — the remote desktop tab's and the
/// consoles other pages show — and their connections.
///
/// A session off screen is not closed here: each is registered with
/// [SessionKeepAlive], told whenever it comes on or goes off screen, and
/// closed through [close] when that decides it has been left long enough.

@ProviderFor(RemoteDesktopSessions)
final remoteDesktopSessionsProvider = RemoteDesktopSessionsProvider._();

/// Every remote desktop session there is — the remote desktop tab's and the
/// consoles other pages show — and their connections.
///
/// A session off screen is not closed here: each is registered with
/// [SessionKeepAlive], told whenever it comes on or goes off screen, and
/// closed through [close] when that decides it has been left long enough.
final class RemoteDesktopSessionsProvider
    extends
        $NotifierProvider<RemoteDesktopSessions, RemoteDesktopSessionsState> {
  /// Every remote desktop session there is — the remote desktop tab's and the
  /// consoles other pages show — and their connections.
  ///
  /// A session off screen is not closed here: each is registered with
  /// [SessionKeepAlive], told whenever it comes on or goes off screen, and
  /// closed through [close] when that decides it has been left long enough.
  RemoteDesktopSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteDesktopSessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteDesktopSessionsHash();

  @$internal
  @override
  RemoteDesktopSessions create() => RemoteDesktopSessions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteDesktopSessionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteDesktopSessionsState>(value),
    );
  }
}

String _$remoteDesktopSessionsHash() =>
    r'60e022fc59703c69c3608d3f434bd396a6e7f458';

/// Every remote desktop session there is — the remote desktop tab's and the
/// consoles other pages show — and their connections.
///
/// A session off screen is not closed here: each is registered with
/// [SessionKeepAlive], told whenever it comes on or goes off screen, and
/// closed through [close] when that decides it has been left long enough.

abstract class _$RemoteDesktopSessions
    extends $Notifier<RemoteDesktopSessionsState> {
  RemoteDesktopSessionsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<RemoteDesktopSessionsState, RemoteDesktopSessionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                RemoteDesktopSessionsState,
                RemoteDesktopSessionsState
              >,
              RemoteDesktopSessionsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
