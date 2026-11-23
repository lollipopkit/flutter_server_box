// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which standalone BMC target is open in the Status tab's two-pane detail
/// host, parallel to `serverSelectionProvider`.

@ProviderFor(BmcSelection)
final bmcSelectionProvider = BmcSelectionProvider._();

/// Which standalone BMC target is open in the Status tab's two-pane detail
/// host, parallel to `serverSelectionProvider`.
final class BmcSelectionProvider
    extends $NotifierProvider<BmcSelection, String?> {
  /// Which standalone BMC target is open in the Status tab's two-pane detail
  /// host, parallel to `serverSelectionProvider`.
  BmcSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bmcSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bmcSelectionHash();

  @$internal
  @override
  BmcSelection create() => BmcSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$bmcSelectionHash() => r'1b036df7908b43e4ad897859e5d16c021d6c3dd8';

/// Which standalone BMC target is open in the Status tab's two-pane detail
/// host, parallel to `serverSelectionProvider`.

abstract class _$BmcSelection extends $Notifier<String?> {
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
