/// Builds the `Tombstone` protocol buffer Android hands over for a native
/// crash, so the decoder can be exercised without a device that has to crash
/// first.
///
/// Uses the same generated classes the decoder reads with, which is a real
/// limit on what these fixtures prove and is worth stating: they cannot catch
/// the schema being wrong, only the decoding and formatting built on it. The
/// schema is not this repository's to get wrong — it is AOSP's file, vendored
/// verbatim under `third_party/proto` — so the risk that would justify a
/// second hand-written encoder is the risk of that file being stale, which a
/// fixture written against the same file could not detect either.
///
/// A tombstone recorded from a real crash is what would, and is worth
/// capturing the first time one is available from a device.
library;

import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:server_box/src/proto/tombstone.pb.dart' as pb;

Uint8List tombstoneBytes({
  int pid = 0,
  int tid = 0,
  pb.Signal? signal,
  String? abortMessage,
  List<String> causes = const [],
  Map<int, pb.Thread> threads = const {},
}) {
  final t = pb.Tombstone(pid: pid, tid: tid);
  if (signal != null) t.signalInfo = signal;
  if (abortMessage != null) t.abortMessage = abortMessage;
  t.causes.addAll(causes.map((e) => pb.Cause(humanReadable: e)));
  t.threads.addAll(threads);
  return t.writeToBuffer();
}

/// The same, plus the fields that make up most of a real tombstone's bytes and
/// none of its report: memory dumps, every mapping, the open descriptors and
/// the tail of the log buffers.
Uint8List tombstoneWithBulk({
  int pid = 0,
  int tid = 0,
  Map<int, pb.Thread> threads = const {},
}) {
  final t = pb.Tombstone(pid: pid, tid: tid)
    ..arch = pb.Architecture.ARM64
    ..buildFingerprint = 'Android/sdk_gphone64_arm64/emu64a:16/BE1A/13000000:user/release-keys'
    ..revision = '0'
    ..timestamp = '2026-08-29 12:00:00.000000000+0800'
    ..uid = 10123
    ..selinuxLabel = 'u:r:untrusted_app:s0'
    ..processUptime = 91
    ..pageSize = 4096;
  t.commandLine.add('tech.lolli.toolbox');
  t.threads.addAll(threads);
  t.memoryMappings.add(
    pb.MemoryMapping(
      beginAddress: Int64(0x7000000000),
      endAddress: Int64(0x7000010000),
      read: true,
      execute: true,
      mappingName: '/data/app/~~x==/tech.lolli.toolbox-1/lib/arm64/libsbm_ffi.so',
      buildId: '0a1b2c3d',
    ),
  );
  t.openFds.add(pb.FD(fd: 3, path: '/dev/null'));
  t.logBuffers.add(
    pb.LogBuffer(
      name: 'main',
      logs: [
        pb.LogMessage(
          timestamp: '08-29 12:00:00.000',
          pid: pid,
          tid: tid,
          priority: 4,
          tag: 'flutter',
          message: 'a line of logcat',
        ),
      ],
    ),
  );
  return t.writeToBuffer();
}

pb.Signal signalOf({
  required int number,
  required String name,
  required int code,
  required String codeName,
  bool hasFaultAddress = false,
  Int64? faultAddress,
}) {
  final s = pb.Signal(number: number, name: name, code: code, codeName: codeName);
  s.hasFaultAddress = hasFaultAddress;
  // `faultAddress_9` is the generator's name for `fault_address`: the schema's
  // `has_fault_address` getter already takes the name its presence method
  // would have had. See `Tombstone._signal`.
  if (faultAddress != null) s.faultAddress_9 = faultAddress;
  return s;
}

pb.Thread threadOf({
  required int id,
  String? name,
  List<pb.BacktraceFrame> frames = const [],
}) {
  final t = pb.Thread(id: id);
  if (name != null) t.name = name;
  t.currentBacktrace.addAll(frames);
  return t;
}

pb.BacktraceFrame frameOf({
  int relPc = 0,
  String? function,
  int offset = 0,
  String? file,
  String? buildId,
}) {
  final f = pb.BacktraceFrame(relPc: Int64(relPc));
  if (function != null) f.functionName = function;
  if (offset != 0) f.functionOffset = Int64(offset);
  if (file != null) f.fileName = file;
  if (buildId != null) f.buildId = buildId;
  return f;
}
