/// Finding one's way around a Redfish service, without assuming its shape.
///
/// Split from the transport so that this — the part where vendor differences
/// actually bite — can be tested against saved responses rather than hardware.
/// A fake [RedfishTransport] backed by a map of path to JSON is enough to
/// exercise every branch here.
library;

import 'package:server_box/data/model/server/bmc/redfish.dart';

/// Reading resources from a Redfish service.
///
/// An interface with one real implementation, so that discovery can be driven
/// by recorded responses. It deals in decoded JSON rather than bytes: nothing
/// below the transport needs to know about HTTP.
abstract interface class RedfishTransport {
  /// The resource at [path], or throws.
  Future<Map<String, dynamic>> get(String path);

  /// Sends [body] to [path]. Used for the reset action.
  Future<void> post(String path, Map<String, dynamic> body);
}

/// What a service turned out to be, worked out once.
///
/// Discovery is not free on a BMC — each step is a round trip to a device that
/// takes seconds to answer — and none of it changes while a connection lives.
/// So it happens once and is carried, rather than being re-derived per poll.
class RedfishTopology {
  const RedfishTopology({
    required this.root,
    required this.systemPath,
    required this.chassisPath,
    required this.system,
    required this.chassis,
  });

  final RedfishRoot root;

  /// The first member of each collection.
  ///
  /// First rather than "the one named X": the ids differ per vendor
  /// (`1`, `System.Embedded.1`, `system`), and a machine with several of either
  /// is not something this app has a way to present yet. Taking the first is a
  /// stated limitation, not an accident — see [hasMultipleSystems].
  final String? systemPath;
  final String? chassisPath;

  final RedfishSystem? system;
  final RedfishChassis? chassis;

  bool get isUsable => system != null;

  /// Which sensor model this chassis presents, or none.
  SensorModel get sensorModel => chassis?.model ?? SensorModel.none;

  /// Set when the service offered more than one system, so the UI can say that
  /// only the first is shown rather than quietly showing one of several.
  final bool hasMultipleSystems = false;
}

/// Why a service could not be read.
enum RedfishFailure {
  /// Answered, but is not a Redfish service — a static host serving its index
  /// page for every path looks exactly like this.
  notAService,

  /// Reachable and a service, but offers no system to read.
  noSystem,

  /// A sub-resource was refused. Licensing gates parts of some services
  /// (Supermicro's keys), so this is an ordinary answer about *that resource*
  /// and not a reason to call the whole service unusable.
  forbidden,

  /// The certificate was not the one that was reviewed, or nothing has been
  /// reviewed yet. Distinct from [unreachable] because the fix is a person
  /// looking at a fingerprint, not a network.
  certificateRejected,

  /// The account was refused.
  unauthorized,

  /// Nothing answered, or answered with something that is not a resource.
  unreachable,
}

class RedfishException implements Exception {
  const RedfishException(this.failure, [this.detail]);

  final RedfishFailure failure;
  final String? detail;

  @override
  String toString() =>
      'RedfishException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Walks a service and reports what it found.
class RedfishDiscovery {
  const RedfishDiscovery(this.transport);

  final RedfishTransport transport;

  static const rootPath = '/redfish/v1/';

  /// Reads the service root and the first system and chassis under it.
  ///
  /// Every path here comes from the previous response. Nothing is built by
  /// concatenation, which is the whole point: `Systems/1`,
  /// `Systems/System.Embedded.1` and `Systems/system` are all correct, and
  /// none of them can be derived from the others.
  Future<RedfishTopology> run() async {
    final rootJson = await transport.get(rootPath);
    final root = RedfishRoot.fromJson(rootJson);
    if (!root.isService) {
      throw const RedfishException(RedfishFailure.notAService);
    }

    final systemPath = await _firstMember(root.systems);
    final chassisPath = await _firstMember(root.chassis);

    if (systemPath == null) {
      throw const RedfishException(RedfishFailure.noSystem);
    }

    final system = RedfishSystem.fromJson(await transport.get(systemPath));

    // A chassis that cannot be read costs the sensor half and nothing else, so
    // it is not allowed to take the power half down with it
    RedfishChassis? chassis;
    if (chassisPath != null) {
      try {
        chassis = RedfishChassis.fromJson(await transport.get(chassisPath));
      } catch (_) {
        chassis = null;
      }
    }

    return RedfishTopology(
      root: root,
      systemPath: systemPath,
      chassisPath: chassisPath,
      system: system,
      chassis: chassis,
    );
  }

  Future<String?> _firstMember(String? collectionPath) async {
    if (collectionPath == null) return null;
    try {
      final members = collectionMembers(await transport.get(collectionPath));
      return members.isEmpty ? null : members.first;
    } catch (_) {
      return null;
    }
  }
}

/// The request a power operation becomes, worked out without sending it.
///
/// Returned rather than performed so that the decision — which reset type, to
/// which path — can be asserted in a test, while the only code that actually
/// resets a machine stays somewhere no test calls. The generated status script
/// treats shutdown and reboot the same way.
class ResetRequest {
  const ResetRequest({required this.target, required this.resetType});

  final String target;
  final String resetType;

  Map<String, dynamic> get body => {'ResetType': resetType};

  /// The request for [intent] against [system], or null if the service allows
  /// nothing that satisfies it.
  static ResetRequest? build(RedfishSystem system, PowerIntent intent) {
    final target = system.resetTarget;
    if (target == null) return null;
    final type = resolveResetType(intent, system.resetTypes);
    if (type == null) return null;
    return ResetRequest(target: target, resetType: type);
  }

  @override
  bool operator ==(Object other) =>
      other is ResetRequest &&
      target == other.target &&
      resetType == other.resetType;

  @override
  int get hashCode => Object.hash(target, resetType);

  @override
  String toString() => 'ResetRequest($target, $resetType)';
}
