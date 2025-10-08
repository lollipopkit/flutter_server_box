// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virtual_keyboard.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VirtKeyboard)
const virtKeyboardProvider = VirtKeyboardProvider._();

final class VirtKeyboardProvider
    extends $NotifierProvider<VirtKeyboard, VirtKeyState> {
  const VirtKeyboardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'virtKeyboardProvider',
        isAutoDispose: true,
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

String _$virtKeyboardHash() => r'1327d412bfb0dd261f3b555f353a8852b4f753e5';

abstract class _$VirtKeyboard extends $Notifier<VirtKeyState> {
  VirtKeyState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<VirtKeyState, VirtKeyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VirtKeyState, VirtKeyState>,
              VirtKeyState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
