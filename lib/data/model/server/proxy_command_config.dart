import 'package:freezed_annotation/freezed_annotation.dart';

part 'proxy_command_config.freezed.dart';
part 'proxy_command_config.g.dart';

/// ProxyCommand configuration for SSH connections
@freezed
abstract class ProxyCommandConfig with _$ProxyCommandConfig {
  const factory ProxyCommandConfig({
    /// Command template with placeholders
    /// Available placeholders: %h (hostname), %p (port), %r (user)
    required String command,

    /// Command arguments (optional, can be included in command)
    List<String>? args,

    /// Working directory for the command
    String? workingDirectory,

    /// Environment variables for the command
    Map<String, String>? environment,

    /// Timeout for command execution
    @Default(Duration(seconds: 30)) Duration timeout,

    /// Whether to retry on connection failure
    @Default(false) bool retryOnFailure,

    /// Maximum retry attempts
    @Default(3) int maxRetries,

    /// Whether the proxy command requires executable download
    @Default(false) bool requiresExecutable,

    /// Executable name for download management
    String? executableName,

    /// Executable download URL
    String? executableDownloadUrl,
  }) = _ProxyCommandConfig;

  factory ProxyCommandConfig.fromJson(Map<String, dynamic> json) => _$ProxyCommandConfigFromJson(json);
}

/// Common proxy command presets
const Map<String, ProxyCommandConfig> proxyCommandPresets = {
  'cloudflare_access': ProxyCommandConfig(
    command: 'cloudflared access ssh --hostname %h',
    requiresExecutable: true,
    executableName: 'cloudflared',
    timeout: Duration(seconds: 15),
  ),
  'ssh_via_bastion': ProxyCommandConfig(
    command: 'ssh -W %h:%p bastion.example.com',
    timeout: Duration(seconds: 10),
  ),
  'nc_netcat': ProxyCommandConfig(command: 'nc %h %p', timeout: Duration(seconds: 10)),
  'socat': ProxyCommandConfig(
    command: 'socat - PROXY:%h:%p,proxyport=8080',
    timeout: Duration(seconds: 10),
  ),
};

/// Extension for ProxyCommandConfig to add utility methods
extension ProxyCommandConfigExtension on ProxyCommandConfig {
  /// Get the final command with placeholders replaced
  String getFinalCommand({required String hostname, required int port, required String user}) {
    var finalCommand = command;
    finalCommand = finalCommand.replaceAll('%h', hostname);
    finalCommand = finalCommand.replaceAll('%p', port.toString());
    finalCommand = finalCommand.replaceAll('%r', user);
    return finalCommand;
  }
}
