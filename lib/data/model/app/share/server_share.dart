import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

part 'server_share.freezed.dart';
part 'server_share.g.dart';

/// What [ServerShare.of] could not carry across to another device.
///
/// Surfaced rather than dropped quietly: each of these is something the sender
/// configured and the receiver will not have, and the difference between a
/// server that works and one that fails at connect time is exactly this list.
enum ServerShareOmission {
  /// [SshCredential.jumpId] / `jumpIds` name *other servers* by id. Carrying
  /// them would hand the receiver a reference to a record they do not have.
  jumpServer,

  /// `keyPath` and `identityFiles` are paths on the sender's filesystem. Only
  /// `~/.ssh/config` import writes them, so this is a desktop-only case.
  localKeyPath,

  /// `BmcCfg.credId` names a row in `bmc_credential`, which this payload does
  /// not carry. The address survives, the account does not.
  bmcCredential,

  /// The server names a key id that is not in this device's store. Nothing to
  /// pack, so the reference goes too — a dangling one would look like key
  /// auth and behave like nothing.
  missingKey,
}

/// Raised when a payload was written by a build that knows more than this one.
///
/// Refused rather than decoded on a best-effort basis: an unknown version is a
/// shape, and reading it with this version's expectations produces a server
/// that looks complete and is not.
class ServerShareTooNewException implements Exception {
  const ServerShareTooNewException(this.version);

  final int version;

  @override
  String toString() =>
      'ServerShareTooNewException($version > ${ServerShare.formatVer})';
}

/// One server, packed to be handed to another device.
///
/// Distinct from `BackupV2` on purpose. A backup is the whole state and is
/// merged, where an absent key means a deletion; this is a fragment and is
/// *added*, so it can never remove anything the receiver has. The two have no
/// reader in common for that reason.
@freezed
abstract class ServerShare with _$ServerShare {
  const ServerShare._();

  const factory ServerShare({
    required int version,

    /// Already made portable by [ServerShare.of] — see [ServerShareOmission]
    /// for what that means.
    required Spi spi,

    /// The private keys [spi] refers to, by value. Normally zero or one; a
    /// list because the field is what makes the payload self-contained and a
    /// server growing a second key reference should not need a format change.
    @Default(<PrivateKeyInfo>[]) List<PrivateKeyInfo> keys,

    /// Unix milliseconds, or null for a payload with no deadline.
    ///
    /// Set for the QR flavour and not for the file one, which is the whole
    /// difference between them: a QR is shown on a screen in a room, and the
    /// realistic way it leaks is a photograph. A deadline does not make the
    /// six-digit code longer, it bounds how long guessing it is worth doing.
    /// A file the user deliberately saved has no such moment to expire from.
    int? expiresAt,
  }) = _ServerShare;

  /// Must stay a single expression: `Freezed.needsJsonSerializable` only emits
  /// `@JsonSerializable()` when this factory's body `is ExpressionFunctionBody`
  /// — with a block body the `.g.dart` silently stops carrying `toJson`. Same
  /// trap as `BackupV2.fromJson`.
  factory ServerShare.fromJson(Map<String, dynamic> json) =>
      _$ServerShareFromJson(json);

  /// Bumped when the shape changes in a way an older reader would get wrong.
  static const formatVer = 1;

  /// Packs [spi] and whatever key it points at.
  ///
  /// [ttl] sets [expiresAt]. Null means the payload never expires.
  static ServerShare of(Spi spi, {Duration? ttl}) {
    final keys = <PrivateKeyInfo>[];
    final keyId = spi.ssh?.keyId;
    final key = keyId == null ? null : Stores.key.fetchOne(keyId);
    if (key != null) keys.add(key);

    return ServerShare(
      version: formatVer,
      spi: _portable(spi, keptKey: key),
      keys: keys,
      expiresAt: ttl == null
          ? null
          : DateTime.now().add(ttl).millisecondsSinceEpoch,
    );
  }

  /// What [of] would leave behind, so a dialog can say so before anything is
  /// handed over.
  static Set<ServerShareOmission> omissionsOf(Spi spi) {
    final out = <ServerShareOmission>{};
    final ssh = spi.ssh;
    if (ssh != null) {
      if (ssh.resolvedJumpIds.isNotEmpty) {
        out.add(ServerShareOmission.jumpServer);
      }
      if (ssh.keyPath != null || ssh.identityFiles?.isNotEmpty == true) {
        out.add(ServerShareOmission.localKeyPath);
      }
      final keyId = ssh.keyId;
      if (keyId != null && Stores.key.fetchOne(keyId) == null) {
        out.add(ServerShareOmission.missingKey);
      }
    }
    if (spi.bmc?.credId != null) {
      out.add(ServerShareOmission.bmcCredential);
    }
    return out;
  }

  /// Strips every reference that only means something on the sender's device.
  ///
  /// [keptKey] is what the payload actually carries; when it is null the
  /// `keyId` goes with it rather than being handed over as a dangling id.
  static Spi _portable(Spi spi, {required PrivateKeyInfo? keptKey}) {
    final ssh = spi.ssh;
    return spi.copyWith(
      ssh: ssh?.copyWith(
        keyId: keptKey?.id,
        keyPath: null,
        identityFiles: null,
        jumpId: null,
        jumpIds: null,
        // Kept. It is a command line the user wrote, not a reference into a
        // store, and it is as likely to be right on the receiving machine as
        // on this one. Dropping it would break a working config silently.
      ),
      bmc: spi.bmc?.copyWith(credId: null),
    );
  }

  /// Whether this payload's deadline has passed.
  ///
  /// A payload with no deadline never expires. [now] is injectable so the test
  /// for the boundary does not have to sleep.
  bool isExpired([DateTime? now]) {
    final at = expiresAt;
    if (at == null) return false;
    return (now ?? DateTime.now()).millisecondsSinceEpoch > at;
  }

  /// Refuses a payload this build cannot read correctly.
  void validate() {
    if (version > formatVer) throw ServerShareTooNewException(version);
  }
}
