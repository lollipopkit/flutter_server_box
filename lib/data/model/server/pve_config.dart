import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pve_config.freezed.dart';
part 'pve_config.g.dart';

/// How the app logs in to a Proxmox VE API.
///
/// Stored by name, never by index — the `server_pve.auth` CHECK names both.
enum PveAuth {
  /// PAM realm, the SSH user, and [PveConfig.pwd] or the SSH password; a
  /// TOTP code when the account has one.
  password,

  /// `Authorization: PVEAPIToken=<tokenId>=<secret>`. No ticket, no CSRF
  /// token, no TOTP; the permissions are the token's.
  token;

  /// Null for a name this build does not know.
  static PveAuth? fromName(Object? name) =>
      values.firstWhereOrNull((e) => e.name == name);
}

/// One server's Proxmox VE configuration — a `server_pve` row.
///
/// Not part of `Spi`: it is a child of the server, stored and synced beside
/// it the way the container host is, by `PveStore`.
@freezed
abstract class PveConfig with _$PveConfig {
  const PveConfig._();

  const factory PveConfig({
    /// The API's base URL, e.g. `https://127.0.0.1:8006`. The host resolves
    /// on the far end of whichever transport carries the connection.
    required String addr,

    /// Unknown names read as [PveAuth.password], which is what every
    /// configuration from before tokens was.
    @JsonKey(unknownEnumValue: PveAuth.password)
    @Default(PveAuth.password)
    PveAuth auth,

    /// The PVE password, for [PveAuth.password] when the SSH login uses a
    /// stored key and so has no password to lend — see [loginPassword]. Kept
    /// null otherwise: the SSH password is what is sent then.
    String? pwd,

    /// `user@realm!tokenid` — see [tokenIdPattern].
    String? tokenId,

    /// The token's secret. Never logged: messages name [tokenId] instead.
    String? tokenSecret,

    /// SHA-256 of the DER certificate the user confirmed, lowercase hex. Null
    /// means none has been confirmed, and the next connection asks.
    String? certSha256,
  }) = _PveConfig;

  factory PveConfig.fromJson(Map<String, dynamic> json) =>
      _$PveConfigFromJson(json);

  /// The API on the server itself. Resolved on the far end of the transport,
  /// so it reaches a PVE host over SSH, its agent's relay, or locally alike.
  static const localAddr = 'https://127.0.0.1:8006';

  /// Just for showing the shape, next to `Spix.example`. **Not** a default.
  static const example = PveConfig(
    addr: 'https://localhost:8006',
    auth: PveAuth.token,
    tokenId: 'root@pam!serverbox',
    tokenSecret: 'token-secret',
  );

  /// The configuration a server record in an import carries: the `pve`
  /// object beside the server's own fields.
  static PveConfig? fromServerRecord(Object? record) {
    if (record is! Map) return null;
    final pve = record['pve'];
    if (pve is! Map) return null;
    try {
      return PveConfig.fromJson(Map<String, dynamic>.from(pve));
    } catch (e, s) {
      Loggers.app.warning('Unreadable PVE configuration was skipped', e, s);
      return null;
    }
  }

  /// What PVE accepts as an API token id: a user id (`name@realm`), `!`, and
  /// the token's own name, which starts with a letter.
  static final tokenIdPattern = RegExp(
    r'^[^\s:/@!]+@[A-Za-z][A-Za-z0-9._-]*![A-Za-z][A-Za-z0-9._-]*$',
  );

  /// Whether the token is complete enough to log in with.
  bool get hasToken =>
      (tokenId?.isNotEmpty ?? false) && (tokenSecret?.isNotEmpty ?? false);

  /// Whether [pwd] is the one a password login sends: only when the SSH
  /// login uses a stored key ([sshKeyId]), which leaves no SSH password to
  /// reuse. The rule every earlier build applied, and the one the editor shows
  /// the field by.
  static bool ownsPassword({required String? sshKeyId}) => sshKeyId != null;

  /// The password a [PveAuth.password] login sends: [pwd] when the SSH login
  /// uses a key ([ownsPassword]), otherwise the SSH password.
  String? loginPassword({
    required String? sshKeyId,
    required String? sshPassword,
  }) => ownsPassword(sshKeyId: sshKeyId) ? pwd : sshPassword;

  /// No secret in it: this reaches logs through string interpolation, and
  /// the generated one would print [pwd] and [tokenSecret].
  @override
  String toString() =>
      'PveConfig(addr: $addr, auth: ${auth.name}, tokenId: $tokenId, '
      'pinned: ${certSha256 != null})';
}
