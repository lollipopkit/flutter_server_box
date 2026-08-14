// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adhoc_ssh.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every host the Agent has open that is not a configured server.
///
/// In memory only. Nothing here is written to storage, so a restart ends every
/// one of them — which is also why a `session_id` from a restored conversation
/// resolves to nothing rather than to somebody else's connection.

@ProviderFor(AdHocSshSessions)
final adHocSshSessionsProvider = AdHocSshSessionsProvider._();

/// Every host the Agent has open that is not a configured server.
///
/// In memory only. Nothing here is written to storage, so a restart ends every
/// one of them — which is also why a `session_id` from a restored conversation
/// resolves to nothing rather than to somebody else's connection.
final class AdHocSshSessionsProvider
    extends $NotifierProvider<AdHocSshSessions, Map<String, AdHocSshSession>> {
  /// Every host the Agent has open that is not a configured server.
  ///
  /// In memory only. Nothing here is written to storage, so a restart ends every
  /// one of them — which is also why a `session_id` from a restored conversation
  /// resolves to nothing rather than to somebody else's connection.
  AdHocSshSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adHocSshSessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adHocSshSessionsHash();

  @$internal
  @override
  AdHocSshSessions create() => AdHocSshSessions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, AdHocSshSession> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, AdHocSshSession>>(value),
    );
  }
}

String _$adHocSshSessionsHash() => r'd2b929a31300d4d5bbfde61bf66932171c82d2ea';

/// Every host the Agent has open that is not a configured server.
///
/// In memory only. Nothing here is written to storage, so a restart ends every
/// one of them — which is also why a `session_id` from a restored conversation
/// resolves to nothing rather than to somebody else's connection.

abstract class _$AdHocSshSessions
    extends $Notifier<Map<String, AdHocSshSession>> {
  Map<String, AdHocSshSession> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<Map<String, AdHocSshSession>, Map<String, AdHocSshSession>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, AdHocSshSession>,
                Map<String, AdHocSshSession>
              >,
              Map<String, AdHocSshSession>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
