// This is a generated file - do not edit.
//
// Generated from tombstone.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'tombstone.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'tombstone.pbenum.dart';

class CrashDetail extends $pb.GeneratedMessage {
  factory CrashDetail({
    $core.List<$core.int>? name,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (data != null) result.data = data;
    return result;
  }

  CrashDetail._();

  factory CrashDetail.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CrashDetail.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CrashDetail',
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'name', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CrashDetail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CrashDetail copyWith(void Function(CrashDetail) updates) =>
      super.copyWith((message) => updates(message as CrashDetail))
          as CrashDetail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CrashDetail create() => CrashDetail._();
  @$core.override
  CrashDetail createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CrashDetail getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CrashDetail>(create);
  static CrashDetail? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get name => $_getN(0);
  @$pb.TagNumber(1)
  set name($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

class StackHistoryBufferEntry extends $pb.GeneratedMessage {
  factory StackHistoryBufferEntry({
    BacktraceFrame? addr,
    $fixnum.Int64? fp,
    $fixnum.Int64? tag,
  }) {
    final result = create();
    if (addr != null) result.addr = addr;
    if (fp != null) result.fp = fp;
    if (tag != null) result.tag = tag;
    return result;
  }

  StackHistoryBufferEntry._();

  factory StackHistoryBufferEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StackHistoryBufferEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StackHistoryBufferEntry',
      createEmptyInstance: create)
    ..aOM<BacktraceFrame>(1, _omitFieldNames ? '' : 'addr',
        subBuilder: BacktraceFrame.create)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'fp', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'tag', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StackHistoryBufferEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StackHistoryBufferEntry copyWith(
          void Function(StackHistoryBufferEntry) updates) =>
      super.copyWith((message) => updates(message as StackHistoryBufferEntry))
          as StackHistoryBufferEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StackHistoryBufferEntry create() => StackHistoryBufferEntry._();
  @$core.override
  StackHistoryBufferEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StackHistoryBufferEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StackHistoryBufferEntry>(create);
  static StackHistoryBufferEntry? _defaultInstance;

  @$pb.TagNumber(1)
  BacktraceFrame get addr => $_getN(0);
  @$pb.TagNumber(1)
  set addr(BacktraceFrame value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAddr() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddr() => $_clearField(1);
  @$pb.TagNumber(1)
  BacktraceFrame ensureAddr() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get fp => $_getI64(1);
  @$pb.TagNumber(2)
  set fp($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFp() => $_has(1);
  @$pb.TagNumber(2)
  void clearFp() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get tag => $_getI64(2);
  @$pb.TagNumber(3)
  set tag($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTag() => $_has(2);
  @$pb.TagNumber(3)
  void clearTag() => $_clearField(3);
}

class StackHistoryBuffer extends $pb.GeneratedMessage {
  factory StackHistoryBuffer({
    $fixnum.Int64? tid,
    $core.Iterable<StackHistoryBufferEntry>? entries,
  }) {
    final result = create();
    if (tid != null) result.tid = tid;
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  StackHistoryBuffer._();

  factory StackHistoryBuffer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StackHistoryBuffer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StackHistoryBuffer',
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'tid', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<StackHistoryBufferEntry>(2, _omitFieldNames ? '' : 'entries',
        subBuilder: StackHistoryBufferEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StackHistoryBuffer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StackHistoryBuffer copyWith(void Function(StackHistoryBuffer) updates) =>
      super.copyWith((message) => updates(message as StackHistoryBuffer))
          as StackHistoryBuffer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StackHistoryBuffer create() => StackHistoryBuffer._();
  @$core.override
  StackHistoryBuffer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StackHistoryBuffer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StackHistoryBuffer>(create);
  static StackHistoryBuffer? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get tid => $_getI64(0);
  @$pb.TagNumber(1)
  set tid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTid() => $_has(0);
  @$pb.TagNumber(1)
  void clearTid() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<StackHistoryBufferEntry> get entries => $_getList(1);
}

class Tombstone extends $pb.GeneratedMessage {
  factory Tombstone({
    Architecture? arch,
    $core.String? buildFingerprint,
    $core.String? revision,
    $core.String? timestamp,
    $core.int? pid,
    $core.int? tid,
    $core.int? uid,
    $core.String? selinuxLabel,
    $core.Iterable<$core.String>? commandLine,
    Signal? signalInfo,
    $core.String? abortMessage,
    $core.Iterable<Cause>? causes,
    $core.Iterable<$core.MapEntry<$core.int, Thread>>? threads,
    $core.Iterable<MemoryMapping>? memoryMappings,
    $core.Iterable<LogBuffer>? logBuffers,
    $core.Iterable<FD>? openFds,
    $core.int? processUptime,
    $core.Iterable<CrashDetail>? crashDetails,
    $core.int? pageSize,
    $core.bool? hasBeen16kbMode,
    Architecture? guestArch,
    $core.Iterable<$core.MapEntry<$core.int, Thread>>? guestThreads,
    StackHistoryBuffer? stackHistoryBuffer,
  }) {
    final result = create();
    if (arch != null) result.arch = arch;
    if (buildFingerprint != null) result.buildFingerprint = buildFingerprint;
    if (revision != null) result.revision = revision;
    if (timestamp != null) result.timestamp = timestamp;
    if (pid != null) result.pid = pid;
    if (tid != null) result.tid = tid;
    if (uid != null) result.uid = uid;
    if (selinuxLabel != null) result.selinuxLabel = selinuxLabel;
    if (commandLine != null) result.commandLine.addAll(commandLine);
    if (signalInfo != null) result.signalInfo = signalInfo;
    if (abortMessage != null) result.abortMessage = abortMessage;
    if (causes != null) result.causes.addAll(causes);
    if (threads != null) result.threads.addEntries(threads);
    if (memoryMappings != null) result.memoryMappings.addAll(memoryMappings);
    if (logBuffers != null) result.logBuffers.addAll(logBuffers);
    if (openFds != null) result.openFds.addAll(openFds);
    if (processUptime != null) result.processUptime = processUptime;
    if (crashDetails != null) result.crashDetails.addAll(crashDetails);
    if (pageSize != null) result.pageSize = pageSize;
    if (hasBeen16kbMode != null) result.hasBeen16kbMode = hasBeen16kbMode;
    if (guestArch != null) result.guestArch = guestArch;
    if (guestThreads != null) result.guestThreads.addEntries(guestThreads);
    if (stackHistoryBuffer != null)
      result.stackHistoryBuffer = stackHistoryBuffer;
    return result;
  }

  Tombstone._();

  factory Tombstone.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Tombstone.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Tombstone',
      createEmptyInstance: create)
    ..aE<Architecture>(1, _omitFieldNames ? '' : 'arch',
        enumValues: Architecture.values)
    ..aOS(2, _omitFieldNames ? '' : 'buildFingerprint')
    ..aOS(3, _omitFieldNames ? '' : 'revision')
    ..aOS(4, _omitFieldNames ? '' : 'timestamp')
    ..aI(5, _omitFieldNames ? '' : 'pid', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'tid', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'uid', fieldType: $pb.PbFieldType.OU3)
    ..aOS(8, _omitFieldNames ? '' : 'selinuxLabel')
    ..pPS(9, _omitFieldNames ? '' : 'commandLine')
    ..aOM<Signal>(10, _omitFieldNames ? '' : 'signalInfo',
        subBuilder: Signal.create)
    ..aOS(14, _omitFieldNames ? '' : 'abortMessage')
    ..pPM<Cause>(15, _omitFieldNames ? '' : 'causes', subBuilder: Cause.create)
    ..m<$core.int, Thread>(16, _omitFieldNames ? '' : 'threads',
        entryClassName: 'Tombstone.ThreadsEntry',
        keyFieldType: $pb.PbFieldType.OU3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Thread.create,
        valueDefaultOrMaker: Thread.getDefault)
    ..pPM<MemoryMapping>(17, _omitFieldNames ? '' : 'memoryMappings',
        subBuilder: MemoryMapping.create)
    ..pPM<LogBuffer>(18, _omitFieldNames ? '' : 'logBuffers',
        subBuilder: LogBuffer.create)
    ..pPM<FD>(19, _omitFieldNames ? '' : 'openFds', subBuilder: FD.create)
    ..aI(20, _omitFieldNames ? '' : 'processUptime',
        fieldType: $pb.PbFieldType.OU3)
    ..pPM<CrashDetail>(21, _omitFieldNames ? '' : 'crashDetails',
        subBuilder: CrashDetail.create)
    ..aI(22, _omitFieldNames ? '' : 'pageSize', fieldType: $pb.PbFieldType.OU3)
    ..aOB(23, _omitFieldNames ? '' : 'hasBeen16kbMode',
        protoName: 'has_been_16kb_mode')
    ..aE<Architecture>(24, _omitFieldNames ? '' : 'guestArch',
        enumValues: Architecture.values)
    ..m<$core.int, Thread>(25, _omitFieldNames ? '' : 'guestThreads',
        entryClassName: 'Tombstone.GuestThreadsEntry',
        keyFieldType: $pb.PbFieldType.OU3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Thread.create,
        valueDefaultOrMaker: Thread.getDefault)
    ..aOM<StackHistoryBuffer>(26, _omitFieldNames ? '' : 'stackHistoryBuffer',
        subBuilder: StackHistoryBuffer.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tombstone clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tombstone copyWith(void Function(Tombstone) updates) =>
      super.copyWith((message) => updates(message as Tombstone)) as Tombstone;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Tombstone create() => Tombstone._();
  @$core.override
  Tombstone createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Tombstone getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Tombstone>(create);
  static Tombstone? _defaultInstance;

  @$pb.TagNumber(1)
  Architecture get arch => $_getN(0);
  @$pb.TagNumber(1)
  set arch(Architecture value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasArch() => $_has(0);
  @$pb.TagNumber(1)
  void clearArch() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get buildFingerprint => $_getSZ(1);
  @$pb.TagNumber(2)
  set buildFingerprint($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBuildFingerprint() => $_has(1);
  @$pb.TagNumber(2)
  void clearBuildFingerprint() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get revision => $_getSZ(2);
  @$pb.TagNumber(3)
  set revision($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRevision() => $_has(2);
  @$pb.TagNumber(3)
  void clearRevision() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get timestamp => $_getSZ(3);
  @$pb.TagNumber(4)
  set timestamp($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTimestamp() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestamp() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get pid => $_getIZ(4);
  @$pb.TagNumber(5)
  set pid($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPid() => $_has(4);
  @$pb.TagNumber(5)
  void clearPid() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get tid => $_getIZ(5);
  @$pb.TagNumber(6)
  set tid($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTid() => $_has(5);
  @$pb.TagNumber(6)
  void clearTid() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get uid => $_getIZ(6);
  @$pb.TagNumber(7)
  set uid($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUid() => $_has(6);
  @$pb.TagNumber(7)
  void clearUid() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get selinuxLabel => $_getSZ(7);
  @$pb.TagNumber(8)
  set selinuxLabel($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSelinuxLabel() => $_has(7);
  @$pb.TagNumber(8)
  void clearSelinuxLabel() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get commandLine => $_getList(8);

  @$pb.TagNumber(10)
  Signal get signalInfo => $_getN(9);
  @$pb.TagNumber(10)
  set signalInfo(Signal value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasSignalInfo() => $_has(9);
  @$pb.TagNumber(10)
  void clearSignalInfo() => $_clearField(10);
  @$pb.TagNumber(10)
  Signal ensureSignalInfo() => $_ensure(9);

  @$pb.TagNumber(14)
  $core.String get abortMessage => $_getSZ(10);
  @$pb.TagNumber(14)
  set abortMessage($core.String value) => $_setString(10, value);
  @$pb.TagNumber(14)
  $core.bool hasAbortMessage() => $_has(10);
  @$pb.TagNumber(14)
  void clearAbortMessage() => $_clearField(14);

  @$pb.TagNumber(15)
  $pb.PbList<Cause> get causes => $_getList(11);

  @$pb.TagNumber(16)
  $pb.PbMap<$core.int, Thread> get threads => $_getMap(12);

  @$pb.TagNumber(17)
  $pb.PbList<MemoryMapping> get memoryMappings => $_getList(13);

  @$pb.TagNumber(18)
  $pb.PbList<LogBuffer> get logBuffers => $_getList(14);

  @$pb.TagNumber(19)
  $pb.PbList<FD> get openFds => $_getList(15);

  /// Process uptime in seconds.
  @$pb.TagNumber(20)
  $core.int get processUptime => $_getIZ(16);
  @$pb.TagNumber(20)
  set processUptime($core.int value) => $_setUnsignedInt32(16, value);
  @$pb.TagNumber(20)
  $core.bool hasProcessUptime() => $_has(16);
  @$pb.TagNumber(20)
  void clearProcessUptime() => $_clearField(20);

  @$pb.TagNumber(21)
  $pb.PbList<CrashDetail> get crashDetails => $_getList(17);

  @$pb.TagNumber(22)
  $core.int get pageSize => $_getIZ(18);
  @$pb.TagNumber(22)
  set pageSize($core.int value) => $_setUnsignedInt32(18, value);
  @$pb.TagNumber(22)
  $core.bool hasPageSize() => $_has(18);
  @$pb.TagNumber(22)
  void clearPageSize() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.bool get hasBeen16kbMode => $_getBF(19);
  @$pb.TagNumber(23)
  set hasBeen16kbMode($core.bool value) => $_setBool(19, value);
  @$pb.TagNumber(23)
  $core.bool hasHasBeen16kbMode() => $_has(19);
  @$pb.TagNumber(23)
  void clearHasBeen16kbMode() => $_clearField(23);

  @$pb.TagNumber(24)
  Architecture get guestArch => $_getN(20);
  @$pb.TagNumber(24)
  set guestArch(Architecture value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasGuestArch() => $_has(20);
  @$pb.TagNumber(24)
  void clearGuestArch() => $_clearField(24);

  @$pb.TagNumber(25)
  $pb.PbMap<$core.int, Thread> get guestThreads => $_getMap(21);

  @$pb.TagNumber(26)
  StackHistoryBuffer get stackHistoryBuffer => $_getN(22);
  @$pb.TagNumber(26)
  set stackHistoryBuffer(StackHistoryBuffer value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasStackHistoryBuffer() => $_has(22);
  @$pb.TagNumber(26)
  void clearStackHistoryBuffer() => $_clearField(26);
  @$pb.TagNumber(26)
  StackHistoryBuffer ensureStackHistoryBuffer() => $_ensure(22);
}

class Signal extends $pb.GeneratedMessage {
  factory Signal({
    $core.int? number,
    $core.String? name,
    $core.int? code,
    $core.String? codeName,
    $core.bool? hasSender,
    $core.int? senderUid,
    $core.int? senderPid,
    $core.bool? hasFaultAddress,
    $fixnum.Int64? faultAddress_9,
    MemoryDump? faultAdjacentMetadata,
  }) {
    final result = create();
    if (number != null) result.number = number;
    if (name != null) result.name = name;
    if (code != null) result.code = code;
    if (codeName != null) result.codeName = codeName;
    if (hasSender != null) result.hasSender = hasSender;
    if (senderUid != null) result.senderUid = senderUid;
    if (senderPid != null) result.senderPid = senderPid;
    if (hasFaultAddress != null) result.hasFaultAddress = hasFaultAddress;
    if (faultAddress_9 != null) result.faultAddress_9 = faultAddress_9;
    if (faultAdjacentMetadata != null)
      result.faultAdjacentMetadata = faultAdjacentMetadata;
    return result;
  }

  Signal._();

  factory Signal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Signal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Signal',
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'number')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'code')
    ..aOS(4, _omitFieldNames ? '' : 'codeName')
    ..aOB(5, _omitFieldNames ? '' : 'hasSender')
    ..aI(6, _omitFieldNames ? '' : 'senderUid')
    ..aI(7, _omitFieldNames ? '' : 'senderPid')
    ..aOB(8, _omitFieldNames ? '' : 'hasFaultAddress')
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'faultAddress', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<MemoryDump>(10, _omitFieldNames ? '' : 'faultAdjacentMetadata',
        subBuilder: MemoryDump.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Signal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Signal copyWith(void Function(Signal) updates) =>
      super.copyWith((message) => updates(message as Signal)) as Signal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Signal create() => Signal._();
  @$core.override
  Signal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Signal getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Signal>(create);
  static Signal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get number => $_getIZ(0);
  @$pb.TagNumber(1)
  set number($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearNumber() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get code => $_getIZ(2);
  @$pb.TagNumber(3)
  set code($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get codeName => $_getSZ(3);
  @$pb.TagNumber(4)
  set codeName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCodeName() => $_has(3);
  @$pb.TagNumber(4)
  void clearCodeName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get hasSender => $_getBF(4);
  @$pb.TagNumber(5)
  set hasSender($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHasSender() => $_has(4);
  @$pb.TagNumber(5)
  void clearHasSender() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get senderUid => $_getIZ(5);
  @$pb.TagNumber(6)
  set senderUid($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSenderUid() => $_has(5);
  @$pb.TagNumber(6)
  void clearSenderUid() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get senderPid => $_getIZ(6);
  @$pb.TagNumber(7)
  set senderPid($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSenderPid() => $_has(6);
  @$pb.TagNumber(7)
  void clearSenderPid() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hasFaultAddress => $_getBF(7);
  @$pb.TagNumber(8)
  set hasFaultAddress($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHasFaultAddress() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasFaultAddress() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get faultAddress_9 => $_getI64(8);
  @$pb.TagNumber(9)
  set faultAddress_9($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFaultAddress_9() => $_has(8);
  @$pb.TagNumber(9)
  void clearFaultAddress_9() => $_clearField(9);

  /// Note, may or may not contain the dump of the actual memory contents. Currently, on arm64, we
  /// only include metadata, and not the contents.
  @$pb.TagNumber(10)
  MemoryDump get faultAdjacentMetadata => $_getN(9);
  @$pb.TagNumber(10)
  set faultAdjacentMetadata(MemoryDump value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasFaultAdjacentMetadata() => $_has(9);
  @$pb.TagNumber(10)
  void clearFaultAdjacentMetadata() => $_clearField(10);
  @$pb.TagNumber(10)
  MemoryDump ensureFaultAdjacentMetadata() => $_ensure(9);
}

class HeapObject extends $pb.GeneratedMessage {
  factory HeapObject({
    $fixnum.Int64? address,
    $fixnum.Int64? size,
    $fixnum.Int64? allocationTid,
    $core.Iterable<BacktraceFrame>? allocationBacktrace,
    $fixnum.Int64? deallocationTid,
    $core.Iterable<BacktraceFrame>? deallocationBacktrace,
  }) {
    final result = create();
    if (address != null) result.address = address;
    if (size != null) result.size = size;
    if (allocationTid != null) result.allocationTid = allocationTid;
    if (allocationBacktrace != null)
      result.allocationBacktrace.addAll(allocationBacktrace);
    if (deallocationTid != null) result.deallocationTid = deallocationTid;
    if (deallocationBacktrace != null)
      result.deallocationBacktrace.addAll(deallocationBacktrace);
    return result;
  }

  HeapObject._();

  factory HeapObject.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HeapObject.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HeapObject',
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'address', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'allocationTid', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<BacktraceFrame>(4, _omitFieldNames ? '' : 'allocationBacktrace',
        subBuilder: BacktraceFrame.create)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'deallocationTid', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<BacktraceFrame>(6, _omitFieldNames ? '' : 'deallocationBacktrace',
        subBuilder: BacktraceFrame.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeapObject clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeapObject copyWith(void Function(HeapObject) updates) =>
      super.copyWith((message) => updates(message as HeapObject)) as HeapObject;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeapObject create() => HeapObject._();
  @$core.override
  HeapObject createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeapObject getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HeapObject>(create);
  static HeapObject? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get address => $_getI64(0);
  @$pb.TagNumber(1)
  set address($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get size => $_getI64(1);
  @$pb.TagNumber(2)
  set size($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get allocationTid => $_getI64(2);
  @$pb.TagNumber(3)
  set allocationTid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAllocationTid() => $_has(2);
  @$pb.TagNumber(3)
  void clearAllocationTid() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<BacktraceFrame> get allocationBacktrace => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get deallocationTid => $_getI64(4);
  @$pb.TagNumber(5)
  set deallocationTid($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDeallocationTid() => $_has(4);
  @$pb.TagNumber(5)
  void clearDeallocationTid() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<BacktraceFrame> get deallocationBacktrace => $_getList(5);
}

enum MemoryError_Location { heap, notSet }

class MemoryError extends $pb.GeneratedMessage {
  factory MemoryError({
    MemoryError_Tool? tool,
    MemoryError_Type? type,
    HeapObject? heap,
  }) {
    final result = create();
    if (tool != null) result.tool = tool;
    if (type != null) result.type = type;
    if (heap != null) result.heap = heap;
    return result;
  }

  MemoryError._();

  factory MemoryError.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MemoryError.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, MemoryError_Location>
      _MemoryError_LocationByTag = {
    3: MemoryError_Location.heap,
    0: MemoryError_Location.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MemoryError',
      createEmptyInstance: create)
    ..oo(0, [3])
    ..aE<MemoryError_Tool>(1, _omitFieldNames ? '' : 'tool',
        enumValues: MemoryError_Tool.values)
    ..aE<MemoryError_Type>(2, _omitFieldNames ? '' : 'type',
        enumValues: MemoryError_Type.values)
    ..aOM<HeapObject>(3, _omitFieldNames ? '' : 'heap',
        subBuilder: HeapObject.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemoryError clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemoryError copyWith(void Function(MemoryError) updates) =>
      super.copyWith((message) => updates(message as MemoryError))
          as MemoryError;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemoryError create() => MemoryError._();
  @$core.override
  MemoryError createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemoryError getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MemoryError>(create);
  static MemoryError? _defaultInstance;

  @$pb.TagNumber(3)
  MemoryError_Location whichLocation() =>
      _MemoryError_LocationByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  void clearLocation() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  MemoryError_Tool get tool => $_getN(0);
  @$pb.TagNumber(1)
  set tool(MemoryError_Tool value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTool() => $_has(0);
  @$pb.TagNumber(1)
  void clearTool() => $_clearField(1);

  @$pb.TagNumber(2)
  MemoryError_Type get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(MemoryError_Type value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  HeapObject get heap => $_getN(2);
  @$pb.TagNumber(3)
  set heap(HeapObject value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasHeap() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeap() => $_clearField(3);
  @$pb.TagNumber(3)
  HeapObject ensureHeap() => $_ensure(2);
}

enum Cause_Details { memoryError, notSet }

class Cause extends $pb.GeneratedMessage {
  factory Cause({
    $core.String? humanReadable,
    MemoryError? memoryError,
  }) {
    final result = create();
    if (humanReadable != null) result.humanReadable = humanReadable;
    if (memoryError != null) result.memoryError = memoryError;
    return result;
  }

  Cause._();

  factory Cause.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Cause.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Cause_Details> _Cause_DetailsByTag = {
    2: Cause_Details.memoryError,
    0: Cause_Details.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Cause',
      createEmptyInstance: create)
    ..oo(0, [2])
    ..aOS(1, _omitFieldNames ? '' : 'humanReadable')
    ..aOM<MemoryError>(2, _omitFieldNames ? '' : 'memoryError',
        subBuilder: MemoryError.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Cause clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Cause copyWith(void Function(Cause) updates) =>
      super.copyWith((message) => updates(message as Cause)) as Cause;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Cause create() => Cause._();
  @$core.override
  Cause createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Cause getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Cause>(create);
  static Cause? _defaultInstance;

  @$pb.TagNumber(2)
  Cause_Details whichDetails() => _Cause_DetailsByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  void clearDetails() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get humanReadable => $_getSZ(0);
  @$pb.TagNumber(1)
  set humanReadable($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHumanReadable() => $_has(0);
  @$pb.TagNumber(1)
  void clearHumanReadable() => $_clearField(1);

  @$pb.TagNumber(2)
  MemoryError get memoryError => $_getN(1);
  @$pb.TagNumber(2)
  set memoryError(MemoryError value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMemoryError() => $_has(1);
  @$pb.TagNumber(2)
  void clearMemoryError() => $_clearField(2);
  @$pb.TagNumber(2)
  MemoryError ensureMemoryError() => $_ensure(1);
}

class Register extends $pb.GeneratedMessage {
  factory Register({
    $core.String? name,
    $fixnum.Int64? u64,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (u64 != null) result.u64 = u64;
    return result;
  }

  Register._();

  factory Register.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Register.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Register',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'u64', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Register clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Register copyWith(void Function(Register) updates) =>
      super.copyWith((message) => updates(message as Register)) as Register;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Register create() => Register._();
  @$core.override
  Register createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Register getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Register>(create);
  static Register? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get u64 => $_getI64(1);
  @$pb.TagNumber(2)
  set u64($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasU64() => $_has(1);
  @$pb.TagNumber(2)
  void clearU64() => $_clearField(2);
}

class Thread extends $pb.GeneratedMessage {
  factory Thread({
    $core.int? id,
    $core.String? name,
    $core.Iterable<Register>? registers,
    $core.Iterable<BacktraceFrame>? currentBacktrace,
    $core.Iterable<MemoryDump>? memoryDump,
    $fixnum.Int64? taggedAddrCtrl,
    $core.Iterable<$core.String>? backtraceNote,
    $fixnum.Int64? pacEnabledKeys,
    $core.Iterable<$core.String>? unreadableElfFiles,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (registers != null) result.registers.addAll(registers);
    if (currentBacktrace != null)
      result.currentBacktrace.addAll(currentBacktrace);
    if (memoryDump != null) result.memoryDump.addAll(memoryDump);
    if (taggedAddrCtrl != null) result.taggedAddrCtrl = taggedAddrCtrl;
    if (backtraceNote != null) result.backtraceNote.addAll(backtraceNote);
    if (pacEnabledKeys != null) result.pacEnabledKeys = pacEnabledKeys;
    if (unreadableElfFiles != null)
      result.unreadableElfFiles.addAll(unreadableElfFiles);
    return result;
  }

  Thread._();

  factory Thread.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Thread.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Thread',
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..pPM<Register>(3, _omitFieldNames ? '' : 'registers',
        subBuilder: Register.create)
    ..pPM<BacktraceFrame>(4, _omitFieldNames ? '' : 'currentBacktrace',
        subBuilder: BacktraceFrame.create)
    ..pPM<MemoryDump>(5, _omitFieldNames ? '' : 'memoryDump',
        subBuilder: MemoryDump.create)
    ..aInt64(6, _omitFieldNames ? '' : 'taggedAddrCtrl')
    ..pPS(7, _omitFieldNames ? '' : 'backtraceNote')
    ..aInt64(8, _omitFieldNames ? '' : 'pacEnabledKeys')
    ..pPS(9, _omitFieldNames ? '' : 'unreadableElfFiles')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Thread clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Thread copyWith(void Function(Thread) updates) =>
      super.copyWith((message) => updates(message as Thread)) as Thread;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Thread create() => Thread._();
  @$core.override
  Thread createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Thread getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Thread>(create);
  static Thread? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<Register> get registers => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<BacktraceFrame> get currentBacktrace => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<MemoryDump> get memoryDump => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get taggedAddrCtrl => $_getI64(5);
  @$pb.TagNumber(6)
  set taggedAddrCtrl($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTaggedAddrCtrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearTaggedAddrCtrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get backtraceNote => $_getList(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get pacEnabledKeys => $_getI64(7);
  @$pb.TagNumber(8)
  set pacEnabledKeys($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPacEnabledKeys() => $_has(7);
  @$pb.TagNumber(8)
  void clearPacEnabledKeys() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get unreadableElfFiles => $_getList(8);
}

class BacktraceFrame extends $pb.GeneratedMessage {
  factory BacktraceFrame({
    $fixnum.Int64? relPc,
    $fixnum.Int64? pc,
    $fixnum.Int64? sp,
    $core.String? functionName,
    $fixnum.Int64? functionOffset,
    $core.String? fileName,
    $fixnum.Int64? fileMapOffset,
    $core.String? buildId,
  }) {
    final result = create();
    if (relPc != null) result.relPc = relPc;
    if (pc != null) result.pc = pc;
    if (sp != null) result.sp = sp;
    if (functionName != null) result.functionName = functionName;
    if (functionOffset != null) result.functionOffset = functionOffset;
    if (fileName != null) result.fileName = fileName;
    if (fileMapOffset != null) result.fileMapOffset = fileMapOffset;
    if (buildId != null) result.buildId = buildId;
    return result;
  }

  BacktraceFrame._();

  factory BacktraceFrame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BacktraceFrame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BacktraceFrame',
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'relPc', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'pc', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'sp', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'functionName')
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'functionOffset', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(6, _omitFieldNames ? '' : 'fileName')
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'fileMapOffset', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(8, _omitFieldNames ? '' : 'buildId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BacktraceFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BacktraceFrame copyWith(void Function(BacktraceFrame) updates) =>
      super.copyWith((message) => updates(message as BacktraceFrame))
          as BacktraceFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BacktraceFrame create() => BacktraceFrame._();
  @$core.override
  BacktraceFrame createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BacktraceFrame getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BacktraceFrame>(create);
  static BacktraceFrame? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get relPc => $_getI64(0);
  @$pb.TagNumber(1)
  set relPc($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelPc() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelPc() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get pc => $_getI64(1);
  @$pb.TagNumber(2)
  set pc($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPc() => $_has(1);
  @$pb.TagNumber(2)
  void clearPc() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sp => $_getI64(2);
  @$pb.TagNumber(3)
  set sp($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSp() => $_has(2);
  @$pb.TagNumber(3)
  void clearSp() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get functionName => $_getSZ(3);
  @$pb.TagNumber(4)
  set functionName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFunctionName() => $_has(3);
  @$pb.TagNumber(4)
  void clearFunctionName() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get functionOffset => $_getI64(4);
  @$pb.TagNumber(5)
  set functionOffset($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFunctionOffset() => $_has(4);
  @$pb.TagNumber(5)
  void clearFunctionOffset() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get fileName => $_getSZ(5);
  @$pb.TagNumber(6)
  set fileName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFileName() => $_has(5);
  @$pb.TagNumber(6)
  void clearFileName() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get fileMapOffset => $_getI64(6);
  @$pb.TagNumber(7)
  set fileMapOffset($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFileMapOffset() => $_has(6);
  @$pb.TagNumber(7)
  void clearFileMapOffset() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get buildId => $_getSZ(7);
  @$pb.TagNumber(8)
  set buildId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBuildId() => $_has(7);
  @$pb.TagNumber(8)
  void clearBuildId() => $_clearField(8);
}

class ArmMTEMetadata extends $pb.GeneratedMessage {
  factory ArmMTEMetadata({
    $core.List<$core.int>? memoryTags,
  }) {
    final result = create();
    if (memoryTags != null) result.memoryTags = memoryTags;
    return result;
  }

  ArmMTEMetadata._();

  factory ArmMTEMetadata.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ArmMTEMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArmMTEMetadata',
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'memoryTags', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArmMTEMetadata clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArmMTEMetadata copyWith(void Function(ArmMTEMetadata) updates) =>
      super.copyWith((message) => updates(message as ArmMTEMetadata))
          as ArmMTEMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ArmMTEMetadata create() => ArmMTEMetadata._();
  @$core.override
  ArmMTEMetadata createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ArmMTEMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArmMTEMetadata>(create);
  static ArmMTEMetadata? _defaultInstance;

  /// One memory tag per granule (e.g. every 16 bytes) of regular memory.
  @$pb.TagNumber(1)
  $core.List<$core.int> get memoryTags => $_getN(0);
  @$pb.TagNumber(1)
  set memoryTags($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMemoryTags() => $_has(0);
  @$pb.TagNumber(1)
  void clearMemoryTags() => $_clearField(1);
}

enum MemoryDump_Metadata { armMteMetadata, notSet }

class MemoryDump extends $pb.GeneratedMessage {
  factory MemoryDump({
    $core.String? registerName,
    $core.String? mappingName,
    $fixnum.Int64? beginAddress,
    $core.List<$core.int>? memory,
    ArmMTEMetadata? armMteMetadata,
  }) {
    final result = create();
    if (registerName != null) result.registerName = registerName;
    if (mappingName != null) result.mappingName = mappingName;
    if (beginAddress != null) result.beginAddress = beginAddress;
    if (memory != null) result.memory = memory;
    if (armMteMetadata != null) result.armMteMetadata = armMteMetadata;
    return result;
  }

  MemoryDump._();

  factory MemoryDump.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MemoryDump.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, MemoryDump_Metadata>
      _MemoryDump_MetadataByTag = {
    6: MemoryDump_Metadata.armMteMetadata,
    0: MemoryDump_Metadata.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MemoryDump',
      createEmptyInstance: create)
    ..oo(0, [6])
    ..aOS(1, _omitFieldNames ? '' : 'registerName')
    ..aOS(2, _omitFieldNames ? '' : 'mappingName')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'beginAddress', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'memory', $pb.PbFieldType.OY)
    ..aOM<ArmMTEMetadata>(6, _omitFieldNames ? '' : 'armMteMetadata',
        subBuilder: ArmMTEMetadata.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemoryDump clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemoryDump copyWith(void Function(MemoryDump) updates) =>
      super.copyWith((message) => updates(message as MemoryDump)) as MemoryDump;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemoryDump create() => MemoryDump._();
  @$core.override
  MemoryDump createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemoryDump getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MemoryDump>(create);
  static MemoryDump? _defaultInstance;

  @$pb.TagNumber(6)
  MemoryDump_Metadata whichMetadata() =>
      _MemoryDump_MetadataByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(6)
  void clearMetadata() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get registerName => $_getSZ(0);
  @$pb.TagNumber(1)
  set registerName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRegisterName() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegisterName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mappingName => $_getSZ(1);
  @$pb.TagNumber(2)
  set mappingName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMappingName() => $_has(1);
  @$pb.TagNumber(2)
  void clearMappingName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get beginAddress => $_getI64(2);
  @$pb.TagNumber(3)
  set beginAddress($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBeginAddress() => $_has(2);
  @$pb.TagNumber(3)
  void clearBeginAddress() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get memory => $_getN(3);
  @$pb.TagNumber(4)
  set memory($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMemory() => $_has(3);
  @$pb.TagNumber(4)
  void clearMemory() => $_clearField(4);

  @$pb.TagNumber(6)
  ArmMTEMetadata get armMteMetadata => $_getN(4);
  @$pb.TagNumber(6)
  set armMteMetadata(ArmMTEMetadata value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasArmMteMetadata() => $_has(4);
  @$pb.TagNumber(6)
  void clearArmMteMetadata() => $_clearField(6);
  @$pb.TagNumber(6)
  ArmMTEMetadata ensureArmMteMetadata() => $_ensure(4);
}

class MemoryMapping extends $pb.GeneratedMessage {
  factory MemoryMapping({
    $fixnum.Int64? beginAddress,
    $fixnum.Int64? endAddress,
    $fixnum.Int64? offset,
    $core.bool? read,
    $core.bool? write,
    $core.bool? execute,
    $core.String? mappingName,
    $core.String? buildId,
    $fixnum.Int64? loadBias,
  }) {
    final result = create();
    if (beginAddress != null) result.beginAddress = beginAddress;
    if (endAddress != null) result.endAddress = endAddress;
    if (offset != null) result.offset = offset;
    if (read != null) result.read = read;
    if (write != null) result.write = write;
    if (execute != null) result.execute = execute;
    if (mappingName != null) result.mappingName = mappingName;
    if (buildId != null) result.buildId = buildId;
    if (loadBias != null) result.loadBias = loadBias;
    return result;
  }

  MemoryMapping._();

  factory MemoryMapping.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MemoryMapping.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MemoryMapping',
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'beginAddress', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'endAddress', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(4, _omitFieldNames ? '' : 'read')
    ..aOB(5, _omitFieldNames ? '' : 'write')
    ..aOB(6, _omitFieldNames ? '' : 'execute')
    ..aOS(7, _omitFieldNames ? '' : 'mappingName')
    ..aOS(8, _omitFieldNames ? '' : 'buildId')
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'loadBias', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemoryMapping clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemoryMapping copyWith(void Function(MemoryMapping) updates) =>
      super.copyWith((message) => updates(message as MemoryMapping))
          as MemoryMapping;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemoryMapping create() => MemoryMapping._();
  @$core.override
  MemoryMapping createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemoryMapping getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MemoryMapping>(create);
  static MemoryMapping? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get beginAddress => $_getI64(0);
  @$pb.TagNumber(1)
  set beginAddress($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBeginAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearBeginAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get endAddress => $_getI64(1);
  @$pb.TagNumber(2)
  set endAddress($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndAddress() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get offset => $_getI64(2);
  @$pb.TagNumber(3)
  set offset($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearOffset() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get read => $_getBF(3);
  @$pb.TagNumber(4)
  set read($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRead() => $_has(3);
  @$pb.TagNumber(4)
  void clearRead() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get write => $_getBF(4);
  @$pb.TagNumber(5)
  set write($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWrite() => $_has(4);
  @$pb.TagNumber(5)
  void clearWrite() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get execute => $_getBF(5);
  @$pb.TagNumber(6)
  set execute($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExecute() => $_has(5);
  @$pb.TagNumber(6)
  void clearExecute() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get mappingName => $_getSZ(6);
  @$pb.TagNumber(7)
  set mappingName($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMappingName() => $_has(6);
  @$pb.TagNumber(7)
  void clearMappingName() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get buildId => $_getSZ(7);
  @$pb.TagNumber(8)
  set buildId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBuildId() => $_has(7);
  @$pb.TagNumber(8)
  void clearBuildId() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get loadBias => $_getI64(8);
  @$pb.TagNumber(9)
  set loadBias($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLoadBias() => $_has(8);
  @$pb.TagNumber(9)
  void clearLoadBias() => $_clearField(9);
}

class FD extends $pb.GeneratedMessage {
  factory FD({
    $core.int? fd,
    $core.String? path,
    $core.String? owner,
    $fixnum.Int64? tag,
  }) {
    final result = create();
    if (fd != null) result.fd = fd;
    if (path != null) result.path = path;
    if (owner != null) result.owner = owner;
    if (tag != null) result.tag = tag;
    return result;
  }

  FD._();

  factory FD.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FD.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FD',
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'fd')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..aOS(3, _omitFieldNames ? '' : 'owner')
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'tag', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FD clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FD copyWith(void Function(FD) updates) =>
      super.copyWith((message) => updates(message as FD)) as FD;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FD create() => FD._();
  @$core.override
  FD createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FD getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FD>(create);
  static FD? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get fd => $_getIZ(0);
  @$pb.TagNumber(1)
  set fd($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFd() => $_has(0);
  @$pb.TagNumber(1)
  void clearFd() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get owner => $_getSZ(2);
  @$pb.TagNumber(3)
  set owner($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOwner() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwner() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get tag => $_getI64(3);
  @$pb.TagNumber(4)
  set tag($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTag() => $_has(3);
  @$pb.TagNumber(4)
  void clearTag() => $_clearField(4);
}

class LogBuffer extends $pb.GeneratedMessage {
  factory LogBuffer({
    $core.String? name,
    $core.Iterable<LogMessage>? logs,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (logs != null) result.logs.addAll(logs);
    return result;
  }

  LogBuffer._();

  factory LogBuffer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogBuffer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogBuffer',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..pPM<LogMessage>(2, _omitFieldNames ? '' : 'logs',
        subBuilder: LogMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogBuffer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogBuffer copyWith(void Function(LogBuffer) updates) =>
      super.copyWith((message) => updates(message as LogBuffer)) as LogBuffer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogBuffer create() => LogBuffer._();
  @$core.override
  LogBuffer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogBuffer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogBuffer>(create);
  static LogBuffer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<LogMessage> get logs => $_getList(1);
}

class LogMessage extends $pb.GeneratedMessage {
  factory LogMessage({
    $core.String? timestamp,
    $core.int? pid,
    $core.int? tid,
    $core.int? priority,
    $core.String? tag,
    $core.String? message,
  }) {
    final result = create();
    if (timestamp != null) result.timestamp = timestamp;
    if (pid != null) result.pid = pid;
    if (tid != null) result.tid = tid;
    if (priority != null) result.priority = priority;
    if (tag != null) result.tag = tag;
    if (message != null) result.message = message;
    return result;
  }

  LogMessage._();

  factory LogMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogMessage',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'timestamp')
    ..aI(2, _omitFieldNames ? '' : 'pid', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'tid', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'priority', fieldType: $pb.PbFieldType.OU3)
    ..aOS(5, _omitFieldNames ? '' : 'tag')
    ..aOS(6, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogMessage copyWith(void Function(LogMessage) updates) =>
      super.copyWith((message) => updates(message as LogMessage)) as LogMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogMessage create() => LogMessage._();
  @$core.override
  LogMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogMessage>(create);
  static LogMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get timestamp => $_getSZ(0);
  @$pb.TagNumber(1)
  set timestamp($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get pid => $_getIZ(1);
  @$pb.TagNumber(2)
  set pid($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPid() => $_has(1);
  @$pb.TagNumber(2)
  void clearPid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get tid => $_getIZ(2);
  @$pb.TagNumber(3)
  set tid($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTid() => $_has(2);
  @$pb.TagNumber(3)
  void clearTid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get priority => $_getIZ(3);
  @$pb.TagNumber(4)
  set priority($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPriority() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriority() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get tag => $_getSZ(4);
  @$pb.TagNumber(5)
  set tag($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTag() => $_has(4);
  @$pb.TagNumber(5)
  void clearTag() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get message => $_getSZ(5);
  @$pb.TagNumber(6)
  set message($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMessage() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessage() => $_clearField(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
