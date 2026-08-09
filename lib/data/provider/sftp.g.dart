// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sftp.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SftpNotifier)
final sftpProvider = SftpNotifierProvider._();

final class SftpNotifierProvider
    extends $NotifierProvider<SftpNotifier, SftpState> {
  SftpNotifierProvider._()
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

String _$sftpNotifierHash() => r'fe9d15cbc19c2808bce35c9a63a2ccae397de37b';

abstract class _$SftpNotifier extends $Notifier<SftpState> {
  SftpState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SftpState, SftpState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SftpState, SftpState>,
              SftpState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
