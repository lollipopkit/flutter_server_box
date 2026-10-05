// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'firewall.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChangeError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChangeError()';
}


}

/// @nodoc
class $ChangeErrorCopyWith<$Res>  {
$ChangeErrorCopyWith(ChangeError _, $Res Function(ChangeError) __);
}


/// Adds pattern-matching-related methods to [ChangeError].
extension ChangeErrorPatterns on ChangeError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ChangeError_Unchanged value)?  unchanged,TResult Function( ChangeError_Draft value)?  draft,TResult Function( ChangeError_Input value)?  input,TResult Function( ChangeError_NoSuchRule value)?  noSuchRule,TResult Function( ChangeError_NoSuchZone value)?  noSuchZone,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ChangeError_Unchanged() when unchanged != null:
return unchanged(_that);case ChangeError_Draft() when draft != null:
return draft(_that);case ChangeError_Input() when input != null:
return input(_that);case ChangeError_NoSuchRule() when noSuchRule != null:
return noSuchRule(_that);case ChangeError_NoSuchZone() when noSuchZone != null:
return noSuchZone(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ChangeError_Unchanged value)  unchanged,required TResult Function( ChangeError_Draft value)  draft,required TResult Function( ChangeError_Input value)  input,required TResult Function( ChangeError_NoSuchRule value)  noSuchRule,required TResult Function( ChangeError_NoSuchZone value)  noSuchZone,}){
final _that = this;
switch (_that) {
case ChangeError_Unchanged():
return unchanged(_that);case ChangeError_Draft():
return draft(_that);case ChangeError_Input():
return input(_that);case ChangeError_NoSuchRule():
return noSuchRule(_that);case ChangeError_NoSuchZone():
return noSuchZone(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ChangeError_Unchanged value)?  unchanged,TResult? Function( ChangeError_Draft value)?  draft,TResult? Function( ChangeError_Input value)?  input,TResult? Function( ChangeError_NoSuchRule value)?  noSuchRule,TResult? Function( ChangeError_NoSuchZone value)?  noSuchZone,}){
final _that = this;
switch (_that) {
case ChangeError_Unchanged() when unchanged != null:
return unchanged(_that);case ChangeError_Draft() when draft != null:
return draft(_that);case ChangeError_Input() when input != null:
return input(_that);case ChangeError_NoSuchRule() when noSuchRule != null:
return noSuchRule(_that);case ChangeError_NoSuchZone() when noSuchZone != null:
return noSuchZone(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  unchanged,TResult Function( UfwDraftIssue field0)?  draft,TResult Function( FirewalldInputIssue field0)?  input,TResult Function()?  noSuchRule,TResult Function()?  noSuchZone,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ChangeError_Unchanged() when unchanged != null:
return unchanged();case ChangeError_Draft() when draft != null:
return draft(_that.field0);case ChangeError_Input() when input != null:
return input(_that.field0);case ChangeError_NoSuchRule() when noSuchRule != null:
return noSuchRule();case ChangeError_NoSuchZone() when noSuchZone != null:
return noSuchZone();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  unchanged,required TResult Function( UfwDraftIssue field0)  draft,required TResult Function( FirewalldInputIssue field0)  input,required TResult Function()  noSuchRule,required TResult Function()  noSuchZone,}) {final _that = this;
switch (_that) {
case ChangeError_Unchanged():
return unchanged();case ChangeError_Draft():
return draft(_that.field0);case ChangeError_Input():
return input(_that.field0);case ChangeError_NoSuchRule():
return noSuchRule();case ChangeError_NoSuchZone():
return noSuchZone();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  unchanged,TResult? Function( UfwDraftIssue field0)?  draft,TResult? Function( FirewalldInputIssue field0)?  input,TResult? Function()?  noSuchRule,TResult? Function()?  noSuchZone,}) {final _that = this;
switch (_that) {
case ChangeError_Unchanged() when unchanged != null:
return unchanged();case ChangeError_Draft() when draft != null:
return draft(_that.field0);case ChangeError_Input() when input != null:
return input(_that.field0);case ChangeError_NoSuchRule() when noSuchRule != null:
return noSuchRule();case ChangeError_NoSuchZone() when noSuchZone != null:
return noSuchZone();case _:
  return null;

}
}

}

/// @nodoc


class ChangeError_Unchanged extends ChangeError {
  const ChangeError_Unchanged(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeError_Unchanged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChangeError.unchanged()';
}


}




/// @nodoc


class ChangeError_Draft extends ChangeError {
  const ChangeError_Draft(this.field0): super._();
  

 final  UfwDraftIssue field0;

/// Create a copy of ChangeError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeError_DraftCopyWith<ChangeError_Draft> get copyWith => _$ChangeError_DraftCopyWithImpl<ChangeError_Draft>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeError_Draft&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ChangeError.draft(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ChangeError_DraftCopyWith<$Res> implements $ChangeErrorCopyWith<$Res> {
  factory $ChangeError_DraftCopyWith(ChangeError_Draft value, $Res Function(ChangeError_Draft) _then) = _$ChangeError_DraftCopyWithImpl;
@useResult
$Res call({
 UfwDraftIssue field0
});




}
/// @nodoc
class _$ChangeError_DraftCopyWithImpl<$Res>
    implements $ChangeError_DraftCopyWith<$Res> {
  _$ChangeError_DraftCopyWithImpl(this._self, this._then);

  final ChangeError_Draft _self;
  final $Res Function(ChangeError_Draft) _then;

/// Create a copy of ChangeError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ChangeError_Draft(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as UfwDraftIssue,
  ));
}


}

