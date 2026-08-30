// This is a generated file - do not edit.
//
// Generated from tombstone.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use architectureDescriptor instead')
const Architecture$json = {
  '1': 'Architecture',
  '2': [
    {'1': 'ARM32', '2': 0},
    {'1': 'ARM64', '2': 1},
    {'1': 'X86', '2': 2},
    {'1': 'X86_64', '2': 3},
    {'1': 'RISCV64', '2': 4},
    {'1': 'NONE', '2': 5},
  ],
  '4': [
    {'1': 6, '2': 999},
  ],
};

/// Descriptor for `Architecture`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List architectureDescriptor = $convert.base64Decode(
    'CgxBcmNoaXRlY3R1cmUSCQoFQVJNMzIQABIJCgVBUk02NBABEgcKA1g4NhACEgoKBlg4Nl82NB'
    'ADEgsKB1JJU0NWNjQQBBIICgROT05FEAUiBQgGEOcH');

@$core.Deprecated('Use crashDetailDescriptor instead')
const CrashDetail$json = {
  '1': 'CrashDetail',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 12, '10': 'name'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
  '9': [
    {'1': 3, '2': 1000},
  ],
};

/// Descriptor for `CrashDetail`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List crashDetailDescriptor = $convert.base64Decode(
    'CgtDcmFzaERldGFpbBISCgRuYW1lGAEgASgMUgRuYW1lEhIKBGRhdGEYAiABKAxSBGRhdGFKBQ'
    'gDEOgH');

@$core.Deprecated('Use stackHistoryBufferEntryDescriptor instead')
const StackHistoryBufferEntry$json = {
  '1': 'StackHistoryBufferEntry',
  '2': [
    {
      '1': 'addr',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.BacktraceFrame',
      '10': 'addr'
    },
    {'1': 'fp', '3': 2, '4': 1, '5': 4, '10': 'fp'},
    {'1': 'tag', '3': 3, '4': 1, '5': 4, '10': 'tag'},
  ],
  '9': [
    {'1': 4, '2': 1000},
  ],
};

/// Descriptor for `StackHistoryBufferEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stackHistoryBufferEntryDescriptor =
    $convert.base64Decode(
        'ChdTdGFja0hpc3RvcnlCdWZmZXJFbnRyeRIjCgRhZGRyGAEgASgLMg8uQmFja3RyYWNlRnJhbW'
        'VSBGFkZHISDgoCZnAYAiABKARSAmZwEhAKA3RhZxgDIAEoBFIDdGFnSgUIBBDoBw==');

@$core.Deprecated('Use stackHistoryBufferDescriptor instead')
const StackHistoryBuffer$json = {
  '1': 'StackHistoryBuffer',
  '2': [
    {'1': 'tid', '3': 1, '4': 1, '5': 4, '10': 'tid'},
    {
      '1': 'entries',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.StackHistoryBufferEntry',
      '10': 'entries'
    },
  ],
  '9': [
    {'1': 3, '2': 1000},
  ],
};

/// Descriptor for `StackHistoryBuffer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stackHistoryBufferDescriptor = $convert.base64Decode(
    'ChJTdGFja0hpc3RvcnlCdWZmZXISEAoDdGlkGAEgASgEUgN0aWQSMgoHZW50cmllcxgCIAMoCz'
    'IYLlN0YWNrSGlzdG9yeUJ1ZmZlckVudHJ5UgdlbnRyaWVzSgUIAxDoBw==');

