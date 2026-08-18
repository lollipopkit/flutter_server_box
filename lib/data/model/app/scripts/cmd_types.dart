import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// Enum representing different command types for various systems
enum CmdTypeSys {
  linux('Linux'),
  bsd('BSD'),
  windows('Windows');

  final String sign;
  const CmdTypeSys(this.sign);

  IconData get icon {
    return switch (this) {
      CmdTypeSys.linux => MingCute.linux_line,
      CmdTypeSys.bsd => LineAwesome.freebsd,
      CmdTypeSys.windows => MingCute.windows_line,
    };
  }
}

/// Base class for all command type enums.
///
/// Commands and script generation live in the shared Rust library
/// (sbm_parser commands.rs / script.rs, see the shared-parser design); these enums remain
/// as typed keys for UI (disable toggles, i18n) and parsed-output lookup.
// TODO(migration): enum names must stay in sync with the sbm_parser
// commands.rs keys (locked by test/frb_parser_test.dart).
sealed class ShellCmdType implements Enum {
  /// Get corresponding system type
  CmdTypeSys get sysType;

  static Set<ShellCmdType> get all {
    return {
      ...StatusCmdType.values,
      ...BSDStatusCmdType.values,
      ...WindowsStatusCmdType.values,
    };
  }
}

extension ShellCmdTypeX on ShellCmdType {
  /// Display name of the command type; also the stored disable-key format
  String get displayName => '${sysType.sign}.$name';
}

/// Linux/Unix status commands
enum StatusCmdType implements ShellCmdType {
  echo,
  time,
  net,
  sys,
  cpu,
  uptime,
  conn,
  disk,
  mem,
  tempType,
  tempVal,
  host,
  diskio,
  battery,
  nvidia,
  amd,
  sensors,
  diskSmart,
  cpuBrand;

  @override
  CmdTypeSys get sysType => CmdTypeSys.linux;
}

/// BSD/macOS status commands
enum BSDStatusCmdType implements ShellCmdType {
  echo,
  time,
  net,
  sys,
  cpu,
  uptime,
  disk,
  mem,
  host,
  diskSmart,
  cpuBrand;

  @override
  CmdTypeSys get sysType => CmdTypeSys.bsd;
}

/// Windows PowerShell status commands
enum WindowsStatusCmdType implements ShellCmdType {
  echo,
  time,
  net,
  sys,
  cpu,
  uptime,
  conn,
  disk,
  mem,
  temp,
  host,
  diskio,
  battery,
  nvidia,
  amd,
  sensors,
  diskSmart,
  cpuBrand;

  @override
  CmdTypeSys get sysType => CmdTypeSys.windows;
}

/// Extensions for StatusCmdType
extension StatusCmdTypeX on StatusCmdType {
  String get i18n => switch (this) {
    StatusCmdType.sys => l10n.system,
    StatusCmdType.host => libL10n.host,
    StatusCmdType.uptime => libL10n.uptime,
    StatusCmdType.battery => libL10n.battery,
    StatusCmdType.sensors => libL10n.sensors,
    StatusCmdType.disk => libL10n.disk,
    final val => val.name,
  };
}

/// Extension for CommandType to find content in parsed map
extension CommandTypeX on ShellCmdType {
  /// Find the command output from the parsed script output map
  String findInMap(Map<String, String> parsedOutput) {
    return parsedOutput[name] ?? '';
  }
}
