import 'dart:async';

import 'package:fl_tty/fl_tty.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/data/res/store.dart';

/// Hands fl_tty what it reads of ServerBox. Before `Rootfs.prepare`.
void configFlTty() {
  FlTty.settings = const _Settings();
  // Fixed: systems already installed keep their `/etc/serverbox`.
  FlTty.brand = 'serverbox';
  FlTty.appName = 'ServerBox';
  FlTty.onSystemsChanged = () => unawaited(MethodChans.linuxSystemsChanged());
}

/// fl_tty's settings, in the keys ServerBox has always kept them under.
final class _Settings implements FlTtySettings {
  const _Settings();

  @override
  String get profile => Stores.setting.linuxProfile.fetch();
  @override
  set profile(String value) => Stores.setting.linuxProfile.put(value);

  @override
  String get distro => Stores.setting.linuxDistro.fetch();

  @override
  Map<String, String> get mirrors => Stores.setting.linuxMirrors.fetch();
  @override
  set mirrors(Map<String, String> value) => Stores.setting.linuxMirrors.put(value);

  @override
  String get dns => Stores.setting.linuxDns.fetch();

  @override
  int get manifestSerial => Stores.setting.rootfsManifestSerial.fetch();
  @override
  set manifestSerial(int value) => Stores.setting.rootfsManifestSerial.put(value);

  @override
  String get manifestCache => Stores.setting.rootfsManifestCache.fetch();
  @override
  set manifestCache(String value) => Stores.setting.rootfsManifestCache.put(value);

  @override
  String get manifestCacheSig => Stores.setting.rootfsManifestCacheSig.fetch();
  @override
  set manifestCacheSig(String value) => Stores.setting.rootfsManifestCacheSig.put(value);
}
