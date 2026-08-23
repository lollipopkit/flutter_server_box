import 'package:json_annotation/json_annotation.dart';

part 'private_key_info.g.dart';

@JsonSerializable()
class PrivateKeyInfo {
  /// Generated, and what `SshCredential.keyId` points at.
  ///
  /// Was the user-typed name until the tables landed, so renaming a key
  /// detached every server using it. The two are separate fields now and the
  /// reference is to this one.
  final String id;

  /// What the user typed, and what the list shows. Unique, enforced by the
  /// schema rather than by the two pages that can create one.
  final String name;

  @JsonKey(name: 'private_key')
  final String key;

  /// What to put at the end of the public key line, when the user has said.
  ///
  /// Null means "whatever the key itself says" — see `describeSshKey`. Editing
  /// it here rather than in the key is what keeps changing a label from
  /// needing the passphrase and a rewrite of key material.
  final String? comment;

  const PrivateKeyInfo({
    required this.id,
    required this.name,
    required this.key,
    this.comment,
  });

  /// [name] falls back to [id] for a record written before they were separate:
  /// back then the id *was* the name, which is exactly what to show.
  factory PrivateKeyInfo.fromJson(Map<String, dynamic> json) =>
      _$PrivateKeyInfoFromJson({
        ...json,
        if ((json['name'] as String?)?.isNotEmpty != true) 'name': json['id'],
      });

  Map<String, dynamic> toJson() => _$PrivateKeyInfoToJson(this);

  PrivateKeyInfo copyWith({
    String? id,
    String? name,
    String? key,
    // Positional-ish: `null` means "leave it", and clearing is what
    // `clearComment` is for — a nullable field cannot say both with one
    // parameter.
    String? comment,
    bool clearComment = false,
  }) => PrivateKeyInfo(
    id: id ?? this.id,
    name: name ?? this.name,
    key: key ?? this.key,
    comment: clearComment ? null : (comment ?? this.comment),
  );

  String? get type {
    final lines = key.split('\n');
    if (lines.length < 2) {
      return null;
    }
    final firstLine = lines[0];
    final splited = firstLine.split(RegExp(r'\s+'));
    if (splited.length < 2) {
      return null;
    }
    return splited[1];
  }
}
