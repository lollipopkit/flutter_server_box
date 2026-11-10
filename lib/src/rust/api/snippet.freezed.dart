// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snippet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlanError {

 String get key;
/// Create a copy of PlanError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlanErrorCopyWith<PlanError> get copyWith => _$PlanErrorCopyWithImpl<PlanError>(this as PlanError, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlanError&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,key);

@override
String toString() {
  return 'PlanError(key: $key)';
}


}

/// @nodoc
abstract mixin class $PlanErrorCopyWith<$Res>  {
  factory $PlanErrorCopyWith(PlanError value, $Res Function(PlanError) _then) = _$PlanErrorCopyWithImpl;
@useResult
$Res call({
 String key
});




}
/// @nodoc
class _$PlanErrorCopyWithImpl<$Res>
    implements $PlanErrorCopyWith<$Res> {
  _$PlanErrorCopyWithImpl(this._self, this._then);

  final PlanError _self;
  final $Res Function(PlanError) _then;

/// Create a copy of PlanError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PlanError].
extension PlanErrorPatterns on PlanError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PlanError_Unanswerable value)?  unanswerable,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PlanError_Unanswerable() when unanswerable != null:
return unanswerable(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PlanError_Unanswerable value)  unanswerable,}){
final _that = this;
switch (_that) {
case PlanError_Unanswerable():
return unanswerable(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PlanError_Unanswerable value)?  unanswerable,}){
final _that = this;
switch (_that) {
case PlanError_Unanswerable() when unanswerable != null:
return unanswerable(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String key)?  unanswerable,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PlanError_Unanswerable() when unanswerable != null:
return unanswerable(_that.key);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String key)  unanswerable,}) {final _that = this;
switch (_that) {
case PlanError_Unanswerable():
return unanswerable(_that.key);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String key)?  unanswerable,}) {final _that = this;
switch (_that) {
case PlanError_Unanswerable() when unanswerable != null:
return unanswerable(_that.key);case _:
  return null;

}
}

}

/// @nodoc


class PlanError_Unanswerable extends PlanError {
  const PlanError_Unanswerable({required this.key}): super._();
  

@override final  String key;

/// Create a copy of PlanError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlanError_UnanswerableCopyWith<PlanError_Unanswerable> get copyWith => _$PlanError_UnanswerableCopyWithImpl<PlanError_Unanswerable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlanError_Unanswerable&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,key);

@override
String toString() {
  return 'PlanError.unanswerable(key: $key)';
}


}

/// @nodoc
abstract mixin class $PlanError_UnanswerableCopyWith<$Res> implements $PlanErrorCopyWith<$Res> {
  factory $PlanError_UnanswerableCopyWith(PlanError_Unanswerable value, $Res Function(PlanError_Unanswerable) _then) = _$PlanError_UnanswerableCopyWithImpl;
@override @useResult
$Res call({
 String key
});




}
/// @nodoc
class _$PlanError_UnanswerableCopyWithImpl<$Res>
    implements $PlanError_UnanswerableCopyWith<$Res> {
  _$PlanError_UnanswerableCopyWithImpl(this._self, this._then);

  final PlanError_Unanswerable _self;
  final $Res Function(PlanError_Unanswerable) _then;

/// Create a copy of PlanError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,}) {
  return _then(PlanError_Unanswerable(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$Step {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Step);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Step()';
}


}

/// @nodoc
class $StepCopyWith<$Res>  {
$StepCopyWith(Step _, $Res Function(Step) __);
}


/// Adds pattern-matching-related methods to [Step].
extension StepPatterns on Step {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Step_Text value)?  text,TResult Function( Step_Combo value)?  combo,TResult Function( Step_Sleep value)?  sleep,TResult Function( Step_Enter value)?  enter,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Step_Text() when text != null:
return text(_that);case Step_Combo() when combo != null:
return combo(_that);case Step_Sleep() when sleep != null:
return sleep(_that);case Step_Enter() when enter != null:
return enter(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Step_Text value)  text,required TResult Function( Step_Combo value)  combo,required TResult Function( Step_Sleep value)  sleep,required TResult Function( Step_Enter value)  enter,}){
final _that = this;
switch (_that) {
case Step_Text():
return text(_that);case Step_Combo():
return combo(_that);case Step_Sleep():
return sleep(_that);case Step_Enter():
return enter(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Step_Text value)?  text,TResult? Function( Step_Combo value)?  combo,TResult? Function( Step_Sleep value)?  sleep,TResult? Function( Step_Enter value)?  enter,}){
final _that = this;
switch (_that) {
case Step_Text() when text != null:
return text(_that);case Step_Combo() when combo != null:
return combo(_that);case Step_Sleep() when sleep != null:
return sleep(_that);case Step_Enter() when enter != null:
return enter(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  text,TResult Function( bool ctrl,  bool alt,  String key,  String rest)?  combo,TResult Function( BigInt seconds)?  sleep,TResult Function( int times)?  enter,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Step_Text() when text != null:
return text(_that.text);case Step_Combo() when combo != null:
return combo(_that.ctrl,_that.alt,_that.key,_that.rest);case Step_Sleep() when sleep != null:
return sleep(_that.seconds);case Step_Enter() when enter != null:
return enter(_that.times);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  text,required TResult Function( bool ctrl,  bool alt,  String key,  String rest)  combo,required TResult Function( BigInt seconds)  sleep,required TResult Function( int times)  enter,}) {final _that = this;
switch (_that) {
case Step_Text():
return text(_that.text);case Step_Combo():
return combo(_that.ctrl,_that.alt,_that.key,_that.rest);case Step_Sleep():
return sleep(_that.seconds);case Step_Enter():
return enter(_that.times);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  text,TResult? Function( bool ctrl,  bool alt,  String key,  String rest)?  combo,TResult? Function( BigInt seconds)?  sleep,TResult? Function( int times)?  enter,}) {final _that = this;
switch (_that) {
case Step_Text() when text != null:
return text(_that.text);case Step_Combo() when combo != null:
return combo(_that.ctrl,_that.alt,_that.key,_that.rest);case Step_Sleep() when sleep != null:
return sleep(_that.seconds);case Step_Enter() when enter != null:
return enter(_that.times);case _:
  return null;

}
}

}

