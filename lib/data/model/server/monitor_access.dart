/// Why a `monitor` agent refuses everything beyond reading, as it says it —
/// see `docs/dev/monitor-permissions.md`.
enum MonitorAccessWhy {
  /// Plaintext HTTP away from loopback, without the agent's `allow_insecure`.
  insecureTransport,

  /// A reason a later agent added. Read as "refused" with no more said.
  unknown;

  static MonitorAccessWhy? fromWire(Object? value) => switch (value) {
    null => null,
    'insecure_transport' => insecureTransport,
    _ => unknown,
  };
}

/// `capabilities.access`: whether the agent lets this connection do more than
/// read — terminals, commands, files, relays, listeners.
///
/// The agent has one account, which may do whatever the system account it
/// runs as may do; the only thing left to refuse is the transport. It
/// re-checks per request; the app uses this only to decide what to offer.
class MonitorAccess {
  const MonitorAccess({required this.ok, this.why});

  final bool ok;

  /// Only when [ok] is false.
  final MonitorAccessWhy? why;

  /// Before the agent has answered, or when it did not say.
  static const none = MonitorAccess(ok: false);

  static const granted = MonitorAccess(ok: true);

  factory MonitorAccess.fromJson(Object? json) {
    if (json is! Map) return none;
    final ok = json['ok'] == true;
    return MonitorAccess(
      ok: ok,
      why: ok ? null : MonitorAccessWhy.fromWire(json['why']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MonitorAccess && other.ok == ok && other.why == why;

  @override
  int get hashCode => Object.hash(ok, why);

  @override
  String toString() => ok ? 'MonitorAccess(ok)' : 'MonitorAccess(refused: ${why?.name})';
}
