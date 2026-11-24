import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/bmc/bmc_cfg.dart';
import 'package:server_box/src/rust/api/bmc.dart';

part 'bmc_target.freezed.dart';
part 'bmc_target.g.dart';

/// A Redfish BMC endpoint managed as a standalone resource, optionally linked
/// to an OS host ([serverId]).
///
/// Unlinked targets appear as their own cards in the Status tab. Linked targets
/// attach to their host's card and detail page instead of duplicating a card on
/// the grid.
@freezed
abstract class BmcTarget with _$BmcTarget {
  const BmcTarget._();

  @JsonSerializable(includeIfNull: false)
  const factory BmcTarget({
    required String id,
    required String name,

    /// Base URL, e.g. `https://10.0.0.9`.
    required String addr,

    /// Referenced [BmcCredential.id], or null when unset / deleted.
    String? credId,

    /// Pinned leaf certificate SHA-256 (lowercase hex), or null until reviewed.
    String? certSha256,

    /// Linked [Spi.id], or null for a standalone BMC target.
    String? serverId,

    List<String>? tags,
  }) = _BmcTarget;

  factory BmcTarget.fromJson(Map<String, dynamic> json) =>
      _$BmcTargetFromJson(json);

  /// Parsed HTTPS URI matching `sbm_redfish::client::parse_base`, or null.
  Uri? get uri => BmcCfg.parseUri(addr);

  /// Port to connect to (443 by default), or null when [addr] is invalid.
  int? get port => uri?.port;

  /// Ready to dial: valid HTTPS URL and a credential id.
  bool get isComplete => uri != null && credId?.isNotEmpty == true;

  /// Why this target cannot be dialed yet, or null when [isComplete].
  RedfishFailure? get incompleteFailure {
    if (uri == null) return RedfishFailure.invalidUrl;
    if (credId == null || credId!.isEmpty) return RedfishFailure.noCredential;
    return null;
  }

  /// Whether this BMC belongs to a host entry.
  bool get isLinked => serverId != null && serverId!.isNotEmpty;

  /// Human-readable host/address for list search and subtitles.
  String get displayAddr => uri?.host ?? addr.trim();
}