@$core.Deprecated('Use tombstoneDescriptor instead')
const Tombstone$json = {
  '1': 'Tombstone',
  '2': [
    {'1': 'arch', '3': 1, '4': 1, '5': 14, '6': '.Architecture', '10': 'arch'},
    {
      '1': 'guest_arch',
      '3': 24,
      '4': 1,
      '5': 14,
      '6': '.Architecture',
      '10': 'guestArch'
    },
    {
      '1': 'build_fingerprint',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'buildFingerprint'
    },
    {'1': 'revision', '3': 3, '4': 1, '5': 9, '10': 'revision'},
    {'1': 'timestamp', '3': 4, '4': 1, '5': 9, '10': 'timestamp'},
    {'1': 'pid', '3': 5, '4': 1, '5': 13, '10': 'pid'},
    {'1': 'tid', '3': 6, '4': 1, '5': 13, '10': 'tid'},
    {'1': 'uid', '3': 7, '4': 1, '5': 13, '10': 'uid'},
    {'1': 'selinux_label', '3': 8, '4': 1, '5': 9, '10': 'selinuxLabel'},
    {'1': 'command_line', '3': 9, '4': 3, '5': 9, '10': 'commandLine'},
    {'1': 'process_uptime', '3': 20, '4': 1, '5': 13, '10': 'processUptime'},
    {
      '1': 'signal_info',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.Signal',
      '10': 'signalInfo'
    },
    {'1': 'abort_message', '3': 14, '4': 1, '5': 9, '10': 'abortMessage'},
    {
      '1': 'crash_details',
      '3': 21,
      '4': 3,
      '5': 11,
      '6': '.CrashDetail',
      '10': 'crashDetails'
    },
    {'1': 'causes', '3': 15, '4': 3, '5': 11, '6': '.Cause', '10': 'causes'},
    {
      '1': 'threads',
      '3': 16,
      '4': 3,
      '5': 11,
      '6': '.Tombstone.ThreadsEntry',
      '10': 'threads'
    },
    {
      '1': 'guest_threads',
      '3': 25,
      '4': 3,
      '5': 11,
      '6': '.Tombstone.GuestThreadsEntry',
      '10': 'guestThreads'
    },
    {
      '1': 'memory_mappings',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.MemoryMapping',
      '10': 'memoryMappings'
    },
    {
      '1': 'log_buffers',
      '3': 18,
      '4': 3,
      '5': 11,
      '6': '.LogBuffer',
      '10': 'logBuffers'
    },
    {'1': 'open_fds', '3': 19, '4': 3, '5': 11, '6': '.FD', '10': 'openFds'},
    {'1': 'page_size', '3': 22, '4': 1, '5': 13, '10': 'pageSize'},
    {
      '1': 'has_been_16kb_mode',
      '3': 23,
      '4': 1,
      '5': 8,
      '10': 'hasBeen16kbMode'
    },
    {
      '1': 'stack_history_buffer',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.StackHistoryBuffer',
      '10': 'stackHistoryBuffer'
    },
  ],
  '3': [Tombstone_ThreadsEntry$json, Tombstone_GuestThreadsEntry$json],
  '9': [
    {'1': 27, '2': 1000},
  ],
};