/// @nodoc


class Step_Text extends Step {
  const Step_Text({required this.text}): super._();
  

 final  String text;

/// Create a copy of Step
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Step_TextCopyWith<Step_Text> get copyWith => _$Step_TextCopyWithImpl<Step_Text>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Step_Text&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'Step.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $Step_TextCopyWith<$Res> implements $StepCopyWith<$Res> {
  factory $Step_TextCopyWith(Step_Text value, $Res Function(Step_Text) _then) = _$Step_TextCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$Step_TextCopyWithImpl<$Res>
    implements $Step_TextCopyWith<$Res> {
  _$Step_TextCopyWithImpl(this._self, this._then);

  final Step_Text _self;
  final $Res Function(Step_Text) _then;

/// Create a copy of Step
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(Step_Text(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Step_Combo extends Step {
  const Step_Combo({required this.ctrl, required this.alt, required this.key, required this.rest}): super._();
  

 final  bool ctrl;
 final  bool alt;
 final  String key;
 final  String rest;

/// Create a copy of Step
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Step_ComboCopyWith<Step_Combo> get copyWith => _$Step_ComboCopyWithImpl<Step_Combo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Step_Combo&&(identical(other.ctrl, ctrl) || other.ctrl == ctrl)&&(identical(other.alt, alt) || other.alt == alt)&&(identical(other.key, key) || other.key == key)&&(identical(other.rest, rest) || other.rest == rest));
}


@override
int get hashCode => Object.hash(runtimeType,ctrl,alt,key,rest);

@override
String toString() {
  return 'Step.combo(ctrl: $ctrl, alt: $alt, key: $key, rest: $rest)';
}


}

/// @nodoc
abstract mixin class $Step_ComboCopyWith<$Res> implements $StepCopyWith<$Res> {
  factory $Step_ComboCopyWith(Step_Combo value, $Res Function(Step_Combo) _then) = _$Step_ComboCopyWithImpl;
@useResult
$Res call({
 bool ctrl, bool alt, String key, String rest
});




}
/// @nodoc
class _$Step_ComboCopyWithImpl<$Res>
    implements $Step_ComboCopyWith<$Res> {
  _$Step_ComboCopyWithImpl(this._self, this._then);

  final Step_Combo _self;
  final $Res Function(Step_Combo) _then;

/// Create a copy of Step
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ctrl = null,Object? alt = null,Object? key = null,Object? rest = null,}) {
  return _then(Step_Combo(
ctrl: null == ctrl ? _self.ctrl : ctrl // ignore: cast_nullable_to_non_nullable
as bool,alt: null == alt ? _self.alt : alt // ignore: cast_nullable_to_non_nullable
as bool,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,rest: null == rest ? _self.rest : rest // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Step_Sleep extends Step {
  const Step_Sleep({required this.seconds}): super._();
  

 final  BigInt seconds;

/// Create a copy of Step
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Step_SleepCopyWith<Step_Sleep> get copyWith => _$Step_SleepCopyWithImpl<Step_Sleep>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Step_Sleep&&(identical(other.seconds, seconds) || other.seconds == seconds));
}


@override
int get hashCode => Object.hash(runtimeType,seconds);

@override
String toString() {
  return 'Step.sleep(seconds: $seconds)';
}


}

/// @nodoc
abstract mixin class $Step_SleepCopyWith<$Res> implements $StepCopyWith<$Res> {
  factory $Step_SleepCopyWith(Step_Sleep value, $Res Function(Step_Sleep) _then) = _$Step_SleepCopyWithImpl;
@useResult
$Res call({
 BigInt seconds
});




}
/// @nodoc
class _$Step_SleepCopyWithImpl<$Res>
    implements $Step_SleepCopyWith<$Res> {
  _$Step_SleepCopyWithImpl(this._self, this._then);

  final Step_Sleep _self;
  final $Res Function(Step_Sleep) _then;

/// Create a copy of Step
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? seconds = null,}) {
  return _then(Step_Sleep(
seconds: null == seconds ? _self.seconds : seconds // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class Step_Enter extends Step {
  const Step_Enter({required this.times}): super._();
  

 final  int times;

/// Create a copy of Step
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Step_EnterCopyWith<Step_Enter> get copyWith => _$Step_EnterCopyWithImpl<Step_Enter>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Step_Enter&&(identical(other.times, times) || other.times == times));
}


@override
int get hashCode => Object.hash(runtimeType,times);

@override
String toString() {
  return 'Step.enter(times: $times)';
}


}

/// @nodoc
abstract mixin class $Step_EnterCopyWith<$Res> implements $StepCopyWith<$Res> {
  factory $Step_EnterCopyWith(Step_Enter value, $Res Function(Step_Enter) _then) = _$Step_EnterCopyWithImpl;
@useResult
$Res call({
 int times
});




}
/// @nodoc
class _$Step_EnterCopyWithImpl<$Res>
    implements $Step_EnterCopyWith<$Res> {
  _$Step_EnterCopyWithImpl(this._self, this._then);

  final Step_Enter _self;
  final $Res Function(Step_Enter) _then;

/// Create a copy of Step
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? times = null,}) {
  return _then(Step_Enter(
times: null == times ? _self.times : times // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
