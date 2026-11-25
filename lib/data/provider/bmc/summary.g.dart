// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lightweight list-card BMC poller.
///
/// Opens a short-lived [BmcClient] per poll (via [BmcPollBudget]) and closes
/// the Redfish session immediately afterwards, so a grid of cards never holds
/// open sessions on devices that allow only a handful.

@ProviderFor(BmcSummaryNotifier)
final bmcSummaryProvider = BmcSummaryNotifierFamily._();

/// Lightweight list-card BMC poller.
///
/// Opens a short-lived [BmcClient] per poll (via [BmcPollBudget]) and closes
/// the Redfish session immediately afterwards, so a grid of cards never holds
/// open sessions on devices that allow only a handful.
final class BmcSummaryNotifierProvider
    extends $NotifierProvider<BmcSummaryNotifier, BmcSummaryState> {
  /// Lightweight list-card BMC poller.
  ///
  /// Opens a short-lived [BmcClient] per poll (via [BmcPollBudget]) and closes
  /// the Redfish session immediately afterwards, so a grid of cards never holds
  /// open sessions on devices that allow only a handful.
  BmcSummaryNotifierProvider._({
    required BmcSummaryNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bmcSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bmcSummaryNotifierHash();

  @override
  String toString() {
    return r'bmcSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BmcSummaryNotifier create() => BmcSummaryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BmcSummaryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BmcSummaryState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BmcSummaryNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bmcSummaryNotifierHash() =>
    r'2957b52e6b5a755f36c7a499e7cdde7bf5c0d760';

/// Lightweight list-card BMC poller.
///
/// Opens a short-lived [BmcClient] per poll (via [BmcPollBudget]) and closes
/// the Redfish session immediately afterwards, so a grid of cards never holds
/// open sessions on devices that allow only a handful.

final class BmcSummaryNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          BmcSummaryNotifier,
          BmcSummaryState,
          BmcSummaryState,
          BmcSummaryState,
          String
        > {
  BmcSummaryNotifierFamily._()
    : super(
        retry: null,
        name: r'bmcSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Lightweight list-card BMC poller.
  ///
  /// Opens a short-lived [BmcClient] per poll (via [BmcPollBudget]) and closes
  /// the Redfish session immediately afterwards, so a grid of cards never holds
  /// open sessions on devices that allow only a handful.

  BmcSummaryNotifierProvider call(String targetId) =>
      BmcSummaryNotifierProvider._(argument: targetId, from: this);

  @override
  String toString() => r'bmcSummaryProvider';
}

/// Lightweight list-card BMC poller.
///
/// Opens a short-lived [BmcClient] per poll (via [BmcPollBudget]) and closes
/// the Redfish session immediately afterwards, so a grid of cards never holds
/// open sessions on devices that allow only a handful.

abstract class _$BmcSummaryNotifier extends $Notifier<BmcSummaryState> {
  late final _$args = ref.$arg as String;
  String get targetId => _$args;

  BmcSummaryState build(String targetId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BmcSummaryState, BmcSummaryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BmcSummaryState, BmcSummaryState>,
              BmcSummaryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
