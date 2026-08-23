import 'package:json_annotation/json_annotation.dart';

part 'bmc_credential.g.dart';

/// An account on a BMC, kept apart from the servers that use it.
///
/// Its own record rather than fields on [BmcCfg], because one account is
/// normally what a whole rack has: BMCs are provisioned together and answer to
/// the same directory, or to the same factory password nobody changed. Twenty
/// servers each carrying their own copy means the password is typed twenty
/// times and, when it is rotated, changed in twenty places — with no way to
/// tell whether one was missed except by a machine that stops answering.
///
/// What is deliberately *not* here is the address and the pinned certificate.
/// Both belong to one device: two BMCs never present the same certificate, so
/// a fingerprint on a shared record would be the first device's, used to
/// verify the second — which is the check not happening at all.
@JsonSerializable()
class BmcCredential {
  /// Generated, and what [BmcCfg.credId] points at.
  ///
  /// Never the [name]: a private key's id *was* its name until the tables
  /// landed, and renaming one detached every server pointing at it. Same
  /// decision, made once rather than rediscovered.
  final String id;

  /// What the user typed and what the picker lists. Unique, enforced by the
  /// schema rather than by whichever dialog last remembered to check.
  final String name;

  final String user;

  /// Null for an account whose password has not been entered yet — a record
  /// can be named and picked before it can log in, and saying so is better
  /// than storing an empty string that reads as a password.
  final String? pwd;

  const BmcCredential({
    required this.id,
    required this.name,
    required this.user,
    this.pwd,
  });

  factory BmcCredential.fromJson(Map<String, dynamic> json) =>
      _$BmcCredentialFromJson(json);

  Map<String, dynamic> toJson() => _$BmcCredentialToJson(this);

  /// Whether this can be logged in with.
  ///
  /// An empty password is not the same as none — some BMCs genuinely have one —
  /// so only [user] is required.
  bool get isComplete => user.trim().isNotEmpty;

  BmcCredential copyWith({
    String? id,
    String? name,
    String? user,
    Object? pwd = _unset,
  }) => BmcCredential(
    id: id ?? this.id,
    name: name ?? this.name,
    user: user ?? this.user,
    pwd: pwd == _unset ? this.pwd : pwd as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is BmcCredential &&
      id == other.id &&
      name == other.name &&
      user == other.user &&
      pwd == other.pwd;

  @override
  int get hashCode => Object.hash(id, name, user, pwd);

  @override
  String toString() => 'BmcCredential($name, $user)';
}

/// Sentinel so [BmcCredential.copyWith] can tell "leave as-is" from "set to
/// null" — clearing a stored password is a thing a caller has to be able to
/// say.
const _unset = Object();
