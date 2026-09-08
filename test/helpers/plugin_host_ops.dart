/// A [PluginHostOps] that records what it was asked and answers what a test
/// scripted.
///
/// Shared, because three test files were each carrying their own copy: the
/// interface has sixteen members now, so a copy per file meant a new host
/// function broke every one of them and each was fixed slightly differently.
///
/// Deliberately not a mock library. What a test wants of this is "what did the
/// plugin ask for", and a list of strings says that more plainly than a
/// verifier does.
library;

import 'package:server_box/data/model/plugin/host_ops.dart';

class FakePluginHostOps implements PluginHostOps {
  final calls = <String>[];
  PluginExecResult execResult = (code: 0, stdout: 'up 3 days', stderr: '');
  String? picked;

  @override
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
  }) async {
    calls.add('exec:$serverId:$script');
    return execResult;
  }

  @override
  Future<List<PluginServerSummary>> listServers() async => const [];

  @override
  Future<void> openTerminal(
    String serverId, {
    String? cmd,
    bool run = false,
  }) async {}

  @override
  Future<PluginFetchResult> fetch({
    required String url,
    required String method,
    Map<String, String> headers = const {},
    String? body,
    String bodyEncoding = 'utf8',
    String? pinSha256,
    bool probeCert = false,
    Duration? timeout,
  }) async => (
    status: 200,
    headers: const <String, String>{},
    body: '',
    bodyEncoding: 'utf8',
    cert: null,
  );

  @override
  void toast(String text, String kind) => calls.add('toast:$kind:$text');

  @override
  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
  }) async {
    calls.add('prompt:$title');
    return (cancelled: false, values: {'user': 'admin'});
  }

  @override
  Future<String?> pickServer() async {
    calls.add('pickServer');
    return picked;
  }

  @override
  Future<String?> clipboardRead() async => 'clip';

  @override
  Future<void> clipboardWrite(String text) async => calls.add('write:$text');

  @override
  Future<void> openServer(String serverId) async =>
      calls.add('open:$serverId');

  @override
  Future<void> goTab(String tab) async => calls.add('tab:$tab');

  @override
  void crumb(String pluginId, String name, String level) =>
      calls.add('crumb:$name');
}
