// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snippet.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SnippetNotifier)
const snippetProvider = SnippetNotifierProvider._();

final class SnippetNotifierProvider
    extends $NotifierProvider<SnippetNotifier, SnippetState> {
  const SnippetNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'snippetProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$snippetNotifierHash();

  @$internal
  @override
  SnippetNotifier create() => SnippetNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SnippetState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SnippetState>(value),
    );
  }
}

String _$snippetNotifierHash() => r'7f5bc473ced25b489bc84477de5c6fbd18af6e34';

abstract class _$SnippetNotifier extends $Notifier<SnippetState> {
  SnippetState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SnippetState, SnippetState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SnippetState, SnippetState>,
              SnippetState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
