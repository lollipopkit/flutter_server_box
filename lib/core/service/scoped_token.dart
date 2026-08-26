import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// A read-only credential this app obtained from one `monitor` agent on behalf
/// of a second surface — an Apple Watch, or a home-screen widget.
///
/// The agent mints these at `POST /api/v1/watch-token`, scoped to a
/// `client_id` and independently revocable, and they reach exactly three
/// endpoints: `/status`, `/metrics` and `/metrics/history`. That limit is the
/// agent's route table rather than anything carried in the token, and is
/// locked there by `monitor/tests/watch_token_scope.rs`.
///
/// [endpoint] travels with the token because the token is only meaningful
/// against the agent that issued it: point a server at a different address and
/// the stored credential is not stale, it is *wrong*, and reusing it would
/// send one agent's token to another.
@immutable
class ScopedToken {
  const ScopedToken({
    required this.token,
    required this.endpoint,
    this.expiresAt = 0,
    this.opaque = false,
  });

  /// A credential this side knows *about* but cannot read.
  ///
  /// The home widgets keep theirs in the platform credential store, and the
  /// channel answers with the endpoint and the deadline only — everything the
  /// renewal decision needs, without carrying the bytes back across. [token]
  /// is then a placeholder.
  const ScopedToken.held({
    required String endpoint,
    required int expiresAt,
  }) : this(
         token: _heldPlaceholder,
         endpoint: endpoint,
         expiresAt: expiresAt,
         opaque: true,
       );

  static const _heldPlaceholder = 'held';

  final String token;

  /// Whether [token] is a placeholder rather than the credential.
  ///
  /// Publishing one of these would overwrite the real credential with the
  /// word "held", and every request after it answers 401 — which is exactly
  /// what happened: the first push issued a real token, and the next one found
  /// it reusable and wrote the placeholder over it.
  final bool opaque;

  /// The normalized agent address this was issued by — see
  /// [normalizeAgentEndpoint].
  final String endpoint;

  /// Seconds since epoch, as the agent reported it.
  ///
  /// Zero means "not known", which is what a token minted by a build that
  /// discarded the agent's `expires_at` looks like. Treated as due for
  /// renewal rather than as valid forever: the agent's lifetime is 90 days,
  /// and an install carrying one of those has no other way back to a known
  /// expiry.
  final int expiresAt;

  /// How long before expiry a token is replaced.
  ///
  /// Renewal only happens when something asks for the token set to be
  /// rebuilt — a launch, a server edit, a watch reconnecting — so the window
  /// has to be wide enough that one of those is likely to fall inside it.
  /// Two weeks against the agent's ninety is generous in the direction that
  /// costs one HTTP request and stingy in the direction that costs a silent
  /// 401 on a device with no way to report it.
  static const renewBefore = Duration(days: 14);

  bool get isEmpty => token.isEmpty;

  /// Whether this can be handed over again as-is for [endpoint].
  ///
  /// [now] is passed in rather than read here so the decision stays a pure
  /// function of its inputs.
  bool servesEndpoint(String endpoint, DateTime now) {
    if (isEmpty) return false;
    if (this.endpoint != normalizeAgentEndpoint(endpoint)) return false;
    if (expiresAt <= 0) return false;
    final remaining =
        DateTime.fromMillisecondsSinceEpoch(
          expiresAt * 1000,
          isUtc: true,
        ).difference(now.toUtc());
    return remaining > renewBefore;
  }

  Map<String, dynamic> toEntry() => {
    'token': token,
    'expiresAt': expiresAt,
  };

  @override
  bool operator ==(Object other) =>
      other is ScopedToken &&
      other.token == token &&
      other.endpoint == endpoint &&
      other.expiresAt == expiresAt &&
      other.opaque == opaque;

  @override
  int get hashCode => Object.hash(token, endpoint, expiresAt, opaque);

  @override
  String toString() => 'ScopedToken($endpoint, expires $expiresAt)';
}

/// An agent address with surrounding space and trailing slashes removed, so
/// two spellings of one endpoint compare equal.
String normalizeAgentEndpoint(String value) =>
    value.trim().replaceFirst(RegExp(r'/+$'), '');

/// Which of [serverIds] already hold a token that can be handed over again,
/// and which have to be issued a fresh one.
///
/// Pure, and separate from the issuing, because every interesting case here is
/// a decision rather than a request: an address that changed, an expiry that
/// crept up, a server that lost its monitor configuration between two pushes.
/// The IO around it is one `POST` per id this does not return.
Map<String, ScopedToken> reusableScopedTokens({
  required List<String> serverIds,
  required Spi? Function(String id) lookup,
  required Map<String, ScopedToken> existing,
  required DateTime now,
}) {
  final reusable = <String, ScopedToken>{};
  for (final id in serverIds) {
    final monitor = lookup(id)?.monitor;
    final held = existing[id];
    if (monitor == null || held == null) continue;
    if (held.servesEndpoint(monitor.addr, now)) reusable[id] = held;
  }
  return reusable;
}

/// Every `client_id` this app mints a scoped token under.
///
/// One list, because the thing that has to revoke them does not care which
/// surface each belongs to — it is undoing all of them at one agent.
List<String> scopedClientIdsFor(String serverId) => [
  'watch:$serverId',
  'widget:$serverId',
];

/// Hands back the credentials an agent the server is *moving away from* still
/// holds.
///
/// This is the only moment they can be revoked. Once the record has been
/// edited, the old address and the old login are gone — and a scoped token is
/// revoked by an authenticated call to the agent that issued it, so nothing
/// later has anything to authenticate with. A rebuild of the token set can
/// only ever stop *handing out* a credential; the agent-side row stays valid
/// for up to ninety days.
///
/// Three ways a server moves away from its agent, and all three leave a live
/// token behind:
///
/// - its monitor configuration is removed outright;
/// - its address changes, so the new token is minted somewhere else;
/// - its username changes, since the agent keys `watch_tokens` by
///   `(subject, client_id)` and the subject is the account that asked.
///
/// Best effort and never rethrows. A server must stay editable while its agent
/// is offline, and once the record is written there is no retry target — the
/// token may outlive it remotely, which is worse than nothing but far better
/// than an edit that cannot be saved.
Future<void> revokeScopedTokensLeftBehind(Spi old, Spi next) async {
  final previous = old.monitor;
  if (previous == null) return;

  final current = next.monitor;
  final movedOn =
      current == null ||
      normalizeAgentEndpoint(current.addr) !=
          normalizeAgentEndpoint(previous.addr) ||
      current.user != previous.user;
  if (!movedOn) return;

  final client = MonitorHttpClient(previous);
  try {
    for (final clientId in scopedClientIdsFor(old.id)) {
      try {
        await client.revokeWatchToken(clientId);
      } catch (e, s) {
        Loggers.app.warning('Revoke $clientId at ${previous.addr}', e, s);
      }
    }
  } finally {
    client.dispose();
  }
}
