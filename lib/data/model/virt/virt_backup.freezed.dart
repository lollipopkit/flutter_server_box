// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virt_backup.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VirtBackup {

/// PVE's volid: `local:backup/vzdump-qemu-100-2026_09_24-02_00_00.vma.zst`.
 String get id;/// The storage it is on, and the node that lists it.
 String get storage; String get node; int? get vmid; DateTime? get createdAt;/// Bytes.
 int? get size;/// `vma.zst`, `tar.zst`, ... — what PVE calls the archive's format.
 String? get format; String? get notes;/// Kept from pruning and deletion until unprotected.
 bool get protected;/// `ok` or `failed`, where a verification job has run on it.
 String? get verification; VirtGuestKind? get kind;
/// Create a copy of VirtBackup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtBackupCopyWith<VirtBackup> get copyWith => _$VirtBackupCopyWithImpl<VirtBackup>(this as VirtBackup, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtBackup&&(identical(other.id, id) || other.id == id)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.node, node) || other.node == node)&&(identical(other.vmid, vmid) || other.vmid == vmid)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.size, size) || other.size == size)&&(identical(other.format, format) || other.format == format)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.protected, protected) || other.protected == protected)&&(identical(other.verification, verification) || other.verification == verification)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,id,storage,node,vmid,createdAt,size,format,notes,protected,verification,kind);

