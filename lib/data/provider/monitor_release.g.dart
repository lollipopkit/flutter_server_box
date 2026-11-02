// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_release.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The newest released `monitor` agent, read from this repository's releases
/// once a run: for an agent too old to say itself (`GET /api/v1/update`).
/// Read only while something watches it, so only with such an agent.
///
/// Which release it is, and whether an agent is behind it, is Rust's
/// (`sbm_parser::monitor_agent`), the same the agent answers with.

@ProviderFor(monitorLatestRelease)
final monitorLatestReleaseProvider = MonitorLatestReleaseProvider._();

/// The newest released `monitor` agent, read from this repository's releases
/// once a run: for an agent too old to say itself (`GET /api/v1/update`).
/// Read only while something watches it, so only with such an agent.
///
/// Which release it is, and whether an agent is behind it, is Rust's
/// (`sbm_parser::monitor_agent`), the same the agent answers with.

final class MonitorLatestReleaseProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The newest released `monitor` agent, read from this repository's releases
  /// once a run: for an agent too old to say itself (`GET /api/v1/update`).
  /// Read only while something watches it, so only with such an agent.
  ///
  /// Which release it is, and whether an agent is behind it, is Rust's
  /// (`sbm_parser::monitor_agent`), the same the agent answers with.
  MonitorLatestReleaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'monitorLatestReleaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monitorLatestReleaseHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return monitorLatestRelease(ref);
  }
}

String _$monitorLatestReleaseHash() =>
    r'ad069570fd6786f5d71abe15559aff6427386e92';
