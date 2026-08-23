/// The Redfish resources this app reads, and nothing about how they arrive.
///
/// Pure on purpose: every vendor difference worth getting right lives here, and
/// none of it needs a BMC to test. `docs/principles/bmc.md` records where the
/// differences come from; this file is where they are handled.
///
/// The rule throughout is that nothing about the resource layout is assumed.
/// Ids differ per vendor, sensor models differ per firmware generation, and a
/// reset type being advertised is not the same as it being implemented — so
/// each is read from what the service said rather than built from a template.
library;

/// A `@odata.id` reference, which is how Redfish links everything.
///
/// Kept as the raw path rather than resolved against a base: the service root
/// is already absolute in every response, and joining would only invent a way
/// to be wrong.
String? odataId(Object? json) {
  if (json is! Map) return null;
  final id = json['@odata.id'];
  return id is String && id.isNotEmpty ? id : null;
}

/// The `Members` of a Redfish collection, as paths.
///
/// An absent or malformed `Members` yields an empty list rather than throwing:
/// a service that offers no systems is a service this app has nothing to show
/// for, which is a state to report and not a parse failure.
List<String> collectionMembers(Map<String, dynamic> json) {
  final members = json['Members'];
  if (members is! List) return const [];
  return [
    for (final m in members) ?odataId(m),
  ];
}

/// What `GET /redfish/v1/` said.
class RedfishRoot {
  const RedfishRoot({
    required this.systems,
    required this.chassis,
    this.sessions,
    this.version,
    this.product,
    this.vendor,
  });

  factory RedfishRoot.fromJson(Map<String, dynamic> json) {
    // `Links.Sessions` is where the spec puts it; `SessionService/Sessions` is
    // where it can also be found, and some services fill in only one.
    final links = json['Links'];
    final sessions =
        odataId(links is Map ? links['Sessions'] : null) ??
        odataId(json['SessionService']);
    return RedfishRoot(
      systems: odataId(json['Systems']),
      chassis: odataId(json['Chassis']),
      sessions: sessions,
      version: json['RedfishVersion'] as String?,
      product: json['Product'] as String?,
      vendor: json['Vendor'] as String?,
    );
  }

  /// Collection paths, absent on a service that offers neither — which is how
  /// something that answers on the address but is not a BMC looks.
  final String? systems;
  final String? chassis;

  /// Where a session is created. Absent means Basic auth is the only way in.
  final String? sessions;

  final String? version;

  /// Free text, and the only hint of who made this. Reported, never branched
  /// on: the vendor name is not what decides which resources exist.
  final String? product;
  final String? vendor;

  /// Whether this looks like a Redfish service at all.
  ///
  /// A static host answers every path with its index page, and a JSON body
  /// that parses but has none of this is exactly what that looks like.
  bool get isService => systems != null || chassis != null;
}

/// The power states Redfish defines. `unknown` covers a service that reported
/// something newer than this, which is a thing to display rather than fail on.
enum PowerState {
  on,
  off,
  poweringOn,
  poweringOff,
  paused,
  unknown;

  static PowerState parse(Object? raw) => switch (raw) {
    'On' => PowerState.on,
    'Off' => PowerState.off,
    'PoweringOn' => PowerState.poweringOn,
    'PoweringOff' => PowerState.poweringOff,
    'Paused' => PowerState.paused,
    _ => PowerState.unknown,
  };

  /// Whether this is a state the machine is settling into rather than resting
  /// in — what a poll after a reset is waiting to get past.
  bool get isTransitional =>
      this == PowerState.poweringOn || this == PowerState.poweringOff;
}

/// A `ComputerSystem`, and the action on it.
class RedfishSystem {
  const RedfishSystem({
    required this.powerState,
    this.model,
    this.manufacturer,
    this.serial,
    this.biosVersion,
    this.health,
    this.resetTarget,
    this.resetTypes = const [],
  });

  factory RedfishSystem.fromJson(Map<String, dynamic> json) {
    final actions = json['Actions'];
    final reset = actions is Map ? actions['#ComputerSystem.Reset'] : null;
    final allowable = reset is Map
        ? reset['ResetType@Redfish.AllowableValues']
        : null;
    final status = json['Status'];
    return RedfishSystem(
      powerState: PowerState.parse(json['PowerState']),
      model: json['Model'] as String?,
      manufacturer: json['Manufacturer'] as String?,
      serial: json['SerialNumber'] as String?,
      biosVersion: json['BiosVersion'] as String?,
      // `HealthRollup` where present — it accounts for the subsystems, which
      // is the question someone looking at one line wants answered
      health: status is Map
          ? (status['HealthRollup'] ?? status['Health']) as String?
          : null,
      resetTarget: reset is Map ? reset['target'] as String? : null,
      resetTypes: allowable is List
          ? [
              for (final v in allowable)
                if (v is String) v,
            ]
          : const [],
    );
  }

