// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uptimer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the signed-in LK Cloud user's Uptimer monitors, periodic polling,
/// and CRUD mutations.

@ProviderFor(Uptimer)
final uptimerProvider = UptimerProvider._();

/// Manages the signed-in LK Cloud user's Uptimer monitors, periodic polling,
/// and CRUD mutations.
final class UptimerProvider extends $NotifierProvider<Uptimer, UptimerState> {
  /// Manages the signed-in LK Cloud user's Uptimer monitors, periodic polling,
  /// and CRUD mutations.
  UptimerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uptimerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uptimerHash();

  @$internal
  @override
  Uptimer create() => Uptimer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UptimerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UptimerState>(value),
    );
  }
}

String _$uptimerHash() => r'30674a8c9a7ae2153f429851f2756bf54249b2da';

/// Manages the signed-in LK Cloud user's Uptimer monitors, periodic polling,
/// and CRUD mutations.

abstract class _$Uptimer extends $Notifier<UptimerState> {
  UptimerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UptimerState, UptimerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UptimerState, UptimerState>,
              UptimerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
