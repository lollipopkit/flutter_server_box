final parseFailed = Exception('Parse failed');
final seqReg = RegExp(r'seq=(.+) ttl=(.+) time=(.+) ms');
final packetReg =
    RegExp(r'(.+) packets transmitted, (.+) received, (.+)% packet loss');
final timeReg = RegExp(r'min/avg/max/mdev = (.+)/(.+)/(.+)/(.+) ms');
final timeAlpineReg = RegExp(r'round-trip min/avg/max = (.+)/(.+)/(.+) ms');
final ipReg = RegExp(r' \((\S+)\)');

class PingResult {
  String serverName;
  String? ip;
  List<PingSeqResult>? results;
  PingStatistics? statistic;

  PingResult.parse(this.serverName, String raw) {
    final lines = raw.split('\n');
    lines.removeWhere((element) => element.isEmpty);
    final statisticIndex =
        lines.indexWhere((element) => element.startsWith('---'));
    if (statisticIndex == -1) {
      throw parseFailed;
    }
    final statisticRaw = lines.sublist(statisticIndex + 1);
    statistic = PingStatistics.parse(statisticRaw);
    results = lines
        .sublist(1, statisticIndex)
        .map((e) => PingSeqResult.parse(e))
        .toList();
    ip = ipReg.firstMatch(lines[0])?.group(1);
  }
}

class PingSeqResult {
  int? seq;
  int? ttl;
  double? time;

  PingSeqResult.parse(String raw) {
    final seqMatched = seqReg.firstMatch(raw);
    if (seqMatched == null) {
      throw parseFailed;
    }
    seq = int.tryParse(seqMatched.group(1)!);
    ttl = int.tryParse(seqMatched.group(2)!);
    time = double.tryParse(seqMatched.group(3)!);
  }

  @override
  String toString() {
    return 'seq: $seq, ttl: $ttl, time: $time';
  }
}

class PingStatistics {
  int? total;
  int? received;
  double? loss;
  double? min;
  double? max;
  double? avg;
  double? stddev;

  PingStatistics.parse(List<String> lines) {
    if (lines.isEmpty || lines.length != 2) {
      return;
    }
    final packetMatched = packetReg.firstMatch(lines[0]);
    final timeMatched = timeReg.firstMatch(lines[1]);
    final timeAlpineMatched = timeAlpineReg.firstMatch(lines[1]);
    if (packetMatched == null) {
      return;
    }
    total = int.tryParse(packetMatched.group(1)!);
    received = int.tryParse(packetMatched.group(2)!);
    loss = double.tryParse(packetMatched.group(3)!);
    if (timeMatched != null) {
      min = double.tryParse(timeMatched.group(1)!);
      avg = double.tryParse(timeMatched.group(2)!);
      max = double.tryParse(timeMatched.group(3)!);
      stddev = double.tryParse(timeMatched.group(4)!);
    } else if (timeAlpineMatched != null) {
      min = double.tryParse(timeAlpineMatched.group(1)!);
      avg = double.tryParse(timeAlpineMatched.group(2)!);
      max = double.tryParse(timeAlpineMatched.group(3)!);
    }
  }
}
