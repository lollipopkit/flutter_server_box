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

String _$snippetNotifierHash() => r'5684ddb4bcc1e5d951c2082fb211509224c552eb';

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
