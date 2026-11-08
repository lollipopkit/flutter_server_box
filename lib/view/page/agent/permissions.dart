import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';

/// fl_pi_llm_ui's [PermissionsPage], for this app's Agent
/// ([LocalPermissionsSource]) and a monitor's Agent mode
/// ([MonitorPermissionsSource]).
abstract final class AgentPermissions {
  static const route = AppRouteArg<void, PermissionsSource>(
    page: PermissionsPage.new,
    path: '/agent/permissions',
  );
}

/// A monitor agent's (`/api/v1/agent/permissions`), over a client of its own:
/// the settings form replaces its client when the server's login changes.
final class MonitorPermissionsSource extends PermissionsSource {
  MonitorPermissionsSource(MonitorHttpCredential cred) : _client = MonitorHttpClient(cred);

  final MonitorHttpClient _client;

  @override
  Future<LlmPermissionsView> load() => _client.agentPermissions();

  @override
  Future<LlmPermissionsView> save(LlmPermissions p) => _client.saveAgentPermissions(p);

  @override
  void dispose() => _client.dispose();
}
