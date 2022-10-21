import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server/cpu_2_status.dart';
import 'package:toolbox/data/model/server/cpu_status.dart';
import 'package:toolbox/data/model/server/memory.dart';
import 'package:toolbox/data/model/server/net_speed.dart';
import 'package:toolbox/data/model/server/disk_info.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/model/server/tcp_status.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';

/// Must put this func out of any Class.
/// Because of this function is called by [compute] in [ServerProvider.genClient].
/// https://stackoverflow.com/questions/51998995/invalid-arguments-illegal-argument-in-isolate-message-object-is-a-closure
List<SSHKeyPair> loadIndentity(String key) {
  return SSHKeyPair.fromPem(key);
}

const seperator = 'A====A';
const shellCmd = "export LANG=en_US.utf-8 \necho '$seperator' \n"
    "cat /proc/net/dev && date +%s \necho $seperator \n "
    "cat /etc/os-release | grep PRETTY_NAME \necho $seperator \n"
    "cat /proc/stat | grep cpu \necho $seperator \n"
    "uptime \necho $seperator \n"
    "cat /proc/net/snmp \necho $seperator \n"
    "df -h \necho $seperator \n"
    "cat /proc/meminfo \necho $seperator \n"
    "cat /sys/class/thermal/thermal_zone*/type \necho $seperator \n"
    "cat /sys/class/thermal/thermal_zone*/temp";
const shellPath = '.serverbox.sh';
final cpuTempReg = RegExp(r'(x86_pkg_temp|cpu_thermal)');
final numReg = RegExp(r'\s{1,}');
final memItemReg = RegExp(r'([A-Z].+:)\s+([0-9]+) kB');

class ServerProvider extends BusyProvider {
  List<ServerInfo> _servers = [];
  List<ServerInfo> get servers => _servers;

  Timer? _timer;

  final logger = Logger('ServerProvider');

  Memory get emptyMemory =>
      Memory(total: 1, used: 0, free: 1, cache: 0, avail: 1);

  NetSpeedPart get emptyNetSpeedPart => NetSpeedPart('', 0, 0, 0);

  NetSpeed get emptyNetSpeed =>
      NetSpeed([emptyNetSpeedPart], [emptyNetSpeedPart]);

  CpuStatus get emptyCpuStatus => CpuStatus('cpu', 0, 0, 0, 0, 0, 0, 0);

  Cpu2Status get emptyCpu2Status =>
      Cpu2Status([emptyCpuStatus], [emptyCpuStatus], '');

  ServerStatus get emptyStatus => ServerStatus(
      emptyCpu2Status,
      emptyMemory,
      'Loading...',
      '',
      [DiskInfo('/', '/', 0, '0', '0', '0')],
      TcpStatus(0, 0, 0, 0),
      emptyNetSpeed);

  Future<void> loadLocalData() async {
    setBusyState(true);
    final infos = locator<ServerStore>().fetch();
    _servers = List.generate(infos.length, (index) => genInfo(infos[index]));
    setBusyState(false);
    notifyListeners();
  }

  ServerInfo genInfo(ServerPrivateInfo spi) {
    return ServerInfo(
        spi, emptyStatus, null, ServerConnectionState.disconnected);
  }

  Future<SSHClient> genClient(ServerPrivateInfo spi) async {
    final socket = await SSHSocket.connect(spi.ip, spi.port);
    if (spi.pubKeyId == null) {
      return SSHClient(socket,
          username: spi.user, onPasswordRequest: () => spi.pwd);
    }
    final key = locator<PrivateKeyStore>().get(spi.pubKeyId!);
    return SSHClient(socket,
        username: spi.user,
        identities: await compute(loadIndentity, key.privateKey));
  }

  Future<void> refreshData({ServerPrivateInfo? spi}) async {
    if (spi != null) {
      _getData(spi);
      return;
    }
    await Future.wait(_servers.map((s) async {
      await _getData(s.info);
    }));
  }

  Future<void> startAutoRefresh() async {
    final duration =
        locator<SettingStore>().serverStatusUpdateInterval.fetch()!;
    if (duration == 0) return;
    stopAutoRefresh();
    _timer = Timer.periodic(Duration(seconds: duration), (_) async {
      await refreshData();
    });
  }

  void stopAutoRefresh() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void setDisconnected() {
    for (var i = 0; i < _servers.length; i++) {
      _servers[i].connectionState = ServerConnectionState.disconnected;
    }
  }