@$core.Deprecated('Use tombstoneDescriptor instead')
const Tombstone_ThreadsEntry$json = {
  '1': 'ThreadsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 13, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.Thread', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use tombstoneDescriptor instead')
const Tombstone_GuestThreadsEntry$json = {
  '1': 'GuestThreadsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 13, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.Thread', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Tombstone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tombstoneDescriptor = $convert.base64Decode(
    'CglUb21ic3RvbmUSIQoEYXJjaBgBIAEoDjINLkFyY2hpdGVjdHVyZVIEYXJjaBIsCgpndWVzdF'
    '9hcmNoGBggASgOMg0uQXJjaGl0ZWN0dXJlUglndWVzdEFyY2gSKwoRYnVpbGRfZmluZ2VycHJp'
    'bnQYAiABKAlSEGJ1aWxkRmluZ2VycHJpbnQSGgoIcmV2aXNpb24YAyABKAlSCHJldmlzaW9uEh'
    'wKCXRpbWVzdGFtcBgEIAEoCVIJdGltZXN0YW1wEhAKA3BpZBgFIAEoDVIDcGlkEhAKA3RpZBgG'
    'IAEoDVIDdGlkEhAKA3VpZBgHIAEoDVIDdWlkEiMKDXNlbGludXhfbGFiZWwYCCABKAlSDHNlbG'
    'ludXhMYWJlbBIhCgxjb21tYW5kX2xpbmUYCSADKAlSC2NvbW1hbmRMaW5lEiUKDnByb2Nlc3Nf'
    'dXB0aW1lGBQgASgNUg1wcm9jZXNzVXB0aW1lEigKC3NpZ25hbF9pbmZvGAogASgLMgcuU2lnbm'
    'FsUgpzaWduYWxJbmZvEiMKDWFib3J0X21lc3NhZ2UYDiABKAlSDGFib3J0TWVzc2FnZRIxCg1j'
    'cmFzaF9kZXRhaWxzGBUgAygLMgwuQ3Jhc2hEZXRhaWxSDGNyYXNoRGV0YWlscxIeCgZjYXVzZX'
    'MYDyADKAsyBi5DYXVzZVIGY2F1c2VzEjEKB3RocmVhZHMYECADKAsyFy5Ub21ic3RvbmUuVGhy'
    'ZWFkc0VudHJ5Ugd0aHJlYWRzEkEKDWd1ZXN0X3RocmVhZHMYGSADKAsyHC5Ub21ic3RvbmUuR3'
    'Vlc3RUaHJlYWRzRW50cnlSDGd1ZXN0VGhyZWFkcxI3Cg9tZW1vcnlfbWFwcGluZ3MYESADKAsy'
    'Di5NZW1vcnlNYXBwaW5nUg5tZW1vcnlNYXBwaW5ncxIrCgtsb2dfYnVmZmVycxgSIAMoCzIKLk'
    'xvZ0J1ZmZlclIKbG9nQnVmZmVycxIeCghvcGVuX2ZkcxgTIAMoCzIDLkZEUgdvcGVuRmRzEhsK'
    'CXBhZ2Vfc2l6ZRgWIAEoDVIIcGFnZVNpemUSKwoSaGFzX2JlZW5fMTZrYl9tb2RlGBcgASgIUg'
    '9oYXNCZWVuMTZrYk1vZGUSRQoUc3RhY2tfaGlzdG9yeV9idWZmZXIYGiABKAsyEy5TdGFja0hp'
    'c3RvcnlCdWZmZXJSEnN0YWNrSGlzdG9yeUJ1ZmZlchpDCgxUaHJlYWRzRW50cnkSEAoDa2V5GA'
    'EgASgNUgNrZXkSHQoFdmFsdWUYAiABKAsyBy5UaHJlYWRSBXZhbHVlOgI4ARpIChFHdWVzdFRo'
    'cmVhZHNFbnRyeRIQCgNrZXkYASABKA1SA2tleRIdCgV2YWx1ZRgCIAEoCzIHLlRocmVhZFIFdm'
    'FsdWU6AjgBSgUIGxDoBw==');

@$core.Deprecated('Use signalDescriptor instead')
const Signal$json = {
  '1': 'Signal',
  '2': [
    {'1': 'number', '3': 1, '4': 1, '5': 5, '10': 'number'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'code', '3': 3, '4': 1, '5': 5, '10': 'code'},
    {'1': 'code_name', '3': 4, '4': 1, '5': 9, '10': 'codeName'},
    {'1': 'has_sender', '3': 5, '4': 1, '5': 8, '10': 'hasSender'},
    {'1': 'sender_uid', '3': 6, '4': 1, '5': 5, '10': 'senderUid'},
    {'1': 'sender_pid', '3': 7, '4': 1, '5': 5, '10': 'senderPid'},
    {'1': 'has_fault_address', '3': 8, '4': 1, '5': 8, '10': 'hasFaultAddress'},
    {'1': 'fault_address', '3': 9, '4': 1, '5': 4, '10': 'faultAddress'},
    {
      '1': 'fault_adjacent_metadata',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.MemoryDump',
      '10': 'faultAdjacentMetadata'
    },
  ],
  '9': [
    {'1': 11, '2': 1000},
  ],
};

/// Descriptor for `Signal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signalDescriptor = $convert.base64Decode(
    'CgZTaWduYWwSFgoGbnVtYmVyGAEgASgFUgZudW1iZXISEgoEbmFtZRgCIAEoCVIEbmFtZRISCg'
    'Rjb2RlGAMgASgFUgRjb2RlEhsKCWNvZGVfbmFtZRgEIAEoCVIIY29kZU5hbWUSHQoKaGFzX3Nl'
    'bmRlchgFIAEoCFIJaGFzU2VuZGVyEh0KCnNlbmRlcl91aWQYBiABKAVSCXNlbmRlclVpZBIdCg'
    'pzZW5kZXJfcGlkGAcgASgFUglzZW5kZXJQaWQSKgoRaGFzX2ZhdWx0X2FkZHJlc3MYCCABKAhS'
    'D2hhc0ZhdWx0QWRkcmVzcxIjCg1mYXVsdF9hZGRyZXNzGAkgASgEUgxmYXVsdEFkZHJlc3MSQw'
    'oXZmF1bHRfYWRqYWNlbnRfbWV0YWRhdGEYCiABKAsyCy5NZW1vcnlEdW1wUhVmYXVsdEFkamFj'
    'ZW50TWV0YWRhdGFKBQgLEOgH');

@$core.Deprecated('Use heapObjectDescriptor instead')
const HeapObject$json = {
  '1': 'HeapObject',
  '2': [
    {'1': 'address', '3': 1, '4': 1, '5': 4, '10': 'address'},
    {'1': 'size', '3': 2, '4': 1, '5': 4, '10': 'size'},
    {'1': 'allocation_tid', '3': 3, '4': 1, '5': 4, '10': 'allocationTid'},
    {
      '1': 'allocation_backtrace',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.BacktraceFrame',
      '10': 'allocationBacktrace'
    },
    {'1': 'deallocation_tid', '3': 5, '4': 1, '5': 4, '10': 'deallocationTid'},
    {
      '1': 'deallocation_backtrace',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.BacktraceFrame',
      '10': 'deallocationBacktrace'
    },
  ],
};

/// Descriptor for `HeapObject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heapObjectDescriptor = $convert.base64Decode(
    'CgpIZWFwT2JqZWN0EhgKB2FkZHJlc3MYASABKARSB2FkZHJlc3MSEgoEc2l6ZRgCIAEoBFIEc2'
    'l6ZRIlCg5hbGxvY2F0aW9uX3RpZBgDIAEoBFINYWxsb2NhdGlvblRpZBJCChRhbGxvY2F0aW9u'
    'X2JhY2t0cmFjZRgEIAMoCzIPLkJhY2t0cmFjZUZyYW1lUhNhbGxvY2F0aW9uQmFja3RyYWNlEi'
    'kKEGRlYWxsb2NhdGlvbl90aWQYBSABKARSD2RlYWxsb2NhdGlvblRpZBJGChZkZWFsbG9jYXRp'
    'b25fYmFja3RyYWNlGAYgAygLMg8uQmFja3RyYWNlRnJhbWVSFWRlYWxsb2NhdGlvbkJhY2t0cm'
    'FjZQ==');

