// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which Uptimer monitor is open in the Status tab's two-pane detail host,
/// parallel to `serverSelectionProvider` and `bmcSelectionProvider`.

@ProviderFor(UptimerSelection)
final uptimerSelectionProvider = UptimerSelectionProvider._();

/// Which Uptimer monitor is open in the Status tab's two-pane detail host,
/// parallel to `serverSelectionProvider` and `bmcSelectionProvider`.
final class UptimerSelectionProvider
    extends $NotifierProvider<UptimerSelection, int?> {
  /// Which Uptimer monitor is open in the Status tab's two-pane detail host,
  /// parallel to `serverSelectionProvider` and `bmcSelectionProvider`.
  UptimerSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uptimerSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uptimerSelectionHash();

  @$internal
  @override
  UptimerSelection create() => UptimerSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$uptimerSelectionHash() => r'79df563217aec1ff694a592d5ea0ec856bbe360b';

/// Which Uptimer monitor is open in the Status tab's two-pane detail host,
/// parallel to `serverSelectionProvider` and `bmcSelectionProvider`.

abstract class _$UptimerSelection extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