@override
String toString() {
  return 'VirtBackup(id: $id, storage: $storage, node: $node, vmid: $vmid, createdAt: $createdAt, size: $size, format: $format, notes: $notes, protected: $protected, verification: $verification, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $VirtBackupCopyWith<$Res>  {
  factory $VirtBackupCopyWith(VirtBackup value, $Res Function(VirtBackup) _then) = _$VirtBackupCopyWithImpl;
@useResult
$Res call({
 String id, String storage, String node, int? vmid, DateTime? createdAt, int? size, String? format, String? notes, bool protected, String? verification, VirtGuestKind? kind
});




}
/// @nodoc
class _$VirtBackupCopyWithImpl<$Res>
    implements $VirtBackupCopyWith<$Res> {
  _$VirtBackupCopyWithImpl(this._self, this._then);

  final VirtBackup _self;
  final $Res Function(VirtBackup) _then;

/// Create a copy of VirtBackup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? storage = null,Object? node = null,Object? vmid = freezed,Object? createdAt = freezed,Object? size = freezed,Object? format = freezed,Object? notes = freezed,Object? protected = null,Object? verification = freezed,Object? kind = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,storage: null == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String,node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String,vmid: freezed == vmid ? _self.vmid : vmid // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,protected: null == protected ? _self.protected : protected // ignore: cast_nullable_to_non_nullable
as bool,verification: freezed == verification ? _self.verification : verification // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtGuestKind?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtBackup].
extension VirtBackupPatterns on VirtBackup {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtBackup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtBackup() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtBackup value)  $default,){
final _that = this;
switch (_that) {
case _VirtBackup():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtBackup value)?  $default,){
final _that = this;
switch (_that) {
case _VirtBackup() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String storage,  String node,  int? vmid,  DateTime? createdAt,  int? size,  String? format,  String? notes,  bool protected,  String? verification,  VirtGuestKind? kind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtBackup() when $default != null:
return $default(_that.id,_that.storage,_that.node,_that.vmid,_that.createdAt,_that.size,_that.format,_that.notes,_that.protected,_that.verification,_that.kind);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String storage,  String node,  int? vmid,  DateTime? createdAt,  int? size,  String? format,  String? notes,  bool protected,  String? verification,  VirtGuestKind? kind)  $default,) {final _that = this;
switch (_that) {
case _VirtBackup():
return $default(_that.id,_that.storage,_that.node,_that.vmid,_that.createdAt,_that.size,_that.format,_that.notes,_that.protected,_that.verification,_that.kind);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String storage,  String node,  int? vmid,  DateTime? createdAt,  int? size,  String? format,  String? notes,  bool protected,  String? verification,  VirtGuestKind? kind)?  $default,) {final _that = this;
switch (_that) {
case _VirtBackup() when $default != null:
return $default(_that.id,_that.storage,_that.node,_that.vmid,_that.createdAt,_that.size,_that.format,_that.notes,_that.protected,_that.verification,_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class _VirtBackup extends VirtBackup {
  const _VirtBackup({required this.id, required this.storage, required this.node, this.vmid, this.createdAt, this.size, this.format, this.notes, this.protected = false, this.verification, this.kind}): super._();
  

/// PVE's volid: `local:backup/vzdump-qemu-100-2026_09_24-02_00_00.vma.zst`.
@override final  String id;
/// The storage it is on, and the node that lists it.
@override final  String storage;
@override final  String node;
@override final  int? vmid;
@override final  DateTime? createdAt;
/// Bytes.
@override final  int? size;
/// `vma.zst`, `tar.zst`, ... — what PVE calls the archive's format.
@override final  String? format;
@override final  String? notes;
/// Kept from pruning and deletion until unprotected.
@override@JsonKey() final  bool protected;
/// `ok` or `failed`, where a verification job has run on it.
@override final  String? verification;
@override final  VirtGuestKind? kind;

/// Create a copy of VirtBackup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtBackupCopyWith<_VirtBackup> get copyWith => __$VirtBackupCopyWithImpl<_VirtBackup>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtBackup&&(identical(other.id, id) || other.id == id)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.node, node) || other.node == node)&&(identical(other.vmid, vmid) || other.vmid == vmid)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.size, size) || other.size == size)&&(identical(other.format, format) || other.format == format)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.protected, protected) || other.protected == protected)&&(identical(other.verification, verification) || other.verification == verification)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,id,storage,node,vmid,createdAt,size,format,notes,protected,verification,kind);

@override
String toString() {
  return 'VirtBackup(id: $id, storage: $storage, node: $node, vmid: $vmid, createdAt: $createdAt, size: $size, format: $format, notes: $notes, protected: $protected, verification: $verification, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$VirtBackupCopyWith<$Res> implements $VirtBackupCopyWith<$Res> {
  factory _$VirtBackupCopyWith(_VirtBackup value, $Res Function(_VirtBackup) _then) = __$VirtBackupCopyWithImpl;
@override @useResult
$Res call({
 String id, String storage, String node, int? vmid, DateTime? createdAt, int? size, String? format, String? notes, bool protected, String? verification, VirtGuestKind? kind
});




}
/// @nodoc
class __$VirtBackupCopyWithImpl<$Res>
    implements _$VirtBackupCopyWith<$Res> {
  __$VirtBackupCopyWithImpl(this._self, this._then);

  final _VirtBackup _self;
  final $Res Function(_VirtBackup) _then;

/// Create a copy of VirtBackup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? storage = null,Object? node = null,Object? vmid = freezed,Object? createdAt = freezed,Object? size = freezed,Object? format = freezed,Object? notes = freezed,Object? protected = null,Object? verification = freezed,Object? kind = freezed,}) {
  return _then(_VirtBackup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,storage: null == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String,node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String,vmid: freezed == vmid ? _self.vmid : vmid // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,protected: null == protected ? _self.protected : protected // ignore: cast_nullable_to_non_nullable
as bool,verification: freezed == verification ? _self.verification : verification // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtGuestKind?,
  ));
}


}

/// @nodoc
mixin _$VirtBackupJob {

 String get id;/// PVE's calendar event: `02:00`, `sat 03:00`, `daily`.
 String? get schedule; String? get storage;/// `snapshot`, `suspend` or `stop`.
 String? get mode;/// `zstd`, `lzo`, `gzip`, or none.
 String? get compress;/// How many are kept, as PVE's retention says it: `keep-last=7`, ...
 String? get keep; bool get enabled;/// `all` (every guest on the job's node), the VMIDs it takes, or — with
/// [pool] — the guests of that pool. PVE's `vmid` is a comma list or
/// `all`; the two are exclusive.
 bool get all; List<int> get vmids;/// PVE's `exclude`, the VMIDs `all` leaves out.
 List<int> get exclude;/// A pool (`VirtBackupJob.pool`), whose guests the job takes.
 String? get pool;/// The node it runs on; null: every node.
 String? get node;/// The job's own description (`comment`).
 String? get comment;/// The notes every backup it makes carries (`notes-template`).
 String? get notesTemplate;/// `always` or `failure` (PVE's `mailnotification`, deprecated in PVE 9
/// but still what a job stores and its editor sets).
 String? get mailNotification;/// The retention, as PVE's `prune-backups` property string:
/// `keep-last=7,keep-daily=4`.
 String? get prune;
/// Create a copy of VirtBackupJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtBackupJobCopyWith<VirtBackupJob> get copyWith => _$VirtBackupJobCopyWithImpl<VirtBackupJob>(this as VirtBackupJob, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtBackupJob&&(identical(other.id, id) || other.id == id)&&(identical(other.schedule, schedule) || other.schedule == schedule)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.compress, compress) || other.compress == compress)&&(identical(other.keep, keep) || other.keep == keep)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.all, all) || other.all == all)&&const DeepCollectionEquality().equals(other.vmids, vmids)&&const DeepCollectionEquality().equals(other.exclude, exclude)&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.node, node) || other.node == node)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.notesTemplate, notesTemplate) || other.notesTemplate == notesTemplate)&&(identical(other.mailNotification, mailNotification) || other.mailNotification == mailNotification)&&(identical(other.prune, prune) || other.prune == prune));
}


@override
int get hashCode => Object.hash(runtimeType,id,schedule,storage,mode,compress,keep,enabled,all,const DeepCollectionEquality().hash(vmids),const DeepCollectionEquality().hash(exclude),pool,node,comment,notesTemplate,mailNotification,prune);

@override
String toString() {
  return 'VirtBackupJob(id: $id, schedule: $schedule, storage: $storage, mode: $mode, compress: $compress, keep: $keep, enabled: $enabled, all: $all, vmids: $vmids, exclude: $exclude, pool: $pool, node: $node, comment: $comment, notesTemplate: $notesTemplate, mailNotification: $mailNotification, prune: $prune)';
}


}

/// @nodoc
abstract mixin class $VirtBackupJobCopyWith<$Res>  {
  factory $VirtBackupJobCopyWith(VirtBackupJob value, $Res Function(VirtBackupJob) _then) = _$VirtBackupJobCopyWithImpl;
@useResult
$Res call({
 String id, String? schedule, String? storage, String? mode, String? compress, String? keep, bool enabled, bool all, List<int> vmids, List<int> exclude, String? pool, String? node, String? comment, String? notesTemplate, String? mailNotification, String? prune
});




}
/// @nodoc
class _$VirtBackupJobCopyWithImpl<$Res>
    implements $VirtBackupJobCopyWith<$Res> {
  _$VirtBackupJobCopyWithImpl(this._self, this._then);

  final VirtBackupJob _self;
  final $Res Function(VirtBackupJob) _then;

/// Create a copy of VirtBackupJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? schedule = freezed,Object? storage = freezed,Object? mode = freezed,Object? compress = freezed,Object? keep = freezed,Object? enabled = null,Object? all = null,Object? vmids = null,Object? exclude = null,Object? pool = freezed,Object? node = freezed,Object? comment = freezed,Object? notesTemplate = freezed,Object? mailNotification = freezed,Object? prune = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,schedule: freezed == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as String?,storage: freezed == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,compress: freezed == compress ? _self.compress : compress // ignore: cast_nullable_to_non_nullable
as String?,keep: freezed == keep ? _self.keep : keep // ignore: cast_nullable_to_non_nullable
as String?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as bool,vmids: null == vmids ? _self.vmids : vmids // ignore: cast_nullable_to_non_nullable
as List<int>,exclude: null == exclude ? _self.exclude : exclude // ignore: cast_nullable_to_non_nullable
as List<int>,pool: freezed == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String?,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,notesTemplate: freezed == notesTemplate ? _self.notesTemplate : notesTemplate // ignore: cast_nullable_to_non_nullable
as String?,mailNotification: freezed == mailNotification ? _self.mailNotification : mailNotification // ignore: cast_nullable_to_non_nullable
as String?,prune: freezed == prune ? _self.prune : prune // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtBackupJob].
extension VirtBackupJobPatterns on VirtBackupJob {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtBackupJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtBackupJob() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtBackupJob value)  $default,){
final _that = this;
switch (_that) {
case _VirtBackupJob():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtBackupJob value)?  $default,){
final _that = this;
switch (_that) {
case _VirtBackupJob() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? schedule,  String? storage,  String? mode,  String? compress,  String? keep,  bool enabled,  bool all,  List<int> vmids,  List<int> exclude,  String? pool,  String? node,  String? comment,  String? notesTemplate,  String? mailNotification,  String? prune)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtBackupJob() when $default != null:
return $default(_that.id,_that.schedule,_that.storage,_that.mode,_that.compress,_that.keep,_that.enabled,_that.all,_that.vmids,_that.exclude,_that.pool,_that.node,_that.comment,_that.notesTemplate,_that.mailNotification,_that.prune);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? schedule,  String? storage,  String? mode,  String? compress,  String? keep,  bool enabled,  bool all,  List<int> vmids,  List<int> exclude,  String? pool,  String? node,  String? comment,  String? notesTemplate,  String? mailNotification,  String? prune)  $default,) {final _that = this;
switch (_that) {
case _VirtBackupJob():
return $default(_that.id,_that.schedule,_that.storage,_that.mode,_that.compress,_that.keep,_that.enabled,_that.all,_that.vmids,_that.exclude,_that.pool,_that.node,_that.comment,_that.notesTemplate,_that.mailNotification,_that.prune);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? schedule,  String? storage,  String? mode,  String? compress,  String? keep,  bool enabled,  bool all,  List<int> vmids,  List<int> exclude,  String? pool,  String? node,  String? comment,  String? notesTemplate,  String? mailNotification,  String? prune)?  $default,) {final _that = this;
switch (_that) {
case _VirtBackupJob() when $default != null:
return $default(_that.id,_that.schedule,_that.storage,_that.mode,_that.compress,_that.keep,_that.enabled,_that.all,_that.vmids,_that.exclude,_that.pool,_that.node,_that.comment,_that.notesTemplate,_that.mailNotification,_that.prune);case _:
  return null;

}
}

}