/// @nodoc


class ChangeError_Input extends ChangeError {
  const ChangeError_Input(this.field0): super._();
  

 final  FirewalldInputIssue field0;

/// Create a copy of ChangeError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeError_InputCopyWith<ChangeError_Input> get copyWith => _$ChangeError_InputCopyWithImpl<ChangeError_Input>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeError_Input&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ChangeError.input(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ChangeError_InputCopyWith<$Res> implements $ChangeErrorCopyWith<$Res> {
  factory $ChangeError_InputCopyWith(ChangeError_Input value, $Res Function(ChangeError_Input) _then) = _$ChangeError_InputCopyWithImpl;
@useResult
$Res call({
 FirewalldInputIssue field0
});




}
/// @nodoc
class _$ChangeError_InputCopyWithImpl<$Res>
    implements $ChangeError_InputCopyWith<$Res> {
  _$ChangeError_InputCopyWithImpl(this._self, this._then);

  final ChangeError_Input _self;
  final $Res Function(ChangeError_Input) _then;

/// Create a copy of ChangeError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ChangeError_Input(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as FirewalldInputIssue,
  ));
}


}

/// @nodoc


class ChangeError_NoSuchRule extends ChangeError {
  const ChangeError_NoSuchRule(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeError_NoSuchRule);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChangeError.noSuchRule()';
}


}




/// @nodoc


class ChangeError_NoSuchZone extends ChangeError {
  const ChangeError_NoSuchZone(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeError_NoSuchZone);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChangeError.noSuchZone()';
}


}




/// @nodoc
mixin _$FirewalldChange {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FirewalldChange()';
}


}

/// @nodoc
class $FirewalldChangeCopyWith<$Res>  {
$FirewalldChangeCopyWith(FirewalldChange _, $Res Function(FirewalldChange) __);
}