@$core.Deprecated('Use memoryErrorDescriptor instead')
const MemoryError$json = {
  '1': 'MemoryError',
  '2': [
    {
      '1': 'tool',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.MemoryError.Tool',
      '10': 'tool'
    },
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.MemoryError.Type',
      '10': 'type'
    },
    {
      '1': 'heap',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.HeapObject',
      '9': 0,
      '10': 'heap'
    },
  ],
  '4': [MemoryError_Tool$json, MemoryError_Type$json],
  '8': [
    {'1': 'location'},
  ],
  '9': [
    {'1': 4, '2': 1000},
  ],
};

@$core.Deprecated('Use memoryErrorDescriptor instead')
const MemoryError_Tool$json = {
  '1': 'Tool',
  '2': [
    {'1': 'GWP_ASAN', '2': 0},
    {'1': 'SCUDO', '2': 1},
  ],
  '4': [
    {'1': 2, '2': 999},
  ],
};

@$core.Deprecated('Use memoryErrorDescriptor instead')
const MemoryError_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'USE_AFTER_FREE', '2': 1},
    {'1': 'DOUBLE_FREE', '2': 2},
    {'1': 'INVALID_FREE', '2': 3},
    {'1': 'BUFFER_OVERFLOW', '2': 4},
    {'1': 'BUFFER_UNDERFLOW', '2': 5},
  ],
  '4': [
    {'1': 6, '2': 999},
  ],
};

