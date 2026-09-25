import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

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

  /// Just for showing the shape, next to `Spix.example`. **Not** a default.
  static const example = PveConfig(
    addr: 'https://localhost:8006',
    auth: PveAuth.token,
    tokenId: 'root@pam!serverbox',
    tokenSecret: 'token-secret',
  );

  /// The configuration a server record in an import or a share carries: the
  /// `pve` object beside the server's own fields, or — from an older build —
  /// the flat fields inside `custom`.
  static PveConfig? fromServerRecord(Object? record) {
    if (record is! Map) return null;
    final pve = record['pve'];
    if (pve is Map) {
      try {
        return PveConfig.fromJson(Map<String, dynamic>.from(pve));
      } catch (e, s) {
        Loggers.app.warning('Unreadable PVE configuration was skipped', e, s);
        return null;
      }
    }
    return fromLegacyRecord(record);
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

  /// The PVE fields a server record carried inside `custom` before they had a
  /// table of their own — what a backup, a sync file, a bulk import or a
  /// share written by an older build still holds. [record] is the whole
  /// server record, since whether `pvePwd` means anything depends on its SSH
  /// key ([ownsPassword]); the key sits under `ssh` or, in the pre-v3 flat
  /// layout, at the top.
  ///
  /// `pveIgnoreCert` is read and dropped: it accepted any certificate, and
  /// what replaces it is confirming one on the next connection, which is what
  /// no pin means.
  // TODO(migration): remove after 5 releases, with every caller.
  static PveConfig? fromLegacyRecord(Object? record) {
    if (record is! Map) return null;
    final custom = record['custom'];
    if (custom is! Map) return null;
    final addr = custom['pveAddr'];
    if (addr is! String || addr.trim().isEmpty) return null;
    final keyId = switch (record['ssh']) {
      final Map ssh => ssh['pubKeyId'],
      // `Spi.toJson` leaves nested models as they are.
      final SshCredential ssh => ssh.keyId,
      _ => record['pubKeyId'],
    };
    final pwd = custom['pvePwd'];
    return PveConfig(
      addr: addr,
      pwd:
          ownsPassword(sshKeyId: keyId is String ? keyId : null) &&
              pwd is String &&
              pwd.isNotEmpty
          ? pwd
          : null,
    );
  }

  /// This configuration in the fields an older build reads from a server
  /// record's `custom` — written beside [toJson] into every sync file, backup
  /// and share while builds without `server_pve` may read them. An older build
  /// ignores the `pve` section and writes back only what it read, so without
  /// these a round trip through it would carry the server back without PVE.
  ///
  /// `pveIgnoreCert` is set exactly when a certificate is pinned: a pin is
  /// only ever made for one that did not validate against a CA, and "ignore
  /// the certificate" is the only way an older build can reach such a server.
  // TODO(migration): remove after 5 releases, with [mergeLegacy].
  Map<String, Object?> toLegacyCustom() => {
    'pveAddr': addr,
    'pveIgnoreCert': certSha256 != null,
    'pvePwd': ?pwd,
  };

  /// [server] — a server record, as `Spi.toJson` or decoded JSON — with
  /// [cfg]'s [toLegacyCustom] fields written into its `custom`.
  // TODO(migration): remove after 5 releases, with [toLegacyCustom].
  static Map<String, Object?> withLegacyCustom(Map server, PveConfig cfg) {
    final out = Map<String, Object?>.from(server);
    final custom = out['custom'];
    final Map<String, Object?> fields = switch (custom) {
      final Map map => Map<String, Object?>.from(map),
      final ServerCustom custom => custom.toJson(),
      _ => <String, Object?>{},
    };
    out['custom'] = {...fields, ...cfg.toLegacyCustom()};
    return out;
  }

  /// What a server record from an older build ([legacy], read by
  /// [fromLegacyRecord]) makes of the configuration this device has
  /// ([existing]).
  ///
  /// The legacy fields express an address and a password and nothing else, so
  /// they are applied to what is here rather than replacing it: an older
  /// build handing back a record it received from this one must not turn a
  /// token login into a password login or drop a confirmed certificate.
  ///
  /// - The address is the legacy one. A different address drops the pin,
  ///   which names a certificate seen at the old one (the editor's rule).
  /// - The password is the legacy one for a password login; a token login
  ///   has none and keeps none.
  // TODO(migration): remove after 5 releases, with [toLegacyCustom].
  static PveConfig mergeLegacy(PveConfig? existing, PveConfig legacy) {
    if (existing == null) return legacy;
    final sameAddr = existing.addr.trim() == legacy.addr.trim();
    return existing.copyWith(
      addr: legacy.addr,
      pwd: existing.auth == PveAuth.password ? legacy.pwd : existing.pwd,
      certSha256: sameAddr ? existing.certSha256 : null,
    );
  }
}