/// @nodoc


class _VirtBackupJob extends VirtBackupJob {
  const _VirtBackupJob({required this.id, this.schedule, this.storage, this.mode, this.compress, this.keep, this.enabled = true, this.all = false, final  List<int> vmids = const <int>[], final  List<int> exclude = const <int>[], this.pool, this.node, this.comment, this.notesTemplate, this.mailNotification, this.prune}): _vmids = vmids,_exclude = exclude,super._();
  

@override final  String id;
/// PVE's calendar event: `02:00`, `sat 03:00`, `daily`.
@override final  String? schedule;
@override final  String? storage;
/// `snapshot`, `suspend` or `stop`.
@override final  String? mode;
/// `zstd`, `lzo`, `gzip`, or none.
@override final  String? compress;
/// How many are kept, as PVE's retention says it: `keep-last=7`, ...
@override final  String? keep;
@override@JsonKey() final  bool enabled;
/// `all` (every guest on the job's node), the VMIDs it takes, or — with
/// [pool] — the guests of that pool. PVE's `vmid` is a comma list or
/// `all`; the two are exclusive.
@override@JsonKey() final  bool all;
 final  List<int> _vmids;
@override@JsonKey() List<int> get vmids {
  if (_vmids is EqualUnmodifiableListView) return _vmids;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vmids);
}