  final PowerState powerState;
  final String? model;
  final String? manufacturer;
  final String? serial;
  final String? biosVersion;
  final String? health;

  /// Where to POST a reset, as the service gave it.
  ///
  /// Taken from the action rather than built from the system's own path: the
  /// two agree on every service seen, but only one of them is what the service
  /// said, and the other is a guess that happens to be right.
  final String? resetTarget;

  /// `ResetType@Redfish.AllowableValues`, verbatim.
  ///
  /// Advertised is not implemented — `Nmi` and `PowerCycle` in particular are
  /// commonly listed and unimplemented or license-gated — but it is the only
  /// statement the service makes, and acting outside it is certainly wrong.
  final List<String> resetTypes;

  bool get canReset => resetTarget != null && resetTypes.isNotEmpty;
}

/// What the user is asking for, as opposed to what Redfish calls it.
enum PowerIntent {
  on,
  gracefulShutdown,
  forceOff,
  restart,
  powerCycle;

  /// The `ResetType` values that satisfy this intent, best first.
  ///
  /// A chain rather than a single value because services differ in which they
  /// implement, and because the polite form of an operation is worth preferring
  /// where it exists. `restart` falling back to `ForceRestart` is the one that
  /// matters in practice.
  List<String> get candidates => switch (this) {
    PowerIntent.on => const ['On', 'ForceOn'],
    PowerIntent.gracefulShutdown => const ['GracefulShutdown'],
    PowerIntent.forceOff => const ['ForceOff'],
    PowerIntent.restart => const ['GracefulRestart', 'ForceRestart'],
    // `ForcePowerCycle` is not in the Redfish `ResetType` enum, but an H3C
    // R5350 G6 advertises it and nothing else that power-cycles. Without it
    // the intent fell through to `ForceRestart`, which is a different
    // operation — the machine restarts instead of losing power, and the button
    // that said "power cycle" did not do one.
    PowerIntent.powerCycle => const [
      'PowerCycle',
      'ForcePowerCycle',
      'ForceRestart',
    ],
  };
}

/// The `ResetType` to send for [intent], or null when the service allows none.
///
/// Null is a real answer and the caller has to show it as one: an intent with
/// nothing behind it is not offered, rather than offered and failing when
/// pressed.
String? resolveResetType(PowerIntent intent, List<String> allowed) {
  for (final candidate in intent.candidates) {
    if (allowed.contains(candidate)) return candidate;
  }
  return null;
}

/// Which sensor model a chassis presents.
///
/// Redfish 2020.4 deprecated `Thermal` and `Power` for `ThermalSubsystem`,
/// `PowerSubsystem` and a unified `Sensors` collection. Firmware follows
/// unevenly — Supermicro switched at X14, so X11 through X13 are still on the
/// old one — and transitional firmware carries **both**.
class RedfishChassis {
  const RedfishChassis({
    this.thermal,
    this.power,
    this.thermalSubsystem,
    this.powerSubsystem,
    this.sensors,
    this.name,
  });

  factory RedfishChassis.fromJson(Map<String, dynamic> json) =>
      RedfishChassis(
        thermal: odataId(json['Thermal']),
        power: odataId(json['Power']),
        thermalSubsystem: odataId(json['ThermalSubsystem']),
        powerSubsystem: odataId(json['PowerSubsystem']),
        sensors: odataId(json['Sensors']),
        name: json['Name'] as String?,
      );

  final String? thermal;
  final String? power;
  final String? thermalSubsystem;
  final String? powerSubsystem;
  final String? sensors;
  final String? name;

  /// Whether the new model is available here.
  ///
  /// `Sensors` is what carries the readings in it, so a chassis advertising
  /// `ThermalSubsystem` without one has nothing this app can read through the
  /// new path and is treated as old.
  bool get hasModernSensors =>
      sensors != null && (thermalSubsystem != null || powerSubsystem != null);

  /// Whether the deprecated pair is available.
  bool get hasLegacySensors => thermal != null || power != null;

  /// Which to read. The new model wins where both are present — that is what
  /// the deprecation means, and transitional firmware is where both appear.
  SensorModel get model {
    if (hasModernSensors) return SensorModel.modern;
    if (hasLegacySensors) return SensorModel.legacy;
    return SensorModel.none;
  }
}

enum SensorModel { modern, legacy, none }
