import 'package:toolbox/data/model/pkg/manager.dart';

class UpgradePkgInfo {
  final PkgManager? _mgr;

  late String package;
  late String nowVersion;
  late String newVersion;
  late String arch;

  UpgradePkgInfo(String raw, this._mgr) {
    switch (_mgr) {
      case PkgManager.apt:
        _parseApt(raw);
        break;
      case PkgManager.yum:
        _parseYum(raw);
        break;
      case PkgManager.zypper:
        _parseZypper(raw);
        break;
      case PkgManager.pacman:
        _parsePacman(raw);
        break;
      case PkgManager.opkg:
        _parseOpkg(raw);
        break;
      default:
        throw Exception('Unsupported pkg type: $_mgr');
    }
  }

  void _parseApt(String raw) {
    final split1 = raw.split("/");
    package = split1[0];
    final split2 = split1[1].split(" ");
    newVersion = split2[1];
    arch = split2[2];
    nowVersion = split2[5].replaceFirst(']', '');
  }

  void _parseYum(String raw) {
    final result = RegExp(r'\S+').allMatches(raw);
    final pkgAndArch = result.elementAt(0).group(0) ?? '.';
    final split1 = pkgAndArch.split('.');
    package = split1[0];
    arch = split1[1];
    newVersion = result.elementAt(1).group(0) ?? 'Unknown';
    nowVersion = '';
  }

  void _parseZypper(String raw) {
    final cols = raw.split("|");
    package = cols[2].trim();
    nowVersion = cols[3].trim();
    newVersion = cols[4].trim();
    arch = cols[5].trim();
  }

  void _parsePacman(String raw) {
    final parts = raw.split(' ');
    package = parts[0];
    nowVersion = parts[1];
    newVersion = parts[3];
    arch = '';
  }

  void _parseOpkg(String raw) {
    final parts = raw.split(' - ');
    package = parts[0];
    nowVersion = parts[1];
    newVersion = parts[2];
    arch = '';
  }
}
