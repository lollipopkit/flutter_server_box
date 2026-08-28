import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';

final class ServiceManagerProbe {
  const ServiceManagerProbe({
    required this.detectedName,
    required this.osName,
    required this.raw,
    this.type,
  });

  final ServiceManagerType? type;
  final String detectedName;
  final String osName;
  final String raw;

  String get description {
    if (detectedName.isEmpty) return osName;
    if (osName.isEmpty) return detectedName;
    return '$detectedName ($osName)';
  }
}

abstract final class ServiceManagerDetector {
  static const script = r'''
if [ -r /etc/os-release ]; then . /etc/os-release; fi
pid1=$(cat /proc/1/comm 2>/dev/null)
if [ -z "$pid1" ]; then pid1=$(ps -p 1 -o comm= 2>/dev/null); fi
pid1=$(printf '%s' "$pid1" | tr -d '[:space:]')

if command -v systemctl >/dev/null 2>&1 &&
   { [ "$pid1" = systemd ] || [ -d /run/systemd/system ]; }; then
  manager=systemd
elif [ "$pid1" = procd ] ||
     { [ -x /sbin/procd ] && command -v ubus >/dev/null 2>&1; }; then
  manager=procd
elif command -v rc-status >/dev/null 2>&1 &&
     command -v rc-service >/dev/null 2>&1; then
  manager=openrc
elif command -v s6-rc >/dev/null 2>&1; then manager=s6
elif command -v sv >/dev/null 2>&1 && [ -d /etc/service ]; then manager=runit
elif command -v initctl >/dev/null 2>&1; then manager=upstart
elif [ "$pid1" = launchd ]; then manager=launchd
elif [ -d /etc/init.d ]; then manager=sysvinit
else manager=${pid1:-unknown}
fi

printf '%s\t%s' "$manager" "${PRETTY_NAME:-}"
''';

  static Future<ServiceManagerProbe> probe(ServerExec exec) async {
    final result = await exec.run(script, entry: 'sh');
    if (!result.succeeded) {
      throw StateError(result.combined.trim());
    }
    return parse(result.stdout);
  }

  static ServiceManagerProbe parse(String raw) {
    final parts = raw.trim().split('\t');
    final id = parts.isEmpty ? '' : parts.first.trim().toLowerCase();
    final os = parts.length > 1 ? parts.sublist(1).join('\t').trim() : '';
    final type = switch (id) {
      'systemd' => ServiceManagerType.systemd,
      'procd' => ServiceManagerType.procd,
      'openrc' => ServiceManagerType.openrc,
      _ => null,
    };
    final display = switch (id) {
      'openrc' => 'OpenRC',
      'unknown' || '' => '',
      _ => id,
    };
    return ServiceManagerProbe(
      type: type,
      detectedName: display,
      osName: os,
      raw: raw,
    );
  }
}
