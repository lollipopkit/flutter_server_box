// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keybindings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The keyboard shortcuts, as changed on the settings page.

@ProviderFor(Keybindings)
final keybindingsProvider = KeybindingsProvider._();

/// The keyboard shortcuts, as changed on the settings page.
final class KeybindingsProvider
    extends $NotifierProvider<Keybindings, KbState> {
  /// The keyboard shortcuts, as changed on the settings page.
  KeybindingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'keybindingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keybindingsHash();

  @$internal
  @override
  Keybindings create() => Keybindings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KbState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KbState>(value),
    );
  }
}

String _$keybindingsHash() => r'c2da45c69f6ad478629fdaff4a6187366d074b66';

/// The keyboard shortcuts, as changed on the settings page.

abstract class _$Keybindings extends $Notifier<KbState> {
  KbState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<KbState, KbState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<KbState, KbState>,
              KbState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
