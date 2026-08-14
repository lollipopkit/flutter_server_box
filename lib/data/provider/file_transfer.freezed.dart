// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_transfer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FileTransferState {

 List<FileTransferStatus> get transfers; int get revision;
/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileTransferStateCopyWith<FileTransferState> get copyWith => _$FileTransferStateCopyWithImpl<FileTransferState>(this as FileTransferState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTransferState&&const DeepCollectionEquality().equals(other.transfers, transfers)&&(identical(other.revision, revision) || other.revision == revision));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(transfers),revision);

@override
String toString() {
  return 'FileTransferState(transfers: $transfers, revision: $revision)';
}


}

/// @nodoc
abstract mixin class $FileTransferStateCopyWith<$Res>  {
  factory $FileTransferStateCopyWith(FileTransferState value, $Res Function(FileTransferState) _then) = _$FileTransferStateCopyWithImpl;
@useResult
$Res call({
 List<FileTransferStatus> transfers, int revision
});




}
/// @nodoc
class _$FileTransferStateCopyWithImpl<$Res>
    implements $FileTransferStateCopyWith<$Res> {
  _$FileTransferStateCopyWithImpl(this._self, this._then);

  final FileTransferState _self;
  final $Res Function(FileTransferState) _then;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? transfers = null,Object? revision = null,}) {
  return _then(_self.copyWith(
transfers: null == transfers ? _self.transfers : transfers // ignore: cast_nullable_to_non_nullable
as List<FileTransferStatus>,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FileTransferState].
extension FileTransferStatePatterns on FileTransferState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileTransferState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileTransferState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileTransferState value)  $default,){
final _that = this;
switch (_that) {
case _FileTransferState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileTransferState value)?  $default,){
final _that = this;
switch (_that) {
case _FileTransferState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<FileTransferStatus> transfers,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileTransferState() when $default != null:
return $default(_that.transfers,_that.revision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<FileTransferStatus> transfers,  int revision)  $default,) {final _that = this;
switch (_that) {
case _FileTransferState():
return $default(_that.transfers,_that.revision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<FileTransferStatus> transfers,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _FileTransferState() when $default != null:
return $default(_that.transfers,_that.revision);case _:
  return null;

}
}

}

/// @nodoc


class _FileTransferState implements FileTransferState {
  const _FileTransferState({final  List<FileTransferStatus> transfers = const <FileTransferStatus>[], this.revision = 0}): _transfers = transfers;
  

 final  List<FileTransferStatus> _transfers;
@override@JsonKey() List<FileTransferStatus> get transfers {
  if (_transfers is EqualUnmodifiableListView) return _transfers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transfers);
}

@override@JsonKey() final  int revision;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileTransferStateCopyWith<_FileTransferState> get copyWith => __$FileTransferStateCopyWithImpl<_FileTransferState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileTransferState&&const DeepCollectionEquality().equals(other._transfers, _transfers)&&(identical(other.revision, revision) || other.revision == revision));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_transfers),revision);

@override
String toString() {
  return 'FileTransferState(transfers: $transfers, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$FileTransferStateCopyWith<$Res> implements $FileTransferStateCopyWith<$Res> {
  factory _$FileTransferStateCopyWith(_FileTransferState value, $Res Function(_FileTransferState) _then) = __$FileTransferStateCopyWithImpl;
@override @useResult
$Res call({
 List<FileTransferStatus> transfers, int revision
});




}
/// @nodoc
class __$FileTransferStateCopyWithImpl<$Res>
    implements _$FileTransferStateCopyWith<$Res> {
  __$FileTransferStateCopyWithImpl(this._self, this._then);

  final _FileTransferState _self;
  final $Res Function(_FileTransferState) _then;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? transfers = null,Object? revision = null,}) {
  return _then(_FileTransferState(
transfers: null == transfers ? _self._transfers : transfers // ignore: cast_nullable_to_non_nullable
as List<FileTransferStatus>,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
