// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sftp.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SftpNotifier)
const sftpProvider = SftpNotifierProvider._();

final class SftpNotifierProvider
    extends $NotifierProvider<SftpNotifier, SftpState> {
  const SftpNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sftpProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sftpNotifierHash();

  @$internal
  @override
  SftpNotifier create() => SftpNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SftpState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SftpState>(value),
    );
  }
}

String _$sftpNotifierHash() => r'f8412a4bd1f2bc5919ec31a3eba1c27e9a578f41';

abstract class _$SftpNotifier extends $Notifier<SftpState> {
  SftpState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SftpState, SftpState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SftpState, SftpState>,
              SftpState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