/// Adds pattern-matching-related methods to [FirewalldChange].
extension FirewalldChangePatterns on FirewalldChange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FirewalldChange_Start value)?  start,TResult Function( FirewalldChange_Stop value)?  stop,TResult Function( FirewalldChange_Reload value)?  reload,TResult Function( FirewalldChange_RuntimeToPermanent value)?  runtimeToPermanent,TResult Function( FirewalldChange_PanicOff value)?  panicOff,TResult Function( FirewalldChange_DefaultZone value)?  defaultZone,TResult Function( FirewalldChange_Target value)?  target,TResult Function( FirewalldChange_Masquerade value)?  masquerade,TResult Function( FirewalldChange_Add value)?  add,TResult Function( FirewalldChange_Remove value)?  remove,TResult Function( FirewalldChange_ChangeInterface value)?  changeInterface,TResult Function( FirewalldChange_RemoveInterface value)?  removeInterface,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FirewalldChange_Start() when start != null:
return start(_that);case FirewalldChange_Stop() when stop != null:
return stop(_that);case FirewalldChange_Reload() when reload != null:
return reload(_that);case FirewalldChange_RuntimeToPermanent() when runtimeToPermanent != null:
return runtimeToPermanent(_that);case FirewalldChange_PanicOff() when panicOff != null:
return panicOff(_that);case FirewalldChange_DefaultZone() when defaultZone != null:
return defaultZone(_that);case FirewalldChange_Target() when target != null:
return target(_that);case FirewalldChange_Masquerade() when masquerade != null:
return masquerade(_that);case FirewalldChange_Add() when add != null:
return add(_that);case FirewalldChange_Remove() when remove != null:
return remove(_that);case FirewalldChange_ChangeInterface() when changeInterface != null:
return changeInterface(_that);case FirewalldChange_RemoveInterface() when removeInterface != null:
return removeInterface(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FirewalldChange_Start value)  start,required TResult Function( FirewalldChange_Stop value)  stop,required TResult Function( FirewalldChange_Reload value)  reload,required TResult Function( FirewalldChange_RuntimeToPermanent value)  runtimeToPermanent,required TResult Function( FirewalldChange_PanicOff value)  panicOff,required TResult Function( FirewalldChange_DefaultZone value)  defaultZone,required TResult Function( FirewalldChange_Target value)  target,required TResult Function( FirewalldChange_Masquerade value)  masquerade,required TResult Function( FirewalldChange_Add value)  add,required TResult Function( FirewalldChange_Remove value)  remove,required TResult Function( FirewalldChange_ChangeInterface value)  changeInterface,required TResult Function( FirewalldChange_RemoveInterface value)  removeInterface,}){
final _that = this;
switch (_that) {
case FirewalldChange_Start():
return start(_that);case FirewalldChange_Stop():
return stop(_that);case FirewalldChange_Reload():
return reload(_that);case FirewalldChange_RuntimeToPermanent():
return runtimeToPermanent(_that);case FirewalldChange_PanicOff():
return panicOff(_that);case FirewalldChange_DefaultZone():
return defaultZone(_that);case FirewalldChange_Target():
return target(_that);case FirewalldChange_Masquerade():
return masquerade(_that);case FirewalldChange_Add():
return add(_that);case FirewalldChange_Remove():
return remove(_that);case FirewalldChange_ChangeInterface():
return changeInterface(_that);case FirewalldChange_RemoveInterface():
return removeInterface(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FirewalldChange_Start value)?  start,TResult? Function( FirewalldChange_Stop value)?  stop,TResult? Function( FirewalldChange_Reload value)?  reload,TResult? Function( FirewalldChange_RuntimeToPermanent value)?  runtimeToPermanent,TResult? Function( FirewalldChange_PanicOff value)?  panicOff,TResult? Function( FirewalldChange_DefaultZone value)?  defaultZone,TResult? Function( FirewalldChange_Target value)?  target,TResult? Function( FirewalldChange_Masquerade value)?  masquerade,TResult? Function( FirewalldChange_Add value)?  add,TResult? Function( FirewalldChange_Remove value)?  remove,TResult? Function( FirewalldChange_ChangeInterface value)?  changeInterface,TResult? Function( FirewalldChange_RemoveInterface value)?  removeInterface,}){
final _that = this;
switch (_that) {
case FirewalldChange_Start() when start != null:
return start(_that);case FirewalldChange_Stop() when stop != null:
return stop(_that);case FirewalldChange_Reload() when reload != null:
return reload(_that);case FirewalldChange_RuntimeToPermanent() when runtimeToPermanent != null:
return runtimeToPermanent(_that);case FirewalldChange_PanicOff() when panicOff != null:
return panicOff(_that);case FirewalldChange_DefaultZone() when defaultZone != null:
return defaultZone(_that);case FirewalldChange_Target() when target != null:
return target(_that);case FirewalldChange_Masquerade() when masquerade != null:
return masquerade(_that);case FirewalldChange_Add() when add != null:
return add(_that);case FirewalldChange_Remove() when remove != null:
return remove(_that);case FirewalldChange_ChangeInterface() when changeInterface != null:
return changeInterface(_that);case FirewalldChange_RemoveInterface() when removeInterface != null:
return removeInterface(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  start,TResult Function()?  stop,TResult Function()?  reload,TResult Function()?  runtimeToPermanent,TResult Function()?  panicOff,TResult Function( String zone)?  defaultZone,TResult Function( String zone,  FirewalldTarget target)?  target,TResult Function( String zone,  bool enabled)?  masquerade,TResult Function( String zone,  FirewalldItem item,  String value)?  add,TResult Function( String zone,  FirewalldItem item,  String value)?  remove,TResult Function( String zone,  String iface)?  changeInterface,TResult Function( String zone,  String iface)?  removeInterface,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FirewalldChange_Start() when start != null:
return start();case FirewalldChange_Stop() when stop != null:
return stop();case FirewalldChange_Reload() when reload != null:
return reload();case FirewalldChange_RuntimeToPermanent() when runtimeToPermanent != null:
return runtimeToPermanent();case FirewalldChange_PanicOff() when panicOff != null:
return panicOff();case FirewalldChange_DefaultZone() when defaultZone != null:
return defaultZone(_that.zone);case FirewalldChange_Target() when target != null:
return target(_that.zone,_that.target);case FirewalldChange_Masquerade() when masquerade != null:
return masquerade(_that.zone,_that.enabled);case FirewalldChange_Add() when add != null:
return add(_that.zone,_that.item,_that.value);case FirewalldChange_Remove() when remove != null:
return remove(_that.zone,_that.item,_that.value);case FirewalldChange_ChangeInterface() when changeInterface != null:
return changeInterface(_that.zone,_that.iface);case FirewalldChange_RemoveInterface() when removeInterface != null:
return removeInterface(_that.zone,_that.iface);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  start,required TResult Function()  stop,required TResult Function()  reload,required TResult Function()  runtimeToPermanent,required TResult Function()  panicOff,required TResult Function( String zone)  defaultZone,required TResult Function( String zone,  FirewalldTarget target)  target,required TResult Function( String zone,  bool enabled)  masquerade,required TResult Function( String zone,  FirewalldItem item,  String value)  add,required TResult Function( String zone,  FirewalldItem item,  String value)  remove,required TResult Function( String zone,  String iface)  changeInterface,required TResult Function( String zone,  String iface)  removeInterface,}) {final _that = this;
switch (_that) {
case FirewalldChange_Start():
return start();case FirewalldChange_Stop():
return stop();case FirewalldChange_Reload():
return reload();case FirewalldChange_RuntimeToPermanent():
return runtimeToPermanent();case FirewalldChange_PanicOff():
return panicOff();case FirewalldChange_DefaultZone():
return defaultZone(_that.zone);case FirewalldChange_Target():
return target(_that.zone,_that.target);case FirewalldChange_Masquerade():
return masquerade(_that.zone,_that.enabled);case FirewalldChange_Add():
return add(_that.zone,_that.item,_that.value);case FirewalldChange_Remove():
return remove(_that.zone,_that.item,_that.value);case FirewalldChange_ChangeInterface():
return changeInterface(_that.zone,_that.iface);case FirewalldChange_RemoveInterface():
return removeInterface(_that.zone,_that.iface);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  start,TResult? Function()?  stop,TResult? Function()?  reload,TResult? Function()?  runtimeToPermanent,TResult? Function()?  panicOff,TResult? Function( String zone)?  defaultZone,TResult? Function( String zone,  FirewalldTarget target)?  target,TResult? Function( String zone,  bool enabled)?  masquerade,TResult? Function( String zone,  FirewalldItem item,  String value)?  add,TResult? Function( String zone,  FirewalldItem item,  String value)?  remove,TResult? Function( String zone,  String iface)?  changeInterface,TResult? Function( String zone,  String iface)?  removeInterface,}) {final _that = this;
switch (_that) {
case FirewalldChange_Start() when start != null:
return start();case FirewalldChange_Stop() when stop != null:
return stop();case FirewalldChange_Reload() when reload != null:
return reload();case FirewalldChange_RuntimeToPermanent() when runtimeToPermanent != null:
return runtimeToPermanent();case FirewalldChange_PanicOff() when panicOff != null:
return panicOff();case FirewalldChange_DefaultZone() when defaultZone != null:
return defaultZone(_that.zone);case FirewalldChange_Target() when target != null:
return target(_that.zone,_that.target);case FirewalldChange_Masquerade() when masquerade != null:
return masquerade(_that.zone,_that.enabled);case FirewalldChange_Add() when add != null:
return add(_that.zone,_that.item,_that.value);case FirewalldChange_Remove() when remove != null:
return remove(_that.zone,_that.item,_that.value);case FirewalldChange_ChangeInterface() when changeInterface != null:
return changeInterface(_that.zone,_that.iface);case FirewalldChange_RemoveInterface() when removeInterface != null:
return removeInterface(_that.zone,_that.iface);case _:
  return null;

}
}

}

