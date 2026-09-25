import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';

part 'libvirt.freezed.dart';
part 'libvirt.g.dart';

/// `sbm_parser::virt` output as it crosses the FFI: serde JSON with
/// snake_case keys. Raw counters only; `VirtRateTracker` turns two readings
/// into rates.

/// `virsh version`.
@freezed
abstract class LibvirtVersion with _$LibvirtVersion {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtVersion({
    String? libvirt,
    String? hypervisor,
    String? hypervisorVersion,
  }) = _LibvirtVersion;

  factory LibvirtVersion.fromJson(Map<String, dynamic> json) =>
      _$LibvirtVersionFromJson(json);
}

@freezed
abstract class LibvirtBlockStats with _$LibvirtBlockStats {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtBlockStats({
    @Default('') String name,
    String? path,
    int? rdBytes,
    int? wrBytes,
    int? capacity,
    int? allocation,
  }) = _LibvirtBlockStats;

  factory LibvirtBlockStats.fromJson(Map<String, dynamic> json) =>
      _$LibvirtBlockStatsFromJson(json);
}

@freezed
abstract class LibvirtNetStats with _$LibvirtNetStats {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtNetStats({
    @Default('') String name,
    int? rxBytes,
    int? txBytes,
  }) = _LibvirtNetStats;

  factory LibvirtNetStats.fromJson(Map<String, dynamic> json) =>
      _$LibvirtNetStatsFromJson(json);
}

/// Cumulative counters from `domstats`; absent for an inactive domain.
@freezed
abstract class LibvirtCounters with _$LibvirtCounters {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtCounters({
    /// Nanoseconds.
    int? cpuTimeNs,

    /// KiB.
    int? balloonRssKib,
    int? balloonAvailableKib,
    int? balloonUnusedKib,
    @Default(<LibvirtBlockStats>[]) List<LibvirtBlockStats> blocks,
    @Default(<LibvirtNetStats>[]) List<LibvirtNetStats> nets,
  }) = _LibvirtCounters;

  factory LibvirtCounters.fromJson(Map<String, dynamic> json) =>
      _$LibvirtCountersFromJson(json);
}

/// One domain of the overview.
@freezed
abstract class LibvirtDomain with _$LibvirtDomain {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtDomain({
    required String uuid,
    required String name,

    /// `sbm_parser::virt::VirtState`: `running`, `paused`, `stopped`,
    /// `starting`, `stopping`, `unknown`.
    required String state,

    /// Raw `virDomainState`; -1 when `domstats` did not report the domain.
    @Default(-1) int stateCode,
    @Default(0) int reasonCode,
    @Default('unknown') String reason,
    @Default(false) bool autostart,
    @Default(false) bool persistent,
    int? vcpuCurrent,
    int? vcpuMax,
    int? memCurrentKib,
    int? memMaxKib,
    @Default(LibvirtCounters()) LibvirtCounters counters,
  }) = _LibvirtDomain;

  factory LibvirtDomain.fromJson(Map<String, dynamic> json) =>
      _$LibvirtDomainFromJson(json);
}

@freezed
abstract class LibvirtOverview with _$LibvirtOverview {
  const factory LibvirtOverview({
    LibvirtVersion? version,
    @Default(<LibvirtDomain>[]) List<LibvirtDomain> domains,
  }) = _LibvirtOverview;

  factory LibvirtOverview.fromJson(Map<String, dynamic> json) =>
      _$LibvirtOverviewFromJson(json);
}

/// The part of `dumpxml` the app reads.
@freezed
abstract class LibvirtDomainXml with _$LibvirtDomainXml {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtDomainXml({
    String? name,
    String? uuid,
    String? description,
    String? arch,
    String? machine,
    @Default(<VirtDisk>[]) List<VirtDisk> disks,
    @Default(<VirtNic>[]) List<VirtNic> nics,
    @Default(<VirtGraphics>[]) List<VirtGraphics> graphics,
    @Default(false) bool hasSerialConsole,
  }) = _LibvirtDomainXml;

  factory LibvirtDomainXml.fromJson(Map<String, dynamic> json) =>
      _$LibvirtDomainXmlFromJson(json);
}

@freezed
abstract class LibvirtDomainDetail with _$LibvirtDomainDetail {
  const factory LibvirtDomainDetail({
    VirtDisplay? display,
    @Default(LibvirtDomainXml()) LibvirtDomainXml xml,
  }) = _LibvirtDomainDetail;

  factory LibvirtDomainDetail.fromJson(Map<String, dynamic> json) =>
      _$LibvirtDomainDetailFromJson(json);
}