/// PVE's `exclude`, the VMIDs `all` leaves out.
 final  List<int> _exclude;
/// PVE's `exclude`, the VMIDs `all` leaves out.
@override@JsonKey() List<int> get exclude {
  if (_exclude is EqualUnmodifiableListView) return _exclude;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exclude);
}

/// A pool (`VirtBackupJob.pool`), whose guests the job takes.
@override final  String? pool;
/// The node it runs on; null: every node.
@override final  String? node;
/// The job's own description (`comment`).
@override final  String? comment;
/// The notes every backup it makes carries (`notes-template`).
@override final  String? notesTemplate;
/// `always` or `failure` (PVE's `mailnotification`, deprecated in PVE 9
/// but still what a job stores and its editor sets).
@override final  String? mailNotification;
/// The retention, as PVE's `prune-backups` property string:
/// `keep-last=7,keep-daily=4`.
@override final  String? prune;

/// Create a copy of VirtBackupJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtBackupJobCopyWith<_VirtBackupJob> get copyWith => __$VirtBackupJobCopyWithImpl<_VirtBackupJob>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtBackupJob&&(identical(other.id, id) || other.id == id)&&(identical(other.schedule, schedule) || other.schedule == schedule)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.compress, compress) || other.compress == compress)&&(identical(other.keep, keep) || other.keep == keep)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.all, all) || other.all == all)&&const DeepCollectionEquality().equals(other._vmids, _vmids)&&const DeepCollectionEquality().equals(other._exclude, _exclude)&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.node, node) || other.node == node)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.notesTemplate, notesTemplate) || other.notesTemplate == notesTemplate)&&(identical(other.mailNotification, mailNotification) || other.mailNotification == mailNotification)&&(identical(other.prune, prune) || other.prune == prune));
}


