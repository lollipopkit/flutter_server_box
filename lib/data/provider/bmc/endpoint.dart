import 'package:fl_lib/fl_lib.dart' hide Provider;
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/provider/bmc/bmc_credential.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/src/rust/api/bmc.dart';

/// Result of resolving a BMC target's connection fields and credential.
sealed class BmcEndpointResolution {
  const BmcEndpointResolution();
}

/// The target id is not present in [bmcTargetsProvider].
final class BmcEndpointMissing extends BmcEndpointResolution {
  const BmcEndpointMissing();
}

/// The target or its credential is incomplete or missing.
final class BmcEndpointFailed extends BmcEndpointResolution {
  const BmcEndpointFailed(this.failure);

  final RedfishFailure failure;
}

/// Complete connection parameters ready to open or poll a BMC client.
final class BmcEndpointReady extends BmcEndpointResolution {
  const BmcEndpointReady({
    required this.addr,
    required this.user,
    required this.password,
    required this.certSha256,
  });

  final String addr;
  final String user;
  final String? password;
  final String? certSha256;
}

/// Watches only connection-relevant target fields and the referenced
/// credential so renaming, tagging, or linking/unlinking never tears down an
/// active session or cached summary.
BmcEndpointResolution watchBmcEndpoint(Ref ref, String targetId) {
  final endpoint = ref.watch(
    bmcTargetsProvider.select((s) {
      final t = s.targets[targetId];
      if (t == null) return null;
      return (
        addr: t.addr,
        credId: t.credId,
        certSha256: t.certSha256,
        incompleteFailure: t.incompleteFailure,
      );
    }),
  );
  if (endpoint == null) return const BmcEndpointMissing();
  if (endpoint.incompleteFailure case final failure?) {
    return BmcEndpointFailed(failure);
  }

  final credId = endpoint.credId!;
  final cred = ref.watch(
    bmcCredentialProvider.select(
      (state) => state.creds.firstWhereOrNull((e) => e.id == credId),
    ),
  );
  if (cred == null || !cred.isComplete) {
    return const BmcEndpointFailed(RedfishFailure.noCredential);
  }

  return BmcEndpointReady(
    addr: endpoint.addr,
    user: cred.user,
    password: cred.pwd,
    certSha256: endpoint.certSha256,
  );
}
