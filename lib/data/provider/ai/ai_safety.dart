import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

@immutable
enum AiRedactionMode {
  placeholder,
  none,
}

@immutable
enum AiCommandRisk {
  low,
  medium,
  high,
}

extension AiCommandRiskX on AiCommandRisk {
  static AiCommandRisk? tryParse(Object? raw) {
    if (raw is! String) return null;
    final s = raw.trim().toLowerCase();
    return switch (s) {
      'low' => AiCommandRisk.low,
      'medium' => AiCommandRisk.medium,
      'high' => AiCommandRisk.high,
      _ => null,
    };
  }

  AiCommandRisk max(AiCommandRisk other) => index >= other.index ? this : other;
}

abstract final class AiSafety {
  const AiSafety._();

  static String redact(
    String input, {
    AiRedactionMode mode = AiRedactionMode.placeholder,
    Spi? spi,
  }) {
    if (mode == AiRedactionMode.none) return input;
    if (input.isEmpty) return input;

    var out = input;

    out = _redactPrivateKeyBlocks(out);
    out = _redactBearerTokens(out);
    out = _redactApiKeys(out);

    if (spi != null) {
      out = _redactSpiIdentity(out, spi);
    }

    return out;
  }

  static List<String> redactBlocks(
    List<String> blocks, {
    AiRedactionMode mode = AiRedactionMode.placeholder,
    Spi? spi,
  }) {
    if (blocks.isEmpty) return const [];
    return [
      for (final b in blocks) redact(b, mode: mode, spi: spi),
    ];
  }

  static AiCommandRisk classifyRisk(String command) {
    final raw = command.trim();
    if (raw.isEmpty) return AiCommandRisk.low;

    final s = raw.toLowerCase();

    // High-risk destructive patterns.
    if (_rxForkBomb.hasMatch(s)) return AiCommandRisk.high;
    if (_rxMkfs.hasMatch(s)) return AiCommandRisk.high;
    if (_rxDdToBlockDevice.hasMatch(s)) return AiCommandRisk.high;
    if (_rxRmRf.hasMatch(s)) return AiCommandRisk.high;
    if (_rxChmodChownRoot.hasMatch(s)) return AiCommandRisk.high;
    if (_rxIptablesFlush.hasMatch(s) || _rxNftFlush.hasMatch(s)) return AiCommandRisk.high;
    if (_rxDockerSystemPruneAll.hasMatch(s) || _rxPodmanSystemPruneAll.hasMatch(s)) return AiCommandRisk.high;

    // Medium-risk operational patterns.
    if (_rxRebootShutdown.hasMatch(s)) return AiCommandRisk.medium;
    if (_rxSystemctlStopRestart.hasMatch(s)) return AiCommandRisk.medium;
    if (_rxKill.hasMatch(s)) return AiCommandRisk.medium;
    if (_rxDockerStopRm.hasMatch(s) || _rxPodmanStopRm.hasMatch(s)) return AiCommandRisk.medium;

    return AiCommandRisk.low;
  }

  static String _redactPrivateKeyBlocks(String input) {
    return input.replaceAllMapped(_rxPrivateKeyBlock, (_) => '<PRIVATE_KEY_BLOCK>');
  }

  static String _redactBearerTokens(String input) {
    var out = input;
    out = out.replaceAllMapped(
      _rxAuthorizationBearer,
      (m) => '${m.group(1)}Bearer <TOKEN>',
    );
    out = out.replaceAllMapped(
      _rxBearerInline,
      (m) => 'Bearer <TOKEN>',
    );
    return out;
  }

  static String _redactApiKeys(String input) {
    // Keep it conservative; only match common patterns with clear prefixes.
    var out = input;
    out = out.replaceAllMapped(_rxOpenAiKey, (_) => '<API_KEY>');
    out = out.replaceAllMapped(_rxAwsAccessKeyId, (_) => '<AWS_ACCESS_KEY_ID>');
    return out;
  }

  static String _redactSpiIdentity(String input, Spi spi) {
    var out = input;

    final ip = spi.ip;
    final user = spi.user;
    final port = spi.port;

    if (user.isNotEmpty && ip.isNotEmpty) {
      out = out.replaceAll('$user@$ip:$port', '<USER_AT_HOST_PORT>');
      out = out.replaceAll('$user@$ip', '<USER_AT_HOST>');
    }

    if (ip.isNotEmpty) {
      out = out.replaceAll(ip, '<IP>');
    }

    if (user.isNotEmpty) {
      out = out.replaceAll(user, '<USER>');
    }

    return out;
  }
}

final _rxPrivateKeyBlock = RegExp(
  r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9 ]*PRIVATE KEY-----',
  multiLine: true,
);

final _rxAuthorizationBearer = RegExp(
  r'(authorization\s*:\s*)bearer\s+[^\s\n\r]+',
  multiLine: true,
  caseSensitive: false,
);

final _rxBearerInline = RegExp(
  r'\bbearer\s+[^\s\n\r]+',
  caseSensitive: false,
);

final _rxOpenAiKey = RegExp(r'\bsk-[A-Za-z0-9]{16,}\b');

final _rxAwsAccessKeyId = RegExp(r'\bAKIA[0-9A-Z]{16}\b');

final _rxForkBomb = RegExp(r':\s*\(\s*\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:');

final _rxMkfs = RegExp(r'\bmkfs(\.[a-z0-9_-]+)?\b');

final _rxDdToBlockDevice = RegExp(r'\bdd\b[^\n\r]*\bof\s*=\s*/dev/');

final _rxRmRf = RegExp(r'\brm\b[^\n\r]*\s-[a-z-]*r[a-z-]*f[a-z-]*\b');

final _rxChmodChownRoot = RegExp(r'\b(chmod|chown)\b[^\n\r]*\s-\w*r\w*\b[^\n\r]*\s/\b');

final _rxIptablesFlush = RegExp(r'\biptables\b[^\n\r]*(\s-(f|x)\b|\s--flush\b)');

final _rxNftFlush = RegExp(r'\bnft\b[^\n\r]*\bflush\s+ruleset\b');

final _rxDockerSystemPruneAll = RegExp(r'\bdocker\b[^\n\r]*\bsystem\s+prune\b[^\n\r]*\s-a\b');

final _rxPodmanSystemPruneAll = RegExp(r'\bpodman\b[^\n\r]*\bsystem\s+prune\b[^\n\r]*\s-a\b');

final _rxRebootShutdown = RegExp(r'\b(reboot|poweroff|halt|shutdown)\b');

final _rxSystemctlStopRestart = RegExp(r'\bsystemctl\b[^\n\r]*\b(stop|restart)\b');

final _rxKill = RegExp(r'\b(kill|killall|pkill)\b');

final _rxDockerStopRm = RegExp(r'\bdocker\b[^\n\r]*\b(stop|rm)\b');

final _rxPodmanStopRm = RegExp(r'\bpodman\b[^\n\r]*\b(stop|rm)\b');