/// Descriptor for `MemoryError`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memoryErrorDescriptor = $convert.base64Decode(
    'CgtNZW1vcnlFcnJvchIlCgR0b29sGAEgASgOMhEuTWVtb3J5RXJyb3IuVG9vbFIEdG9vbBIlCg'
    'R0eXBlGAIgASgOMhEuTWVtb3J5RXJyb3IuVHlwZVIEdHlwZRIhCgRoZWFwGAMgASgLMgsuSGVh'
    'cE9iamVjdEgAUgRoZWFwIiYKBFRvb2wSDAoIR1dQX0FTQU4QABIJCgVTQ1VETxABIgUIAhDnBy'
    'J8CgRUeXBlEgsKB1VOS05PV04QABISCg5VU0VfQUZURVJfRlJFRRABEg8KC0RPVUJMRV9GUkVF'
    'EAISEAoMSU5WQUxJRF9GUkVFEAMSEwoPQlVGRkVSX09WRVJGTE9XEAQSFAoQQlVGRkVSX1VORE'
    'VSRkxPVxAFIgUIBhDnB0IKCghsb2NhdGlvbkoFCAQQ6Ac=');

@$core.Deprecated('Use causeDescriptor instead')
const Cause$json = {
  '1': 'Cause',
  '2': [
    {'1': 'human_readable', '3': 1, '4': 1, '5': 9, '10': 'humanReadable'},
    {
      '1': 'memory_error',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.MemoryError',
      '9': 0,
      '10': 'memoryError'
    },
  ],
  '8': [
    {'1': 'details'},
  ],
  '9': [
    {'1': 3, '2': 1000},
  ],
};

/// Descriptor for `Cause`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List causeDescriptor = $convert.base64Decode(
    'CgVDYXVzZRIlCg5odW1hbl9yZWFkYWJsZRgBIAEoCVINaHVtYW5SZWFkYWJsZRIxCgxtZW1vcn'
    'lfZXJyb3IYAiABKAsyDC5NZW1vcnlFcnJvckgAUgttZW1vcnlFcnJvckIJCgdkZXRhaWxzSgUI'
    'AxDoBw==');

@$core.Deprecated('Use registerDescriptor instead')
const Register$json = {
  '1': 'Register',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'u64', '3': 2, '4': 1, '5': 4, '10': 'u64'},
  ],
  '9': [
    {'1': 3, '2': 1000},
  ],
};

/// Descriptor for `Register`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDescriptor = $convert.base64Decode(
    'CghSZWdpc3RlchISCgRuYW1lGAEgASgJUgRuYW1lEhAKA3U2NBgCIAEoBFIDdTY0SgUIAxDoBw'
    '==');

