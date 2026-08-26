// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snippet.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SnippetNotifier)
final snippetProvider = SnippetNotifierProvider._();

final class SnippetNotifierProvider
    extends $NotifierProvider<SnippetNotifier, SnippetState> {
  SnippetNotifierProvider._()
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

String _$snippetNotifierHash() => r'78e9a16b99b64b870a0309b7d9e6a5de99475c85';

abstract class _$SnippetNotifier extends $Notifier<SnippetState> {
  SnippetState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SnippetState, SnippetState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SnippetState, SnippetState>,
              SnippetState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