  void addServer(ServerPrivateInfo spi) {
    _servers.add(genInfo(spi));
    locator<ServerStore>().put(spi);
    notifyListeners();
    refreshData(spi: spi);
  }

  void delServer(ServerPrivateInfo info) {
    final idx = _servers.indexWhere((s) => s.info == info);
    if (idx == -1) return;
    _servers[idx].client?.close();
    _servers.removeAt(idx);
    notifyListeners();
    locator<ServerStore>().delete(info);
  }

  Future<void> updateServer(
      ServerPrivateInfo old, ServerPrivateInfo newSpi) async {
    final idx = _servers.indexWhere((e) => e.info == old);
    if (idx < 0) {
      throw RangeError.index(idx, _servers);
    }
    _servers[idx].info = newSpi;
    locator<ServerStore>().update(old, newSpi);
    _servers[idx].client = await genClient(newSpi);
    notifyListeners();
    refreshData(spi: newSpi);
  }

  Future<void> _getData(ServerPrivateInfo spi) async {
    final s = _servers.firstWhere((element) => element.info == spi);
    final state = s.connectionState;
    if (state == ServerConnectionState.failed ||
        state == ServerConnectionState.disconnected) {
      s.connectionState = ServerConnectionState.connecting;
      notifyListeners();
      final time1 = DateTime.now();
      try {
        s.client = await genClient(spi);
        final time2 = DateTime.now();
        logger.info(
            'Connected to [${spi.name}] in [${time2.difference(time1).toString()}].');
        s.connectionState = ServerConnectionState.connected;
        final writeResult = await s.client!
            .run("echo '$shellCmd' > $shellPath && chmod +x $shellPath")
            .string;
        if (writeResult.isNotEmpty) {
          throw Exception(writeResult);
        }
      } catch (e) {
        s.connectionState = ServerConnectionState.failed;
        s.status.failedInfo = '$e ## ';
        logger.warning(e);
      } finally {
        notifyListeners();
      }
    }

    // if client is null, return
    if (s.client == null) return;
    final raw = await s.client!.run("sh $shellPath").string;
    final segments = raw.split(seperator).map((e) => e.trim()).toList();
    if (raw.isEmpty || segments.length == 1) {
      s.connectionState = ServerConnectionState.failed;
      if (s.status.failedInfo == null || s.status.failedInfo!.isEmpty) {
        s.status.failedInfo = 'No data received';
      }
      notifyListeners();
      return;
    }
    segments.removeAt(0);

    try {
      _getCPU(spi, segments[2], segments[7], segments[8]);
      _getMem(spi, segments[6]);
      _getSysVer(spi, segments[1]);
      _getUpTime(spi, segments[3]);
      _getDisk(spi, segments[5]);
      _getTcp(spi, segments[4]);
      _getNetSpeed(spi, segments[0]);
    } catch (e) {
      s.connectionState = ServerConnectionState.failed;
      s.status.failedInfo = e.toString();
      logger.warning(e);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// [raw] example:
  /// Inter-|   Receive                                                |  Transmit
  ///   face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
  ///   lo: 45929941  269112    0    0    0     0          0         0 45929941  269112    0    0    0     0       0          0
  ///   eth0: 48481023  505772    0    0    0     0          0         0 36002262  202307    0    0    0     0       0          0
  /// 1635752901
  Future<void> _getNetSpeed(ServerPrivateInfo spi, String raw) async {
    final info = _servers.firstWhere((e) => e.info == spi);
    info.status.netSpeed.update(await compute(_parseNetSpeed, raw));
  }

  void _getSysVer(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.info == spi);
    final s = raw.split('=');
    if (s.length == 2) {
      info.status.sysVer = s[1].replaceAll('"', '').replaceFirst('\n', '');
    }
  }

  Future<void> _getCPU(ServerPrivateInfo spi, String raw, String tempType,
      String tempValue) async {
    final info = _servers.firstWhere((e) => e.info == spi);
    final cpus = await compute(_parseCPU, raw);

    if (cpus.isNotEmpty) {
      info.status.cpu2Status
          .update(cpus, await compute(_getCPUTemp, [tempType, tempValue]));
    }
  }

  void _getUpTime(ServerPrivateInfo spi, String raw) {
    _servers.firstWhere((e) => e.info == spi).status.uptime =
        raw.split('up ')[1].split(', ')[0];
  }

  Future<void> _getTcp(ServerPrivateInfo spi, String raw) async {
    final info = _servers.firstWhere((e) => e.info == spi);
    final status = await compute(_parseTcp, raw);
    if (status != null) {
      info.status.tcp = status;
    }
  }

  void _getDisk(ServerPrivateInfo spi, String raw) {
    final info = _servers.firstWhere((e) => e.info == spi);
    final list = <DiskInfo>[];
    final items = raw.split('\n');
    for (var item in items) {
      if (items.indexOf(item) == 0 || item.isEmpty) {
        continue;
      }
      final vals = item.split(numReg);
      list.add(DiskInfo(vals[0], vals[5],
          int.parse(vals[4].replaceFirst('%', '')), vals[2], vals[1], vals[3]));
    }
    info.status.disk = list;
  }

  Future<void> _getMem(ServerPrivateInfo spi, String raw) async {
    final info = _servers.firstWhere((e) => e.info == spi);
    final mem = await compute(_parseMem, raw);
    info.status.memory = mem;
  }

  Future<String?> runSnippet(ServerPrivateInfo spi, Snippet snippet) async {
    return await _servers
        .firstWhere((element) => element.info == spi)
        .client!
        .run(snippet.script)
        .string;
  }
}

Memory _parseMem(String raw) {
  final items = raw.split('\n').map((e) => memItemReg.firstMatch(e)).toList();
  final total = int.parse(
      items.firstWhere((e) => e?.group(1) == 'MemTotal:')?.group(2) ?? '1');
  final free = int.parse(
      items.firstWhere((e) => e?.group(1) == 'MemFree:')?.group(2) ?? '0');
  final cached = int.parse(
      items.firstWhere((e) => e?.group(1) == 'Cached:')?.group(2) ?? '0');
  final available = int.parse(
      items.firstWhere((e) => e?.group(1) == 'MemAvailable:')?.group(2) ?? '0');
  return Memory(
      total: total,
      used: total - available,
      free: free,
      cache: cached,
      avail: available);
}

TcpStatus? _parseTcp(String raw) {
  final lines = raw.split('\n');
  final idx = lines.lastWhere((element) => element.startsWith('Tcp:'),
      orElse: () => '');
  if (idx != '') {
    final vals = idx.split(numReg);
    return TcpStatus(vals[5].i, vals[6].i, vals[7].i, vals[8].i);
  }
  return null;
}

List<CpuStatus> _parseCPU(String raw) {
  final List<CpuStatus> cpus = [];

  for (var item in raw.split('\n')) {
    if (item == '') break;
    final id = item.split(' ').first;
    final matches = item.replaceFirst(id, '').trim().split(' ');
    cpus.add(CpuStatus(
        id,
        int.parse(matches[0]),
        int.parse(matches[1]),
        int.parse(matches[2]),
        int.parse(matches[3]),
        int.parse(matches[4]),
        int.parse(matches[5]),
        int.parse(matches[6])));
  }
  return cpus;
}

String _getCPUTemp(List<String> segments) {
  const noMatch = "/sys/class/thermal/thermal_zone*/type";
  final type = segments[0];
  final value = segments[1];
  // Not support to get CPU temperature
  if (value.contains(noMatch) ||
      type.contains(noMatch) ||
      value.isEmpty ||
      type.isEmpty) {
    return '';
  }
  final split = type.split('\n');
  int idx = 0;
  for (var item in split) {
    if (item.contains(cpuTempReg)) {
      break;
    }
    idx++;
  }
  final valueSplited = value.split('\n');
  if (idx >= valueSplited.length) return '';
  final temp = int.tryParse(valueSplited[idx].trim());
  if (temp == null) return '';
  return '${(temp / 1000).toStringAsFixed(1)}°C';
}

List<NetSpeedPart> _parseNetSpeed(String raw) {
  final split = raw.split('\n');
  final deviceCount = split.length - 3;
  if (deviceCount < 1) return [];
  final time = int.parse(split[split.length - 1]);
  final results = <NetSpeedPart>[];
  for (int idx = 2; idx < deviceCount; idx++) {
    final data = split[idx].trim().split(':');
    final device = data.first;
    final bytes = data.last.trim().split(' ');
    bytes.removeWhere((element) => element == '');
    final bytesIn = int.parse(bytes.first);
    final bytesOut = int.parse(bytes[8]);
    results.add(NetSpeedPart(device, bytesIn, bytesOut, time));
  }
  return results;
}