/// @nodoc


class FirewalldChange_Start extends FirewalldChange {
  const FirewalldChange_Start(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_Start);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FirewalldChange.start()';
}


}




/// @nodoc


class FirewalldChange_Stop extends FirewalldChange {
  const FirewalldChange_Stop(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_Stop);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FirewalldChange.stop()';
}


}




/// @nodoc


class FirewalldChange_Reload extends FirewalldChange {
  const FirewalldChange_Reload(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_Reload);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FirewalldChange.reload()';
}


}




/// @nodoc


class FirewalldChange_RuntimeToPermanent extends FirewalldChange {
  const FirewalldChange_RuntimeToPermanent(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_RuntimeToPermanent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FirewalldChange.runtimeToPermanent()';
}


}




/// @nodoc


class FirewalldChange_PanicOff extends FirewalldChange {
  const FirewalldChange_PanicOff(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_PanicOff);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FirewalldChange.panicOff()';
}


}




/// @nodoc


class FirewalldChange_DefaultZone extends FirewalldChange {
  const FirewalldChange_DefaultZone({required this.zone}): super._();
  

 final  String zone;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirewalldChange_DefaultZoneCopyWith<FirewalldChange_DefaultZone> get copyWith => _$FirewalldChange_DefaultZoneCopyWithImpl<FirewalldChange_DefaultZone>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_DefaultZone&&(identical(other.zone, zone) || other.zone == zone));
}


@override
int get hashCode => Object.hash(runtimeType,zone);

@override
String toString() {
  return 'FirewalldChange.defaultZone(zone: $zone)';
}


}

/// @nodoc
abstract mixin class $FirewalldChange_DefaultZoneCopyWith<$Res> implements $FirewalldChangeCopyWith<$Res> {
  factory $FirewalldChange_DefaultZoneCopyWith(FirewalldChange_DefaultZone value, $Res Function(FirewalldChange_DefaultZone) _then) = _$FirewalldChange_DefaultZoneCopyWithImpl;
@useResult
$Res call({
 String zone
});




}
/// @nodoc
class _$FirewalldChange_DefaultZoneCopyWithImpl<$Res>
    implements $FirewalldChange_DefaultZoneCopyWith<$Res> {
  _$FirewalldChange_DefaultZoneCopyWithImpl(this._self, this._then);

  final FirewalldChange_DefaultZone _self;
  final $Res Function(FirewalldChange_DefaultZone) _then;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? zone = null,}) {
  return _then(FirewalldChange_DefaultZone(
zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FirewalldChange_Target extends FirewalldChange {
  const FirewalldChange_Target({required this.zone, required this.target}): super._();
  

 final  String zone;
 final  FirewalldTarget target;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirewalldChange_TargetCopyWith<FirewalldChange_Target> get copyWith => _$FirewalldChange_TargetCopyWithImpl<FirewalldChange_Target>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_Target&&(identical(other.zone, zone) || other.zone == zone)&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,zone,target);

@override
String toString() {
  return 'FirewalldChange.target(zone: $zone, target: $target)';
}


}

/// @nodoc
abstract mixin class $FirewalldChange_TargetCopyWith<$Res> implements $FirewalldChangeCopyWith<$Res> {
  factory $FirewalldChange_TargetCopyWith(FirewalldChange_Target value, $Res Function(FirewalldChange_Target) _then) = _$FirewalldChange_TargetCopyWithImpl;
@useResult
$Res call({
 String zone, FirewalldTarget target
});




}
/// @nodoc
class _$FirewalldChange_TargetCopyWithImpl<$Res>
    implements $FirewalldChange_TargetCopyWith<$Res> {
  _$FirewalldChange_TargetCopyWithImpl(this._self, this._then);

  final FirewalldChange_Target _self;
  final $Res Function(FirewalldChange_Target) _then;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? zone = null,Object? target = null,}) {
  return _then(FirewalldChange_Target(
zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as FirewalldTarget,
  ));
}


}

