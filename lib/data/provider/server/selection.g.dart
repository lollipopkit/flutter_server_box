// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which server the detail pane is showing.
///
/// State rather than a route argument, because in the two-pane layout it has
/// to outlive the pane's contents: the list highlights it, the pane renders
/// it, and a page pushed inside the pane replaces neither. In the single-pane
/// layout nothing reads it — there the pushed route still carries the answer,
/// which is why one call site can serve both.
///
/// Keyed the same way as `serverProvider`, so the two never disagree about
/// what identifies a server.

@ProviderFor(ServerSelection)
final serverSelectionProvider = ServerSelectionProvider._();

/// Which server the detail pane is showing.
///
/// State rather than a route argument, because in the two-pane layout it has
/// to outlive the pane's contents: the list highlights it, the pane renders
/// it, and a page pushed inside the pane replaces neither. In the single-pane
/// layout nothing reads it — there the pushed route still carries the answer,
/// which is why one call site can serve both.
///
/// Keyed the same way as `serverProvider`, so the two never disagree about
/// what identifies a server.
final class ServerSelectionProvider
    extends $NotifierProvider<ServerSelection, String?> {
  /// Which server the detail pane is showing.
  ///
  /// State rather than a route argument, because in the two-pane layout it has
  /// to outlive the pane's contents: the list highlights it, the pane renders
  /// it, and a page pushed inside the pane replaces neither. In the single-pane
  /// layout nothing reads it — there the pushed route still carries the answer,
  /// which is why one call site can serve both.
  ///
  /// Keyed the same way as `serverProvider`, so the two never disagree about
  /// what identifies a server.
  ServerSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverSelectionHash();

  @$internal
  @override
  ServerSelection create() => ServerSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$serverSelectionHash() => r'6249701f0492994837b537d73d24a52064923b2b';

/// Which server the detail pane is showing.
///
/// State rather than a route argument, because in the two-pane layout it has
/// to outlive the pane's contents: the list highlights it, the pane renders
/// it, and a page pushed inside the pane replaces neither. In the single-pane
/// layout nothing reads it — there the pushed route still carries the answer,
/// which is why one call site can serve both.
///
/// Keyed the same way as `serverProvider`, so the two never disagree about
/// what identifies a server.

abstract class _$ServerSelection extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