@$core.Deprecated('Use threadDescriptor instead')
const Thread$json = {
  '1': 'Thread',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'registers',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.Register',
      '10': 'registers'
    },
    {'1': 'backtrace_note', '3': 7, '4': 3, '5': 9, '10': 'backtraceNote'},
    {
      '1': 'unreadable_elf_files',
      '3': 9,
      '4': 3,
      '5': 9,
      '10': 'unreadableElfFiles'
    },
    {
      '1': 'current_backtrace',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.BacktraceFrame',
      '10': 'currentBacktrace'
    },
    {
      '1': 'memory_dump',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.MemoryDump',
      '10': 'memoryDump'
    },
    {'1': 'tagged_addr_ctrl', '3': 6, '4': 1, '5': 3, '10': 'taggedAddrCtrl'},
    {'1': 'pac_enabled_keys', '3': 8, '4': 1, '5': 3, '10': 'pacEnabledKeys'},
  ],
  '9': [
    {'1': 10, '2': 1000},
  ],
};

/// Descriptor for `Thread`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadDescriptor = $convert.base64Decode(
    'CgZUaHJlYWQSDgoCaWQYASABKAVSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSJwoJcmVnaXN0ZX'
    'JzGAMgAygLMgkuUmVnaXN0ZXJSCXJlZ2lzdGVycxIlCg5iYWNrdHJhY2Vfbm90ZRgHIAMoCVIN'
    'YmFja3RyYWNlTm90ZRIwChR1bnJlYWRhYmxlX2VsZl9maWxlcxgJIAMoCVISdW5yZWFkYWJsZU'
    'VsZkZpbGVzEjwKEWN1cnJlbnRfYmFja3RyYWNlGAQgAygLMg8uQmFja3RyYWNlRnJhbWVSEGN1'
    'cnJlbnRCYWNrdHJhY2USLAoLbWVtb3J5X2R1bXAYBSADKAsyCy5NZW1vcnlEdW1wUgptZW1vcn'
    'lEdW1wEigKEHRhZ2dlZF9hZGRyX2N0cmwYBiABKANSDnRhZ2dlZEFkZHJDdHJsEigKEHBhY19l'
    'bmFibGVkX2tleXMYCCABKANSDnBhY0VuYWJsZWRLZXlzSgUIChDoBw==');

@$core.Deprecated('Use backtraceFrameDescriptor instead')
const BacktraceFrame$json = {
  '1': 'BacktraceFrame',
  '2': [
    {'1': 'rel_pc', '3': 1, '4': 1, '5': 4, '10': 'relPc'},
    {'1': 'pc', '3': 2, '4': 1, '5': 4, '10': 'pc'},
    {'1': 'sp', '3': 3, '4': 1, '5': 4, '10': 'sp'},
    {'1': 'function_name', '3': 4, '4': 1, '5': 9, '10': 'functionName'},
    {'1': 'function_offset', '3': 5, '4': 1, '5': 4, '10': 'functionOffset'},
    {'1': 'file_name', '3': 6, '4': 1, '5': 9, '10': 'fileName'},
    {'1': 'file_map_offset', '3': 7, '4': 1, '5': 4, '10': 'fileMapOffset'},
    {'1': 'build_id', '3': 8, '4': 1, '5': 9, '10': 'buildId'},
  ],
  '9': [
    {'1': 9, '2': 1000},
  ],
};

/// Descriptor for `BacktraceFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backtraceFrameDescriptor = $convert.base64Decode(
    'Cg5CYWNrdHJhY2VGcmFtZRIVCgZyZWxfcGMYASABKARSBXJlbFBjEg4KAnBjGAIgASgEUgJwYx'
    'IOCgJzcBgDIAEoBFICc3ASIwoNZnVuY3Rpb25fbmFtZRgEIAEoCVIMZnVuY3Rpb25OYW1lEicK'
    'D2Z1bmN0aW9uX29mZnNldBgFIAEoBFIOZnVuY3Rpb25PZmZzZXQSGwoJZmlsZV9uYW1lGAYgAS'
    'gJUghmaWxlTmFtZRImCg9maWxlX21hcF9vZmZzZXQYByABKARSDWZpbGVNYXBPZmZzZXQSGQoI'
    'YnVpbGRfaWQYCCABKAlSB2J1aWxkSWRKBQgJEOgH');

