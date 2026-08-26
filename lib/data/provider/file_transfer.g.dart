// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_transfer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every transfer this app has been asked to run, wherever its two ends are.

@ProviderFor(FileTransferNotifier)
final fileTransferProvider = FileTransferNotifierProvider._();

/// Every transfer this app has been asked to run, wherever its two ends are.
final class FileTransferNotifierProvider
    extends $NotifierProvider<FileTransferNotifier, FileTransferState> {
  /// Every transfer this app has been asked to run, wherever its two ends are.
  FileTransferNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileTransferProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileTransferNotifierHash();

  @$internal
  @override
  FileTransferNotifier create() => FileTransferNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileTransferState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileTransferState>(value),
    );
  }
}

String _$fileTransferNotifierHash() =>
    r'59202179e00773aaa877583254b928440e357b2d';

/// Every transfer this app has been asked to run, wherever its two ends are.

abstract class _$FileTransferNotifier extends $Notifier<FileTransferState> {
  FileTransferState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FileTransferState, FileTransferState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FileTransferState, FileTransferState>,
              FileTransferState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