/// @nodoc


class FirewalldChange_Masquerade extends FirewalldChange {
  const FirewalldChange_Masquerade({required this.zone, required this.enabled}): super._();
  

 final  String zone;
 final  bool enabled;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirewalldChange_MasqueradeCopyWith<FirewalldChange_Masquerade> get copyWith => _$FirewalldChange_MasqueradeCopyWithImpl<FirewalldChange_Masquerade>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_Masquerade&&(identical(other.zone, zone) || other.zone == zone)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,zone,enabled);

@override
String toString() {
  return 'FirewalldChange.masquerade(zone: $zone, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $FirewalldChange_MasqueradeCopyWith<$Res> implements $FirewalldChangeCopyWith<$Res> {
  factory $FirewalldChange_MasqueradeCopyWith(FirewalldChange_Masquerade value, $Res Function(FirewalldChange_Masquerade) _then) = _$FirewalldChange_MasqueradeCopyWithImpl;
@useResult
$Res call({
 String zone, bool enabled
});




}
/// @nodoc
class _$FirewalldChange_MasqueradeCopyWithImpl<$Res>
    implements $FirewalldChange_MasqueradeCopyWith<$Res> {
  _$FirewalldChange_MasqueradeCopyWithImpl(this._self, this._then);

  final FirewalldChange_Masquerade _self;
  final $Res Function(FirewalldChange_Masquerade) _then;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? zone = null,Object? enabled = null,}) {
  return _then(FirewalldChange_Masquerade(
zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class FirewalldChange_Add extends FirewalldChange {
  const FirewalldChange_Add({required this.zone, required this.item, required this.value}): super._();
  

 final  String zone;
 final  FirewalldItem item;
 final  String value;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirewalldChange_AddCopyWith<FirewalldChange_Add> get copyWith => _$FirewalldChange_AddCopyWithImpl<FirewalldChange_Add>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_Add&&(identical(other.zone, zone) || other.zone == zone)&&(identical(other.item, item) || other.item == item)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,zone,item,value);

@override
String toString() {
  return 'FirewalldChange.add(zone: $zone, item: $item, value: $value)';
}


}

/// @nodoc
abstract mixin class $FirewalldChange_AddCopyWith<$Res> implements $FirewalldChangeCopyWith<$Res> {
  factory $FirewalldChange_AddCopyWith(FirewalldChange_Add value, $Res Function(FirewalldChange_Add) _then) = _$FirewalldChange_AddCopyWithImpl;
@useResult
$Res call({
 String zone, FirewalldItem item, String value
});




}
/// @nodoc
class _$FirewalldChange_AddCopyWithImpl<$Res>
    implements $FirewalldChange_AddCopyWith<$Res> {
  _$FirewalldChange_AddCopyWithImpl(this._self, this._then);

  final FirewalldChange_Add _self;
  final $Res Function(FirewalldChange_Add) _then;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? zone = null,Object? item = null,Object? value = null,}) {
  return _then(FirewalldChange_Add(
zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as String,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as FirewalldItem,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FirewalldChange_Remove extends FirewalldChange {
  const FirewalldChange_Remove({required this.zone, required this.item, required this.value}): super._();
  

 final  String zone;
 final  FirewalldItem item;
 final  String value;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirewalldChange_RemoveCopyWith<FirewalldChange_Remove> get copyWith => _$FirewalldChange_RemoveCopyWithImpl<FirewalldChange_Remove>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_Remove&&(identical(other.zone, zone) || other.zone == zone)&&(identical(other.item, item) || other.item == item)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,zone,item,value);

@override
String toString() {
  return 'FirewalldChange.remove(zone: $zone, item: $item, value: $value)';
}


}

/// @nodoc
abstract mixin class $FirewalldChange_RemoveCopyWith<$Res> implements $FirewalldChangeCopyWith<$Res> {
  factory $FirewalldChange_RemoveCopyWith(FirewalldChange_Remove value, $Res Function(FirewalldChange_Remove) _then) = _$FirewalldChange_RemoveCopyWithImpl;
@useResult
$Res call({
 String zone, FirewalldItem item, String value
});




}
/// @nodoc
class _$FirewalldChange_RemoveCopyWithImpl<$Res>
    implements $FirewalldChange_RemoveCopyWith<$Res> {
  _$FirewalldChange_RemoveCopyWithImpl(this._self, this._then);

  final FirewalldChange_Remove _self;
  final $Res Function(FirewalldChange_Remove) _then;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? zone = null,Object? item = null,Object? value = null,}) {
  return _then(FirewalldChange_Remove(
zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as String,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as FirewalldItem,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FirewalldChange_ChangeInterface extends FirewalldChange {
  const FirewalldChange_ChangeInterface({required this.zone, required this.iface}): super._();
  

 final  String zone;
 final  String iface;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirewalldChange_ChangeInterfaceCopyWith<FirewalldChange_ChangeInterface> get copyWith => _$FirewalldChange_ChangeInterfaceCopyWithImpl<FirewalldChange_ChangeInterface>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_ChangeInterface&&(identical(other.zone, zone) || other.zone == zone)&&(identical(other.iface, iface) || other.iface == iface));
}


@override
int get hashCode => Object.hash(runtimeType,zone,iface);

@override
String toString() {
  return 'FirewalldChange.changeInterface(zone: $zone, iface: $iface)';
}


}

/// @nodoc
abstract mixin class $FirewalldChange_ChangeInterfaceCopyWith<$Res> implements $FirewalldChangeCopyWith<$Res> {
  factory $FirewalldChange_ChangeInterfaceCopyWith(FirewalldChange_ChangeInterface value, $Res Function(FirewalldChange_ChangeInterface) _then) = _$FirewalldChange_ChangeInterfaceCopyWithImpl;
@useResult
$Res call({
 String zone, String iface
});




}
/// @nodoc
class _$FirewalldChange_ChangeInterfaceCopyWithImpl<$Res>
    implements $FirewalldChange_ChangeInterfaceCopyWith<$Res> {
  _$FirewalldChange_ChangeInterfaceCopyWithImpl(this._self, this._then);

  final FirewalldChange_ChangeInterface _self;
  final $Res Function(FirewalldChange_ChangeInterface) _then;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? zone = null,Object? iface = null,}) {
  return _then(FirewalldChange_ChangeInterface(
zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as String,iface: null == iface ? _self.iface : iface // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FirewalldChange_RemoveInterface extends FirewalldChange {
  const FirewalldChange_RemoveInterface({required this.zone, required this.iface}): super._();
  

 final  String zone;
 final  String iface;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirewalldChange_RemoveInterfaceCopyWith<FirewalldChange_RemoveInterface> get copyWith => _$FirewalldChange_RemoveInterfaceCopyWithImpl<FirewalldChange_RemoveInterface>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirewalldChange_RemoveInterface&&(identical(other.zone, zone) || other.zone == zone)&&(identical(other.iface, iface) || other.iface == iface));
}


@override
int get hashCode => Object.hash(runtimeType,zone,iface);

@override
String toString() {
  return 'FirewalldChange.removeInterface(zone: $zone, iface: $iface)';
}


}

/// @nodoc
abstract mixin class $FirewalldChange_RemoveInterfaceCopyWith<$Res> implements $FirewalldChangeCopyWith<$Res> {
  factory $FirewalldChange_RemoveInterfaceCopyWith(FirewalldChange_RemoveInterface value, $Res Function(FirewalldChange_RemoveInterface) _then) = _$FirewalldChange_RemoveInterfaceCopyWithImpl;
@useResult
$Res call({
 String zone, String iface
});




}
/// @nodoc
class _$FirewalldChange_RemoveInterfaceCopyWithImpl<$Res>
    implements $FirewalldChange_RemoveInterfaceCopyWith<$Res> {
  _$FirewalldChange_RemoveInterfaceCopyWithImpl(this._self, this._then);

  final FirewalldChange_RemoveInterface _self;
  final $Res Function(FirewalldChange_RemoveInterface) _then;

/// Create a copy of FirewalldChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? zone = null,Object? iface = null,}) {
  return _then(FirewalldChange_RemoveInterface(
zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as String,iface: null == iface ? _self.iface : iface // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UfwChange {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UfwChange);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UfwChange()';
}


}

/// @nodoc
class $UfwChangeCopyWith<$Res>  {
$UfwChangeCopyWith(UfwChange _, $Res Function(UfwChange) __);
}


/// Adds pattern-matching-related methods to [UfwChange].
extension UfwChangePatterns on UfwChange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UfwChange_Enable value)?  enable,TResult Function( UfwChange_Disable value)?  disable,TResult Function( UfwChange_Reload value)?  reload,TResult Function( UfwChange_Policy value)?  policy,TResult Function( UfwChange_Logging value)?  logging,TResult Function( UfwChange_AddRule value)?  addRule,TResult Function( UfwChange_DeleteRule value)?  deleteRule,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UfwChange_Enable() when enable != null:
return enable(_that);case UfwChange_Disable() when disable != null:
return disable(_that);case UfwChange_Reload() when reload != null:
return reload(_that);case UfwChange_Policy() when policy != null:
return policy(_that);case UfwChange_Logging() when logging != null:
return logging(_that);case UfwChange_AddRule() when addRule != null:
return addRule(_that);case UfwChange_DeleteRule() when deleteRule != null:
return deleteRule(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UfwChange_Enable value)  enable,required TResult Function( UfwChange_Disable value)  disable,required TResult Function( UfwChange_Reload value)  reload,required TResult Function( UfwChange_Policy value)  policy,required TResult Function( UfwChange_Logging value)  logging,required TResult Function( UfwChange_AddRule value)  addRule,required TResult Function( UfwChange_DeleteRule value)  deleteRule,}){
final _that = this;
switch (_that) {
case UfwChange_Enable():
return enable(_that);case UfwChange_Disable():
return disable(_that);case UfwChange_Reload():
return reload(_that);case UfwChange_Policy():
return policy(_that);case UfwChange_Logging():
return logging(_that);case UfwChange_AddRule():
return addRule(_that);case UfwChange_DeleteRule():
return deleteRule(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UfwChange_Enable value)?  enable,TResult? Function( UfwChange_Disable value)?  disable,TResult? Function( UfwChange_Reload value)?  reload,TResult? Function( UfwChange_Policy value)?  policy,TResult? Function( UfwChange_Logging value)?  logging,TResult? Function( UfwChange_AddRule value)?  addRule,TResult? Function( UfwChange_DeleteRule value)?  deleteRule,}){
final _that = this;
switch (_that) {
case UfwChange_Enable() when enable != null:
return enable(_that);case UfwChange_Disable() when disable != null:
return disable(_that);case UfwChange_Reload() when reload != null:
return reload(_that);case UfwChange_Policy() when policy != null:
return policy(_that);case UfwChange_Logging() when logging != null:
return logging(_that);case UfwChange_AddRule() when addRule != null:
return addRule(_that);case UfwChange_DeleteRule() when deleteRule != null:
return deleteRule(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  enable,TResult Function()?  disable,TResult Function()?  reload,TResult Function( UfwChain chain,  UfwPolicy policy)?  policy,TResult Function( UfwLogLevel level)?  logging,TResult Function( UfwRuleDraft draft)?  addRule,TResult Function( List<String> tuples)?  deleteRule,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UfwChange_Enable() when enable != null:
return enable();case UfwChange_Disable() when disable != null:
return disable();case UfwChange_Reload() when reload != null:
return reload();case UfwChange_Policy() when policy != null:
return policy(_that.chain,_that.policy);case UfwChange_Logging() when logging != null:
return logging(_that.level);case UfwChange_AddRule() when addRule != null:
return addRule(_that.draft);case UfwChange_DeleteRule() when deleteRule != null:
return deleteRule(_that.tuples);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  enable,required TResult Function()  disable,required TResult Function()  reload,required TResult Function( UfwChain chain,  UfwPolicy policy)  policy,required TResult Function( UfwLogLevel level)  logging,required TResult Function( UfwRuleDraft draft)  addRule,required TResult Function( List<String> tuples)  deleteRule,}) {final _that = this;
switch (_that) {
case UfwChange_Enable():
return enable();case UfwChange_Disable():
return disable();case UfwChange_Reload():
return reload();case UfwChange_Policy():
return policy(_that.chain,_that.policy);case UfwChange_Logging():
return logging(_that.level);case UfwChange_AddRule():
return addRule(_that.draft);case UfwChange_DeleteRule():
return deleteRule(_that.tuples);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  enable,TResult? Function()?  disable,TResult? Function()?  reload,TResult? Function( UfwChain chain,  UfwPolicy policy)?  policy,TResult? Function( UfwLogLevel level)?  logging,TResult? Function( UfwRuleDraft draft)?  addRule,TResult? Function( List<String> tuples)?  deleteRule,}) {final _that = this;
switch (_that) {
case UfwChange_Enable() when enable != null:
return enable();case UfwChange_Disable() when disable != null:
return disable();case UfwChange_Reload() when reload != null:
return reload();case UfwChange_Policy() when policy != null:
return policy(_that.chain,_that.policy);case UfwChange_Logging() when logging != null:
return logging(_that.level);case UfwChange_AddRule() when addRule != null:
return addRule(_that.draft);case UfwChange_DeleteRule() when deleteRule != null:
return deleteRule(_that.tuples);case _:
  return null;

}
}

}