@$core.Deprecated('Use armMTEMetadataDescriptor instead')
const ArmMTEMetadata$json = {
  '1': 'ArmMTEMetadata',
  '2': [
    {'1': 'memory_tags', '3': 1, '4': 1, '5': 12, '10': 'memoryTags'},
  ],
  '9': [
    {'1': 2, '2': 1000},
  ],
};

/// Descriptor for `ArmMTEMetadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List armMTEMetadataDescriptor = $convert.base64Decode(
    'Cg5Bcm1NVEVNZXRhZGF0YRIfCgttZW1vcnlfdGFncxgBIAEoDFIKbWVtb3J5VGFnc0oFCAIQ6A'
    'c=');

@$core.Deprecated('Use memoryDumpDescriptor instead')
const MemoryDump$json = {
  '1': 'MemoryDump',
  '2': [
    {'1': 'register_name', '3': 1, '4': 1, '5': 9, '10': 'registerName'},
    {'1': 'mapping_name', '3': 2, '4': 1, '5': 9, '10': 'mappingName'},
    {'1': 'begin_address', '3': 3, '4': 1, '5': 4, '10': 'beginAddress'},
    {'1': 'memory', '3': 4, '4': 1, '5': 12, '10': 'memory'},
    {
      '1': 'arm_mte_metadata',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.ArmMTEMetadata',
      '9': 0,
      '10': 'armMteMetadata'
    },
  ],
  '8': [
    {'1': 'metadata'},
  ],
  '9': [
    {'1': 5, '2': 6},
    {'1': 7, '2': 1000},
  ],
};

/// Descriptor for `MemoryDump`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memoryDumpDescriptor = $convert.base64Decode(
    'CgpNZW1vcnlEdW1wEiMKDXJlZ2lzdGVyX25hbWUYASABKAlSDHJlZ2lzdGVyTmFtZRIhCgxtYX'
    'BwaW5nX25hbWUYAiABKAlSC21hcHBpbmdOYW1lEiMKDWJlZ2luX2FkZHJlc3MYAyABKARSDGJl'
    'Z2luQWRkcmVzcxIWCgZtZW1vcnkYBCABKAxSBm1lbW9yeRI7ChBhcm1fbXRlX21ldGFkYXRhGA'
    'YgASgLMg8uQXJtTVRFTWV0YWRhdGFIAFIOYXJtTXRlTWV0YWRhdGFCCgoIbWV0YWRhdGFKBAgF'
    'EAZKBQgHEOgH');

@$core.Deprecated('Use memoryMappingDescriptor instead')
const MemoryMapping$json = {
  '1': 'MemoryMapping',
  '2': [
    {'1': 'begin_address', '3': 1, '4': 1, '5': 4, '10': 'beginAddress'},
    {'1': 'end_address', '3': 2, '4': 1, '5': 4, '10': 'endAddress'},
    {'1': 'offset', '3': 3, '4': 1, '5': 4, '10': 'offset'},
    {'1': 'read', '3': 4, '4': 1, '5': 8, '10': 'read'},
    {'1': 'write', '3': 5, '4': 1, '5': 8, '10': 'write'},
    {'1': 'execute', '3': 6, '4': 1, '5': 8, '10': 'execute'},
    {'1': 'mapping_name', '3': 7, '4': 1, '5': 9, '10': 'mappingName'},
    {'1': 'build_id', '3': 8, '4': 1, '5': 9, '10': 'buildId'},
    {'1': 'load_bias', '3': 9, '4': 1, '5': 4, '10': 'loadBias'},
  ],
  '9': [
    {'1': 10, '2': 1000},
  ],
};