@override
int get hashCode => Object.hash(runtimeType,id,schedule,storage,mode,compress,keep,enabled,all,const DeepCollectionEquality().hash(_vmids),const DeepCollectionEquality().hash(_exclude),pool,node,comment,notesTemplate,mailNotification,prune);

@override
String toString() {
  return 'VirtBackupJob(id: $id, schedule: $schedule, storage: $storage, mode: $mode, compress: $compress, keep: $keep, enabled: $enabled, all: $all, vmids: $vmids, exclude: $exclude, pool: $pool, node: $node, comment: $comment, notesTemplate: $notesTemplate, mailNotification: $mailNotification, prune: $prune)';
}


}

/// @nodoc
abstract mixin class _$VirtBackupJobCopyWith<$Res> implements $VirtBackupJobCopyWith<$Res> {
  factory _$VirtBackupJobCopyWith(_VirtBackupJob value, $Res Function(_VirtBackupJob) _then) = __$VirtBackupJobCopyWithImpl;
@override @useResult
$Res call({
 String id, String? schedule, String? storage, String? mode, String? compress, String? keep, bool enabled, bool all, List<int> vmids, List<int> exclude, String? pool, String? node, String? comment, String? notesTemplate, String? mailNotification, String? prune
});




}
/// @nodoc
class __$VirtBackupJobCopyWithImpl<$Res>
    implements _$VirtBackupJobCopyWith<$Res> {
  __$VirtBackupJobCopyWithImpl(this._self, this._then);

  final _VirtBackupJob _self;
  final $Res Function(_VirtBackupJob) _then;

/// Create a copy of VirtBackupJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? schedule = freezed,Object? storage = freezed,Object? mode = freezed,Object? compress = freezed,Object? keep = freezed,Object? enabled = null,Object? all = null,Object? vmids = null,Object? exclude = null,Object? pool = freezed,Object? node = freezed,Object? comment = freezed,Object? notesTemplate = freezed,Object? mailNotification = freezed,Object? prune = freezed,}) {
  return _then(_VirtBackupJob(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,schedule: freezed == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as String?,storage: freezed == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,compress: freezed == compress ? _self.compress : compress // ignore: cast_nullable_to_non_nullable
as String?,keep: freezed == keep ? _self.keep : keep // ignore: cast_nullable_to_non_nullable
as String?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as bool,vmids: null == vmids ? _self._vmids : vmids // ignore: cast_nullable_to_non_nullable
as List<int>,exclude: null == exclude ? _self._exclude : exclude // ignore: cast_nullable_to_non_nullable
as List<int>,pool: freezed == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String?,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,notesTemplate: freezed == notesTemplate ? _self.notesTemplate : notesTemplate // ignore: cast_nullable_to_non_nullable
as String?,mailNotification: freezed == mailNotification ? _self.mailNotification : mailNotification // ignore: cast_nullable_to_non_nullable
as String?,prune: freezed == prune ? _self.prune : prune // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
