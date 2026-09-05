// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'benchmark.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BenchmarkState {

/// The run in flight, picked back up from storage when the page opens.
 BenchmarkRun? get active; List<BenchmarkRun> get history;/// A start or a cancel is in progress. Not true while a run is going —
/// that is [active], and the difference is whether a button should spin.
 bool get isBusy;/// Why this app could not drive the run. Never yabs' own diagnostics.
 String? get error;
/// Create a copy of BenchmarkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BenchmarkStateCopyWith<BenchmarkState> get copyWith => _$BenchmarkStateCopyWithImpl<BenchmarkState>(this as BenchmarkState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BenchmarkState&&(identical(other.active, active) || other.active == active)&&const DeepCollectionEquality().equals(other.history, history)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,active,const DeepCollectionEquality().hash(history),isBusy,error);

@override
String toString() {
  return 'BenchmarkState(active: $active, history: $history, isBusy: $isBusy, error: $error)';
}


}

/// @nodoc
abstract mixin class $BenchmarkStateCopyWith<$Res>  {
  factory $BenchmarkStateCopyWith(BenchmarkState value, $Res Function(BenchmarkState) _then) = _$BenchmarkStateCopyWithImpl;
@useResult
$Res call({
 BenchmarkRun? active, List<BenchmarkRun> history, bool isBusy, String? error
});




}
/// @nodoc
class _$BenchmarkStateCopyWithImpl<$Res>
    implements $BenchmarkStateCopyWith<$Res> {
  _$BenchmarkStateCopyWithImpl(this._self, this._then);

  final BenchmarkState _self;
  final $Res Function(BenchmarkState) _then;

/// Create a copy of BenchmarkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? active = freezed,Object? history = null,Object? isBusy = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
active: freezed == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as BenchmarkRun?,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<BenchmarkRun>,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BenchmarkState].
extension BenchmarkStatePatterns on BenchmarkState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BenchmarkState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BenchmarkState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BenchmarkState value)  $default,){
final _that = this;
switch (_that) {
case _BenchmarkState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BenchmarkState value)?  $default,){
final _that = this;
switch (_that) {
case _BenchmarkState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BenchmarkRun? active,  List<BenchmarkRun> history,  bool isBusy,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BenchmarkState() when $default != null:
return $default(_that.active,_that.history,_that.isBusy,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BenchmarkRun? active,  List<BenchmarkRun> history,  bool isBusy,  String? error)  $default,) {final _that = this;
switch (_that) {
case _BenchmarkState():
return $default(_that.active,_that.history,_that.isBusy,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BenchmarkRun? active,  List<BenchmarkRun> history,  bool isBusy,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _BenchmarkState() when $default != null:
return $default(_that.active,_that.history,_that.isBusy,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _BenchmarkState implements BenchmarkState {
  const _BenchmarkState({this.active, final  List<BenchmarkRun> history = const <BenchmarkRun>[], this.isBusy = false, this.error}): _history = history;
  

/// The run in flight, picked back up from storage when the page opens.
@override final  BenchmarkRun? active;
 final  List<BenchmarkRun> _history;
@override@JsonKey() List<BenchmarkRun> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

/// A start or a cancel is in progress. Not true while a run is going —
/// that is [active], and the difference is whether a button should spin.
@override@JsonKey() final  bool isBusy;
/// Why this app could not drive the run. Never yabs' own diagnostics.
@override final  String? error;

/// Create a copy of BenchmarkState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BenchmarkStateCopyWith<_BenchmarkState> get copyWith => __$BenchmarkStateCopyWithImpl<_BenchmarkState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BenchmarkState&&(identical(other.active, active) || other.active == active)&&const DeepCollectionEquality().equals(other._history, _history)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,active,const DeepCollectionEquality().hash(_history),isBusy,error);

@override
String toString() {
  return 'BenchmarkState(active: $active, history: $history, isBusy: $isBusy, error: $error)';
}


}

/// @nodoc
abstract mixin class _$BenchmarkStateCopyWith<$Res> implements $BenchmarkStateCopyWith<$Res> {
  factory _$BenchmarkStateCopyWith(_BenchmarkState value, $Res Function(_BenchmarkState) _then) = __$BenchmarkStateCopyWithImpl;
@override @useResult
$Res call({
 BenchmarkRun? active, List<BenchmarkRun> history, bool isBusy, String? error
});




}
/// @nodoc
class __$BenchmarkStateCopyWithImpl<$Res>
    implements _$BenchmarkStateCopyWith<$Res> {
  __$BenchmarkStateCopyWithImpl(this._self, this._then);

  final _BenchmarkState _self;
  final $Res Function(_BenchmarkState) _then;

/// Create a copy of BenchmarkState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? active = freezed,Object? history = null,Object? isBusy = null,Object? error = freezed,}) {
  return _then(_BenchmarkState(
active: freezed == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as BenchmarkRun?,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<BenchmarkRun>,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