/// Descriptor for `MemoryMapping`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memoryMappingDescriptor = $convert.base64Decode(
    'Cg1NZW1vcnlNYXBwaW5nEiMKDWJlZ2luX2FkZHJlc3MYASABKARSDGJlZ2luQWRkcmVzcxIfCg'
    'tlbmRfYWRkcmVzcxgCIAEoBFIKZW5kQWRkcmVzcxIWCgZvZmZzZXQYAyABKARSBm9mZnNldBIS'
    'CgRyZWFkGAQgASgIUgRyZWFkEhQKBXdyaXRlGAUgASgIUgV3cml0ZRIYCgdleGVjdXRlGAYgAS'
    'gIUgdleGVjdXRlEiEKDG1hcHBpbmdfbmFtZRgHIAEoCVILbWFwcGluZ05hbWUSGQoIYnVpbGRf'
    'aWQYCCABKAlSB2J1aWxkSWQSGwoJbG9hZF9iaWFzGAkgASgEUghsb2FkQmlhc0oFCAoQ6Ac=');

@$core.Deprecated('Use fDDescriptor instead')
const FD$json = {
  '1': 'FD',
  '2': [
    {'1': 'fd', '3': 1, '4': 1, '5': 5, '10': 'fd'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'owner', '3': 3, '4': 1, '5': 9, '10': 'owner'},
    {'1': 'tag', '3': 4, '4': 1, '5': 4, '10': 'tag'},
  ],
  '9': [
    {'1': 5, '2': 1000},
  ],
};

/// Descriptor for `FD`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fDDescriptor = $convert.base64Decode(
    'CgJGRBIOCgJmZBgBIAEoBVICZmQSEgoEcGF0aBgCIAEoCVIEcGF0aBIUCgVvd25lchgDIAEoCV'
    'IFb3duZXISEAoDdGFnGAQgASgEUgN0YWdKBQgFEOgH');

@$core.Deprecated('Use logBufferDescriptor instead')
const LogBuffer$json = {
  '1': 'LogBuffer',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'logs', '3': 2, '4': 3, '5': 11, '6': '.LogMessage', '10': 'logs'},
  ],
  '9': [
    {'1': 3, '2': 1000},
  ],
};

/// Descriptor for `LogBuffer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logBufferDescriptor = $convert.base64Decode(
    'CglMb2dCdWZmZXISEgoEbmFtZRgBIAEoCVIEbmFtZRIfCgRsb2dzGAIgAygLMgsuTG9nTWVzc2'
    'FnZVIEbG9nc0oFCAMQ6Ac=');

@$core.Deprecated('Use logMessageDescriptor instead')
const LogMessage$json = {
  '1': 'LogMessage',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 9, '10': 'timestamp'},
    {'1': 'pid', '3': 2, '4': 1, '5': 13, '10': 'pid'},
    {'1': 'tid', '3': 3, '4': 1, '5': 13, '10': 'tid'},
    {'1': 'priority', '3': 4, '4': 1, '5': 13, '10': 'priority'},
    {'1': 'tag', '3': 5, '4': 1, '5': 9, '10': 'tag'},
    {'1': 'message', '3': 6, '4': 1, '5': 9, '10': 'message'},
  ],
  '9': [
    {'1': 7, '2': 1000},
  ],
};

/// Descriptor for `LogMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logMessageDescriptor = $convert.base64Decode(
    'CgpMb2dNZXNzYWdlEhwKCXRpbWVzdGFtcBgBIAEoCVIJdGltZXN0YW1wEhAKA3BpZBgCIAEoDV'
    'IDcGlkEhAKA3RpZBgDIAEoDVIDdGlkEhoKCHByaW9yaXR5GAQgASgNUghwcmlvcml0eRIQCgN0'
    'YWcYBSABKAlSA3RhZxIYCgdtZXNzYWdlGAYgASgJUgdtZXNzYWdlSgUIBxDoBw==');
