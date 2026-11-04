// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virtual_keyboard.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VirtualKeyboard)
final virtualKeyboardProvider = VirtualKeyboardProvider._();

final class VirtualKeyboardProvider
    extends $NotifierProvider<VirtualKeyboard, VirtKeyState> {
  VirtualKeyboardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'virtualKeyboardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$virtualKeyboardHash();

  @$internal
  @override
  VirtualKeyboard create() => VirtualKeyboard();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VirtKeyState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VirtKeyState>(value),
    );
  }
}

String _$virtualKeyboardHash() => r'b076d97b36548d59db68183c64c4163e4844604e';

abstract class _$VirtualKeyboard extends $Notifier<VirtKeyState> {
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
