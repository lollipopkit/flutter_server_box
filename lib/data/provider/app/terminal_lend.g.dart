// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_lend.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The terminal tab's running shells, published for a panel elsewhere that
/// shows one of them rather than starting another.
///
/// Only those with a session: a tab restored but never looked at has not
/// connected, and there is nothing in it to show.

@ProviderFor(OpenTerminals)
final openTerminalsProvider = OpenTerminalsProvider._();

/// The terminal tab's running shells, published for a panel elsewhere that
/// shows one of them rather than starting another.
///
/// Only those with a session: a tab restored but never looked at has not
/// connected, and there is nothing in it to show.
final class OpenTerminalsProvider
    extends $NotifierProvider<OpenTerminals, List<OpenTerminal>> {
  /// The terminal tab's running shells, published for a panel elsewhere that
  /// shows one of them rather than starting another.
  ///
  /// Only those with a session: a tab restored but never looked at has not
  /// connected, and there is nothing in it to show.
  OpenTerminalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openTerminalsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openTerminalsHash();

  @$internal
  @override
  OpenTerminals create() => OpenTerminals();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<OpenTerminal> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<OpenTerminal>>(value),
    );
  }
}

String _$openTerminalsHash() => r'9d148d2f4f57f7a2c7416aada6c8b0bdde25acd1';

/// The terminal tab's running shells, published for a panel elsewhere that
/// shows one of them rather than starting another.
///
/// Only those with a session: a tab restored but never looked at has not
/// connected, and there is nothing in it to show.

abstract class _$OpenTerminals extends $Notifier<List<OpenTerminal>> {
  List<OpenTerminal> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<OpenTerminal>, List<OpenTerminal>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<OpenTerminal>, List<OpenTerminal>>,
              List<OpenTerminal>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The terminal a companion panel is drawing, which its tab then does not.
///
/// The reason is [FloatingTerminal]'s: two views of one terminal each resize
/// it to themselves. One at a time, because a panel lends only while it is on
/// screen.

@ProviderFor(LentTerminal)
final lentTerminalProvider = LentTerminalProvider._();

/// The terminal a companion panel is drawing, which its tab then does not.
///
/// The reason is [FloatingTerminal]'s: two views of one terminal each resize
/// it to themselves. One at a time, because a panel lends only while it is on
/// screen.
final class LentTerminalProvider
    extends $NotifierProvider<LentTerminal, TerminalLend?> {
  /// The terminal a companion panel is drawing, which its tab then does not.
  ///
  /// The reason is [FloatingTerminal]'s: two views of one terminal each resize
  /// it to themselves. One at a time, because a panel lends only while it is on
  /// screen.
  LentTerminalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lentTerminalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lentTerminalHash();

  @$internal
  @override
  LentTerminal create() => LentTerminal();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TerminalLend? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TerminalLend?>(value),
    );
  }
}

String _$lentTerminalHash() => r'e53c92b260005de5bfcbb5bbf0c3bd25969d2d33';

/// The terminal a companion panel is drawing, which its tab then does not.
///
/// The reason is [FloatingTerminal]'s: two views of one terminal each resize
/// it to themselves. One at a time, because a panel lends only while it is on
/// screen.

abstract class _$LentTerminal extends $Notifier<TerminalLend?> {
  TerminalLend? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TerminalLend?, TerminalLend?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TerminalLend?, TerminalLend?>,
              TerminalLend?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
