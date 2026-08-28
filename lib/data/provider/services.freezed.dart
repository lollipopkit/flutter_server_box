// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'services.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServicesState {

 bool get isBusy; List<ServiceUnit> get units; ServiceScopeFilter get scopeFilter; ServiceManagerType? get manager; ServiceListingNotice? get notice; String? get noticeDetail; ServiceFailure? get failure;
/// Create a copy of ServicesState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServicesStateCopyWith<ServicesState> get copyWith => _$ServicesStateCopyWithImpl<ServicesState>(this as ServicesState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServicesState&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&const DeepCollectionEquality().equals(other.units, units)&&(identical(other.scopeFilter, scopeFilter) || other.scopeFilter == scopeFilter)&&(identical(other.manager, manager) || other.manager == manager)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.noticeDetail, noticeDetail) || other.noticeDetail == noticeDetail)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,isBusy,const DeepCollectionEquality().hash(units),scopeFilter,manager,notice,noticeDetail,failure);

@override
String toString() {
  return 'ServicesState(isBusy: $isBusy, units: $units, scopeFilter: $scopeFilter, manager: $manager, notice: $notice, noticeDetail: $noticeDetail, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $ServicesStateCopyWith<$Res>  {
  factory $ServicesStateCopyWith(ServicesState value, $Res Function(ServicesState) _then) = _$ServicesStateCopyWithImpl;
@useResult
$Res call({
 bool isBusy, List<ServiceUnit> units, ServiceScopeFilter scopeFilter, ServiceManagerType? manager, ServiceListingNotice? notice, String? noticeDetail, ServiceFailure? failure
});




}
/// @nodoc
class _$ServicesStateCopyWithImpl<$Res>
    implements $ServicesStateCopyWith<$Res> {
  _$ServicesStateCopyWithImpl(this._self, this._then);

  final ServicesState _self;
  final $Res Function(ServicesState) _then;

/// Create a copy of ServicesState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isBusy = null,Object? units = null,Object? scopeFilter = null,Object? manager = freezed,Object? notice = freezed,Object? noticeDetail = freezed,Object? failure = freezed,}) {
  return _then(_self.copyWith(
isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,units: null == units ? _self.units : units // ignore: cast_nullable_to_non_nullable
as List<ServiceUnit>,scopeFilter: null == scopeFilter ? _self.scopeFilter : scopeFilter // ignore: cast_nullable_to_non_nullable
as ServiceScopeFilter,manager: freezed == manager ? _self.manager : manager // ignore: cast_nullable_to_non_nullable
as ServiceManagerType?,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as ServiceListingNotice?,noticeDetail: freezed == noticeDetail ? _self.noticeDetail : noticeDetail // ignore: cast_nullable_to_non_nullable
as String?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ServiceFailure?,
  ));
}

}


/// Adds pattern-matching-related methods to [ServicesState].
extension ServicesStatePatterns on ServicesState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServicesState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServicesState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServicesState value)  $default,){
final _that = this;
switch (_that) {
case _ServicesState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServicesState value)?  $default,){
final _that = this;
switch (_that) {
case _ServicesState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isBusy,  List<ServiceUnit> units,  ServiceScopeFilter scopeFilter,  ServiceManagerType? manager,  ServiceListingNotice? notice,  String? noticeDetail,  ServiceFailure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServicesState() when $default != null:
return $default(_that.isBusy,_that.units,_that.scopeFilter,_that.manager,_that.notice,_that.noticeDetail,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isBusy,  List<ServiceUnit> units,  ServiceScopeFilter scopeFilter,  ServiceManagerType? manager,  ServiceListingNotice? notice,  String? noticeDetail,  ServiceFailure? failure)  $default,) {final _that = this;
switch (_that) {
case _ServicesState():
return $default(_that.isBusy,_that.units,_that.scopeFilter,_that.manager,_that.notice,_that.noticeDetail,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isBusy,  List<ServiceUnit> units,  ServiceScopeFilter scopeFilter,  ServiceManagerType? manager,  ServiceListingNotice? notice,  String? noticeDetail,  ServiceFailure? failure)?  $default,) {final _that = this;
switch (_that) {
case _ServicesState() when $default != null:
return $default(_that.isBusy,_that.units,_that.scopeFilter,_that.manager,_that.notice,_that.noticeDetail,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _ServicesState implements ServicesState {
  const _ServicesState({this.isBusy = false, final  List<ServiceUnit> units = const <ServiceUnit>[], this.scopeFilter = ServiceScopeFilter.all, this.manager, this.notice, this.noticeDetail, this.failure}): _units = units;


@override@JsonKey() final  bool isBusy;
 final  List<ServiceUnit> _units;
@override@JsonKey() List<ServiceUnit> get units {
  if (_units is EqualUnmodifiableListView) return _units;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_units);
}

@override@JsonKey() final  ServiceScopeFilter scopeFilter;
@override final  ServiceManagerType? manager;
@override final  ServiceListingNotice? notice;
@override final  String? noticeDetail;
@override final  ServiceFailure? failure;

/// Create a copy of ServicesState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServicesStateCopyWith<_ServicesState> get copyWith => __$ServicesStateCopyWithImpl<_ServicesState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServicesState&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&const DeepCollectionEquality().equals(other._units, _units)&&(identical(other.scopeFilter, scopeFilter) || other.scopeFilter == scopeFilter)&&(identical(other.manager, manager) || other.manager == manager)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.noticeDetail, noticeDetail) || other.noticeDetail == noticeDetail)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,isBusy,const DeepCollectionEquality().hash(_units),scopeFilter,manager,notice,noticeDetail,failure);

@override
String toString() {
  return 'ServicesState(isBusy: $isBusy, units: $units, scopeFilter: $scopeFilter, manager: $manager, notice: $notice, noticeDetail: $noticeDetail, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$ServicesStateCopyWith<$Res> implements $ServicesStateCopyWith<$Res> {
  factory _$ServicesStateCopyWith(_ServicesState value, $Res Function(_ServicesState) _then) = __$ServicesStateCopyWithImpl;
@override @useResult
$Res call({
 bool isBusy, List<ServiceUnit> units, ServiceScopeFilter scopeFilter, ServiceManagerType? manager, ServiceListingNotice? notice, String? noticeDetail, ServiceFailure? failure
});




}
/// @nodoc
class __$ServicesStateCopyWithImpl<$Res>
    implements _$ServicesStateCopyWith<$Res> {
  __$ServicesStateCopyWithImpl(this._self, this._then);

  final _ServicesState _self;
  final $Res Function(_ServicesState) _then;

/// Create a copy of ServicesState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isBusy = null,Object? units = null,Object? scopeFilter = null,Object? manager = freezed,Object? notice = freezed,Object? noticeDetail = freezed,Object? failure = freezed,}) {
  return _then(_ServicesState(
isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,units: null == units ? _self._units : units // ignore: cast_nullable_to_non_nullable
as List<ServiceUnit>,scopeFilter: null == scopeFilter ? _self.scopeFilter : scopeFilter // ignore: cast_nullable_to_non_nullable
as ServiceScopeFilter,manager: freezed == manager ? _self.manager : manager // ignore: cast_nullable_to_non_nullable
as ServiceManagerType?,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as ServiceListingNotice?,noticeDetail: freezed == noticeDetail ? _self.noticeDetail : noticeDetail // ignore: cast_nullable_to_non_nullable
as String?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ServiceFailure?,
  ));
}


}

// dart format on