/// @nodoc


class UfwChange_Enable extends UfwChange {
  const UfwChange_Enable(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UfwChange_Enable);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UfwChange.enable()';
}


}




/// @nodoc


class UfwChange_Disable extends UfwChange {
  const UfwChange_Disable(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UfwChange_Disable);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UfwChange.disable()';
}


}




/// @nodoc


class UfwChange_Reload extends UfwChange {
  const UfwChange_Reload(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UfwChange_Reload);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UfwChange.reload()';
}


}




/// @nodoc


class UfwChange_Policy extends UfwChange {
  const UfwChange_Policy({required this.chain, required this.policy}): super._();
  

 final  UfwChain chain;
 final  UfwPolicy policy;

/// Create a copy of UfwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UfwChange_PolicyCopyWith<UfwChange_Policy> get copyWith => _$UfwChange_PolicyCopyWithImpl<UfwChange_Policy>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UfwChange_Policy&&(identical(other.chain, chain) || other.chain == chain)&&(identical(other.policy, policy) || other.policy == policy));
}


@override
int get hashCode => Object.hash(runtimeType,chain,policy);

@override
String toString() {
  return 'UfwChange.policy(chain: $chain, policy: $policy)';
}


}

/// @nodoc
abstract mixin class $UfwChange_PolicyCopyWith<$Res> implements $UfwChangeCopyWith<$Res> {
  factory $UfwChange_PolicyCopyWith(UfwChange_Policy value, $Res Function(UfwChange_Policy) _then) = _$UfwChange_PolicyCopyWithImpl;
@useResult
$Res call({
 UfwChain chain, UfwPolicy policy
});




}
/// @nodoc
class _$UfwChange_PolicyCopyWithImpl<$Res>
    implements $UfwChange_PolicyCopyWith<$Res> {
  _$UfwChange_PolicyCopyWithImpl(this._self, this._then);

  final UfwChange_Policy _self;
  final $Res Function(UfwChange_Policy) _then;

/// Create a copy of UfwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? chain = null,Object? policy = null,}) {
  return _then(UfwChange_Policy(
chain: null == chain ? _self.chain : chain // ignore: cast_nullable_to_non_nullable
as UfwChain,policy: null == policy ? _self.policy : policy // ignore: cast_nullable_to_non_nullable
as UfwPolicy,
  ));
}


}

