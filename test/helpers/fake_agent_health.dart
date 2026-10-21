import 'dart:convert';
import 'dart:io';

import 'package:server_box/src/rust/api/protocol.dart';

/// Answers `/api/v1/health` the way a current agent does, which every client
/// asks before signing in; false for any other request, left to the caller.
Future<bool> answerAgentHealth(HttpRequest request) async {
  if (request.uri.path != '/api/v1/health') return false;
  await request.drain<void>();
  request.response
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({
      'status': 'healthy',
      'protocol': monitorProtocol(),
      'min_client_protocol': monitorProtocol(),
    }));
  await request.response.close();
  return true;
}
