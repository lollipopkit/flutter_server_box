// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virtual_keyboard.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VirtKeyboard)
final virtKeyboardProvider = VirtKeyboardProvider._();

final class VirtKeyboardProvider
    extends $NotifierProvider<VirtKeyboard, VirtKeyState> {
  VirtKeyboardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'virtKeyboardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$virtKeyboardHash();

  @$internal
  @override
  VirtKeyboard create() => VirtKeyboard();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VirtKeyState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VirtKeyState>(value),
    );
  }
}

String _$virtKeyboardHash() => r'f8012f7bdf41d9a6a57b93c443cf0f5cab9e0baa';

abstract class _$VirtKeyboard extends $Notifier<VirtKeyState> {
  VirtKeyState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VirtKeyState, VirtKeyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VirtKeyState, VirtKeyState>,
              VirtKeyState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
