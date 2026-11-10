// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bmc_credential.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The BMC accounts, as a provider so the picker and the list page see the
/// same set without either of them reloading the other.
///
/// The same shape as [PrivateKeyNotifier], which the accounts are the same kind
/// of record as: named, shared between servers, and edited from two places.

@ProviderFor(BmcCredentialNotifier)
final bmcCredentialProvider = BmcCredentialNotifierProvider._();

/// The BMC accounts, as a provider so the picker and the list page see the
/// same set without either of them reloading the other.
///
/// The same shape as [PrivateKeyNotifier], which the accounts are the same kind
/// of record as: named, shared between servers, and edited from two places.
final class BmcCredentialNotifierProvider
    extends $NotifierProvider<BmcCredentialNotifier, BmcCredentialState> {
  /// The BMC accounts, as a provider so the picker and the list page see the
  /// same set without either of them reloading the other.
  ///
  /// The same shape as [PrivateKeyNotifier], which the accounts are the same kind
  /// of record as: named, shared between servers, and edited from two places.
  BmcCredentialNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bmcCredentialProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bmcCredentialNotifierHash();

  @$internal
  @override
  BmcCredentialNotifier create() => BmcCredentialNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BmcCredentialState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BmcCredentialState>(value),
    );
  }
}

String _$bmcCredentialNotifierHash() =>
    r'12fb97084a3265cf0e1bfd4860dfdb3d60da153a';

/// The BMC accounts, as a provider so the picker and the list page see the
/// same set without either of them reloading the other.
///
/// The same shape as [PrivateKeyNotifier], which the accounts are the same kind
/// of record as: named, shared between servers, and edited from two places.

abstract class _$BmcCredentialNotifier extends $Notifier<BmcCredentialState> {
  BmcCredentialState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BmcCredentialState, BmcCredentialState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BmcCredentialState, BmcCredentialState>,
              BmcCredentialState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
