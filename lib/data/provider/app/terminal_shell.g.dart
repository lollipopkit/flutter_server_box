// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_shell.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which terminal is floating, if any.
///
/// Unlike the Agent's, this cannot be restored on the next launch: an Agent
/// conversation is stored and a shell is a connection, so there is nothing for
/// a relaunch to put back in the window. What does persist is how the window
/// was left — its size, where it was dragged, and whether it was collapsed —
/// which is what [FloatShellGeometry] keeps.

@ProviderFor(TerminalShell)
final terminalShellProvider = TerminalShellProvider._();

/// Which terminal is floating, if any.
///
/// Unlike the Agent's, this cannot be restored on the next launch: an Agent
/// conversation is stored and a shell is a connection, so there is nothing for
/// a relaunch to put back in the window. What does persist is how the window
/// was left — its size, where it was dragged, and whether it was collapsed —
/// which is what [FloatShellGeometry] keeps.
final class TerminalShellProvider
    extends $NotifierProvider<TerminalShell, FloatingTerminal?> {
  /// Which terminal is floating, if any.
  ///
  /// Unlike the Agent's, this cannot be restored on the next launch: an Agent
  /// conversation is stored and a shell is a connection, so there is nothing for
  /// a relaunch to put back in the window. What does persist is how the window
  /// was left — its size, where it was dragged, and whether it was collapsed —
  /// which is what [FloatShellGeometry] keeps.
  TerminalShellProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'terminalShellProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$terminalShellHash();

  @$internal
  @override
  TerminalShell create() => TerminalShell();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FloatingTerminal? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FloatingTerminal?>(value),
    );
  }
}

String _$terminalShellHash() => r'c65bedb82cce9d9d6455db7fd66993452d68f7a9';

/// Which terminal is floating, if any.
///
/// Unlike the Agent's, this cannot be restored on the next launch: an Agent
/// conversation is stored and a shell is a connection, so there is nothing for
/// a relaunch to put back in the window. What does persist is how the window
/// was left — its size, where it was dragged, and whether it was collapsed —
/// which is what [FloatShellGeometry] keeps.

abstract class _$TerminalShell extends $Notifier<FloatingTerminal?> {
  FloatingTerminal? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FloatingTerminal?, FloatingTerminal?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FloatingTerminal?, FloatingTerminal?>,
              FloatingTerminal?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
