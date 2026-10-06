import 'package:server_box/data/model/server/firewall.dart';

export 'package:server_box/data/model/server/firewall.dart';

extension FirewalldTargetX on FirewalldTarget {
  /// What `--set-target` takes: `%%REJECT%%` for `REJECT`.
  String get token => firewalldTargetToken(target: this);

  /// As a person reads it: `REJECT` rather than `%%REJECT%%`.
  String get label => this == FirewalldTarget.reject ? 'REJECT' : token;
}

extension FirewalldPortX on FirewalldPort {
  /// `8080/tcp`, as firewalld writes it.
  String get spec => firewalldPortSpec(port: this);
}

extension FirewalldZoneX on FirewalldZone {
  /// This zone with what is given changed: a change asked about before it
  /// is made.
  FirewalldZone copyWith({
    FirewalldTarget? target,
    List<String>? interfaces,
    List<String>? sources,
    List<String>? services,
    List<FirewalldPort>? ports,
    List<String>? protocols,
    List<String>? forwardPorts,
    List<FirewalldRichRule>? richRules,
  }) => FirewalldZone(
    name: name,
    target: target ?? this.target,
    active: active,
    interfaces: interfaces ?? this.interfaces,
    sources: sources ?? this.sources,
    services: services ?? this.services,
    ports: ports ?? this.ports,
    protocols: protocols ?? this.protocols,
    sourcePorts: sourcePorts,
    forwardPorts: forwardPorts ?? this.forwardPorts,
    richRules: richRules ?? this.richRules,
    masquerade: masquerade,
  );
}

extension FirewalldSnapshotX on FirewalldSnapshot {
  /// What is in force: [runtime] while running, else [permanent].
  List<FirewalldZone> get zones => runtime ?? permanent;

  FirewalldZone? zone(String name, {bool permanent = false}) {
    for (final z in permanent ? this.permanent : zones) {
      if (z.name == name) return z;
    }
    return null;
  }

  /// The runtime differs from what is written down: a reload or a boot will
  /// change what the firewall does.
  bool get drifted => firewalldDrifted(snapshot: this);

  /// The zones a connection like [access] may be handled by; [zones] and
  /// [defaultZone] stand in for this snapshot's own.
  List<FirewalldZone> zonesFor(
    FirewallAccess access, {
    List<FirewalldZone>? zones,
    String? defaultZone,
  }) => firewalldZonesFor(
    snapshot: this,
    access: access,
    zones: zones,
    defaultZone: defaultZone,
  );

  /// [access] gets in now and will not once the saved configuration is in
  /// force.
  bool shutByReload(FirewallAccess access) =>
      firewalldShutByReload(snapshot: this, access: access);
}
