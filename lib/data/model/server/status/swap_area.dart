import 'package:json_annotation/json_annotation.dart';

part 'swap_area.g.dart';

/// One active swap area (#1829): mirrors `sbm_parser::types::SwapArea`, which
/// the SSH status and the monitor agent's `/metrics` (`swap_areas`) both send.
@JsonSerializable(fieldRename: FieldRename.snake)
class SwapArea {
  /// `/dev/zram0`, `/swapfile`, `/dev/sda2`
  final String path;

  /// `partition` or `file`
  final String kind;

  /// Bytes
  final int size;
  final int used;

  /// Higher is used first.
  final int priority;

  const SwapArea({
    required this.path,
    this.kind = '',
    this.size = 0,
    this.used = 0,
    this.priority = 0,
  });

  /// Null for an area of no size.
  double? get usedPercent => size == 0 ? null : used / size;

  factory SwapArea.fromJson(Map<String, dynamic> json) =>
      _$SwapAreaFromJson(json);

  Map<String, dynamic> toJson() => _$SwapAreaToJson(this);
}