/// @nodoc


class UfwChange_Logging extends UfwChange {
  const UfwChange_Logging({required this.level}): super._();
  

 final  UfwLogLevel level;

/// Create a copy of UfwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UfwChange_LoggingCopyWith<UfwChange_Logging> get copyWith => _$UfwChange_LoggingCopyWithImpl<UfwChange_Logging>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UfwChange_Logging&&(identical(other.level, level) || other.level == level));
}


@override
int get hashCode => Object.hash(runtimeType,level);

@override
String toString() {
  return 'UfwChange.logging(level: $level)';
}


}

/// @nodoc
abstract mixin class $UfwChange_LoggingCopyWith<$Res> implements $UfwChangeCopyWith<$Res> {
  factory $UfwChange_LoggingCopyWith(UfwChange_Logging value, $Res Function(UfwChange_Logging) _then) = _$UfwChange_LoggingCopyWithImpl;
@useResult
$Res call({
 UfwLogLevel level
});




}
/// @nodoc
class _$UfwChange_LoggingCopyWithImpl<$Res>
    implements $UfwChange_LoggingCopyWith<$Res> {
  _$UfwChange_LoggingCopyWithImpl(this._self, this._then);

  final UfwChange_Logging _self;
  final $Res Function(UfwChange_Logging) _then;

/// Create a copy of UfwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? level = null,}) {
  return _then(UfwChange_Logging(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as UfwLogLevel,
  ));
}


}

