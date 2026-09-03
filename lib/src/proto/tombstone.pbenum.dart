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

import 'package:protobuf/protobuf.dart' as $pb;

class Architecture extends $pb.ProtobufEnum {
  static const Architecture ARM32 =
      Architecture._(0, _omitEnumNames ? '' : 'ARM32');
  static const Architecture ARM64 =
      Architecture._(1, _omitEnumNames ? '' : 'ARM64');
  static const Architecture X86 =
      Architecture._(2, _omitEnumNames ? '' : 'X86');
  static const Architecture X86_64 =
      Architecture._(3, _omitEnumNames ? '' : 'X86_64');
  static const Architecture RISCV64 =
      Architecture._(4, _omitEnumNames ? '' : 'RISCV64');
  static const Architecture NONE =
      Architecture._(5, _omitEnumNames ? '' : 'NONE');

  static const $core.List<Architecture> values = <Architecture>[
    ARM32,
    ARM64,
    X86,
    X86_64,
    RISCV64,
    NONE,
  ];

  static final $core.List<Architecture?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static Architecture? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Architecture._(super.value, super.name);
}

class MemoryError_Tool extends $pb.ProtobufEnum {
  static const MemoryError_Tool GWP_ASAN =
      MemoryError_Tool._(0, _omitEnumNames ? '' : 'GWP_ASAN');
  static const MemoryError_Tool SCUDO =
      MemoryError_Tool._(1, _omitEnumNames ? '' : 'SCUDO');

  static const $core.List<MemoryError_Tool> values = <MemoryError_Tool>[
    GWP_ASAN,
    SCUDO,
  ];

  static final $core.List<MemoryError_Tool?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static MemoryError_Tool? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MemoryError_Tool._(super.value, super.name);
}

class MemoryError_Type extends $pb.ProtobufEnum {
  static const MemoryError_Type UNKNOWN =
      MemoryError_Type._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const MemoryError_Type USE_AFTER_FREE =
      MemoryError_Type._(1, _omitEnumNames ? '' : 'USE_AFTER_FREE');
  static const MemoryError_Type DOUBLE_FREE =
      MemoryError_Type._(2, _omitEnumNames ? '' : 'DOUBLE_FREE');
  static const MemoryError_Type INVALID_FREE =
      MemoryError_Type._(3, _omitEnumNames ? '' : 'INVALID_FREE');
  static const MemoryError_Type BUFFER_OVERFLOW =
      MemoryError_Type._(4, _omitEnumNames ? '' : 'BUFFER_OVERFLOW');
  static const MemoryError_Type BUFFER_UNDERFLOW =
      MemoryError_Type._(5, _omitEnumNames ? '' : 'BUFFER_UNDERFLOW');

  static const $core.List<MemoryError_Type> values = <MemoryError_Type>[
    UNKNOWN,
    USE_AFTER_FREE,
    DOUBLE_FREE,
    INVALID_FREE,
    BUFFER_OVERFLOW,
    BUFFER_UNDERFLOW,
  ];

  static final $core.List<MemoryError_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static MemoryError_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MemoryError_Type._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
