import 'package:server_box/data/model/server/dist.dart';

enum PkgManager {
  apt,
  yum,
  zypper,
  pacman,
  opkg,
  apk;

  String? get listUpdate {
    switch (this) {
      case PkgManager.yum:
        return 'yum check-update';
      case PkgManager.apt:
        return 'apt list --upgradeable';
      case PkgManager.zypper:
        return 'zypper lu';
      case PkgManager.pacman:
        return 'pacman -Qu';
      case PkgManager.opkg:
        return 'opkg list-upgradable';
      case PkgManager.apk:
        return 'apk list --upgradable';
      default:
        return null;
    }
  }

  String? get update {
    switch (this) {
      case PkgManager.apt:
        return 'apt update';
      case PkgManager.pacman:
        return 'pacman -Sy';
      case PkgManager.opkg:
        return 'opkg update';
      case PkgManager.apk:
        return 'apk update';
      default:
        return null;
    }
  }

  String? upgrade(String args) {
    switch (this) {
      case PkgManager.yum:
        return 'yum upgrade -y';
      case PkgManager.apt:
        return 'apt upgrade -y';
      case PkgManager.zypper:
        return 'zypper up -y';
      case PkgManager.pacman:
        return 'pacman -Syu --noconfirm';
      case PkgManager.opkg:
        return 'opkg upgrade $args';
      case PkgManager.apk:
        return 'apk upgrade';
      default:
        return null;
    }
  }

  List<String> updateListRemoveUnused(List<String> list) {
    switch (this) {
      case PkgManager.yum:
        list = list.sublist(2);
        list.removeWhere((element) => element.isEmpty);
        final endLine = list.lastIndexWhere(
            (element) => element.contains('Obsoleting Packages'));
        if (endLine != -1 && list.isNotEmpty) {
          list = list.sublist(0, endLine);
        }
        break;
      case PkgManager.apt:
        // avoid other outputs
        // such as: [Could not chdir to home directory /home/test: No such file or directory, , WARNING: apt does not have a stable CLI interface. Use with caution in scripts., , Listing...]
        final idx =
            list.indexWhere((element) => element.contains('[upgradable from:'));
        if (idx == -1) {
          return [];
        }
        list = list.sublist(idx);
        list.removeWhere((element) => element.isEmpty);
        break;
      case PkgManager.zypper:
        list = list.sublist(4);
        break;
      case PkgManager.pacman:
      case PkgManager.opkg:
      case PkgManager.apk:
        break;
    }
    list.removeWhere((element) => element.isEmpty);
    return list;
  }

  static PkgManager? fromDist(Dist? dist) {
    switch (dist) {
      case Dist.centos:
      case Dist.rocky:
      case Dist.fedora:
        return PkgManager.yum;
      case Dist.debian:
      case Dist.ubuntu:
      case Dist.kali:
      case Dist.armbian:
      case Dist.deepin:
        return PkgManager.apt;
      case Dist.opensuse:
        return PkgManager.zypper;
      case Dist.wrt:
        return PkgManager.opkg;
      case Dist.arch:
        return PkgManager.pacman;
      case Dist.alpine:
        return PkgManager.apk;
      case null:
        return null;
    }
  }
}