/// @nodoc


class UfwChange_AddRule extends UfwChange {
  const UfwChange_AddRule({required this.draft}): super._();
  

 final  UfwRuleDraft draft;

/// Create a copy of UfwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UfwChange_AddRuleCopyWith<UfwChange_AddRule> get copyWith => _$UfwChange_AddRuleCopyWithImpl<UfwChange_AddRule>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UfwChange_AddRule&&(identical(other.draft, draft) || other.draft == draft));
}


@override
int get hashCode => Object.hash(runtimeType,draft);

@override
String toString() {
  return 'UfwChange.addRule(draft: $draft)';
}


}

/// @nodoc
abstract mixin class $UfwChange_AddRuleCopyWith<$Res> implements $UfwChangeCopyWith<$Res> {
  factory $UfwChange_AddRuleCopyWith(UfwChange_AddRule value, $Res Function(UfwChange_AddRule) _then) = _$UfwChange_AddRuleCopyWithImpl;
@useResult
$Res call({
 UfwRuleDraft draft
});




}
/// @nodoc
class _$UfwChange_AddRuleCopyWithImpl<$Res>
    implements $UfwChange_AddRuleCopyWith<$Res> {
  _$UfwChange_AddRuleCopyWithImpl(this._self, this._then);

  final UfwChange_AddRule _self;
  final $Res Function(UfwChange_AddRule) _then;

/// Create a copy of UfwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? draft = null,}) {
  return _then(UfwChange_AddRule(
draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as UfwRuleDraft,
  ));
}


}

/// @nodoc


class UfwChange_DeleteRule extends UfwChange {
  const UfwChange_DeleteRule({required final  List<String> tuples}): _tuples = tuples,super._();
  

 final  List<String> _tuples;
 List<String> get tuples {
  if (_tuples is EqualUnmodifiableListView) return _tuples;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tuples);
}


/// Create a copy of UfwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UfwChange_DeleteRuleCopyWith<UfwChange_DeleteRule> get copyWith => _$UfwChange_DeleteRuleCopyWithImpl<UfwChange_DeleteRule>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UfwChange_DeleteRule&&const DeepCollectionEquality().equals(other._tuples, _tuples));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tuples));

@override
String toString() {
  return 'UfwChange.deleteRule(tuples: $tuples)';
}


}

/// @nodoc
abstract mixin class $UfwChange_DeleteRuleCopyWith<$Res> implements $UfwChangeCopyWith<$Res> {
  factory $UfwChange_DeleteRuleCopyWith(UfwChange_DeleteRule value, $Res Function(UfwChange_DeleteRule) _then) = _$UfwChange_DeleteRuleCopyWithImpl;
@useResult
$Res call({
 List<String> tuples
});




}
/// @nodoc
class _$UfwChange_DeleteRuleCopyWithImpl<$Res>
    implements $UfwChange_DeleteRuleCopyWith<$Res> {
  _$UfwChange_DeleteRuleCopyWithImpl(this._self, this._then);

  final UfwChange_DeleteRule _self;
  final $Res Function(UfwChange_DeleteRule) _then;

/// Create a copy of UfwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tuples = null,}) {
  return _then(UfwChange_DeleteRule(
tuples: null == tuples ? _self._tuples : tuples // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
