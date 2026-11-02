import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/src/rust/api/script.dart' as rust;

part 'monitor_release.g.dart';

/// How long a failed read stands before the next: GitHub allows 60 unsigned
/// requests an hour from one address, and a read is up to
/// [rust.monitorReleaseMaxPages] of them.
const _retryAfter = Duration(minutes: 30);

/// The newest released `monitor` agent, read from this repository's releases
/// once a run: for an agent too old to say itself (`GET /api/v1/update`).
/// Read only while something watches it, so only with such an agent.
///
/// Which release it is, and whether an agent is behind it, is Rust's
/// (`sbm_parser::monitor_agent`), the same the agent answers with.
@Riverpod(keepAlive: true, retry: _noRetry)
Future<String?> monitorLatestRelease(Ref ref) async {
  try {
    return await _read();
  } catch (_) {
    // Read again later rather than keep the failure for the whole run.
    final timer = Timer(_retryAfter, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
    rethrow;
  }
}

Duration? _noRetry(int count, Object error) => null;

Future<String?> _read() async {
  for (var page = 1; page <= rust.monitorReleaseMaxPages(); page++) {
    // [myDio] sets no timeout of its own.
    final resp = await myDio
        .get<String>(rust.monitorReleasesUrl(page: page), options: Options(responseType: ResponseType.plain))
        .timeout(const Duration(seconds: 15));
    final read = rust.monitorReleasePage(listing: resp.data ?? '');
    if (read.newest != null || !read.readOn) return read.newest;
  }
  return null;
}

/// Whether an agent reporting [running] is older than [latest]; false when
/// either is unknown or unreadable.
bool monitorOutdated(String? running, String? latest) {
  if (running == null || latest == null) return false;
  return rust.monitorOutdated(running: running, latest: latest);
}
