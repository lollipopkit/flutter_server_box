// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_consoles.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Guests' text consoles that are still running with no terminal page showing
/// them, by console id — the ids [SessionKeepAlive] knows them by.
///
/// A text console is a terminal page pushed over the window, and leaving that
/// page used to close its shell. Now the page hands its session here instead
/// ([park]), where [SessionKeepAlive] closes it once it has been left long
/// enough, and the guest's Console view offers it back ([take]) in the
/// meantime. Only one page shows a console at a time: a parked one is taken
/// out before a page is given it, and parked again when that page goes.

@ProviderFor(VirtTextConsoles)
final virtTextConsolesProvider = VirtTextConsolesProvider._();

/// Guests' text consoles that are still running with no terminal page showing
/// them, by console id — the ids [SessionKeepAlive] knows them by.
///
/// A text console is a terminal page pushed over the window, and leaving that
/// page used to close its shell. Now the page hands its session here instead
/// ([park]), where [SessionKeepAlive] closes it once it has been left long
/// enough, and the guest's Console view offers it back ([take]) in the
/// meantime. Only one page shows a console at a time: a parked one is taken
/// out before a page is given it, and parked again when that page goes.
final class VirtTextConsolesProvider
    extends $NotifierProvider<VirtTextConsoles, Set<String>> {
  /// Guests' text consoles that are still running with no terminal page showing
  /// them, by console id — the ids [SessionKeepAlive] knows them by.
  ///
  /// A text console is a terminal page pushed over the window, and leaving that
  /// page used to close its shell. Now the page hands its session here instead
  /// ([park]), where [SessionKeepAlive] closes it once it has been left long
  /// enough, and the guest's Console view offers it back ([take]) in the
  /// meantime. Only one page shows a console at a time: a parked one is taken
  /// out before a page is given it, and parked again when that page goes.
  VirtTextConsolesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'virtTextConsolesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$virtTextConsolesHash();

  @$internal
  @override
  VirtTextConsoles create() => VirtTextConsoles();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$virtTextConsolesHash() => r'0210349e01566334239fa7158f3f9d6fb894f102';

/// Guests' text consoles that are still running with no terminal page showing
/// them, by console id — the ids [SessionKeepAlive] knows them by.
///
/// A text console is a terminal page pushed over the window, and leaving that
/// page used to close its shell. Now the page hands its session here instead
/// ([park]), where [SessionKeepAlive] closes it once it has been left long
/// enough, and the guest's Console view offers it back ([take]) in the
/// meantime. Only one page shows a console at a time: a parked one is taken
/// out before a page is given it, and parked again when that page goes.

abstract class _$VirtTextConsoles extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
